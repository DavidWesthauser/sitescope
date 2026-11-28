import Foundation

/// Uploads the phone's queued changes and then reads the server's state into local storage (T-008).
/// Never throws to the caller and never blocks a screen: being offline just leaves the queue for the next pass;
/// a change the server refuses is marked failed with its reason, so the user can retry it.
@MainActor final class SyncEngine {
    private let storage: LocalDataStore
    private let remote: RemoteSyncing
    private let policy: ConflictPolicy
    private(set) var isSyncing = false
    private(set) var isOffline = false
    /// Why the last pass could not read part of the server, e.g. a table the database does not have yet (T-029).
    private(set) var problem: String?
    var onStateChange: (@MainActor () -> Void)?
    private var anotherPass = false

    init(storage: LocalDataStore, remote: RemoteSyncing, policy: ConflictPolicy = LastChangeWins()) {
        self.storage = storage
        self.remote = remote
        self.policy = policy
    }

    /// One sync, or a follow-up once the running one ends if changes arrive meanwhile.
    func sync() async {
        if isSyncing {
            anotherPass = true
            return
        }
        isSyncing = true
        onStateChange?()
        defer {
            isSyncing = false
            onStateChange?()
        }
        repeat {
            anotherPass = false
            await pass()
        } while anotherPass && !isOffline
    }

    /// Clears the failure of one change (or all) so the next pass tries it again.
    func retry(_ key: RecordKey? = nil) async {
        try? await storage.change { data in
            for i in data.outbox.indices where key == nil || data.outbox[i].key == key {
                data.outbox[i].lastError = nil
            }
        }
        await sync()
    }

    private func pass() async {
        do {
            try await push()
            try await pull()
            isOffline = false
            try? await storage.change { $0.lastSync = Date() }
        } catch {
            if Self.isOffline(error) { isOffline = true } else { problem = error.localizedDescription }
        }
        onStateChange?()
    }

    /// The server's own words for refusals, but not its internals: a column or table it does not have yet means
    /// the database is not on the version the app expects.
    static func readable(_ error: Error, deleting: Bool = false) -> String {
        let text = error.localizedDescription
        let schema = ["schema cache", "does not exist", "column", "relation"]
        guard schema.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return text }
        return deleting ? "Can’t be deleted online yet." : "Can’t be stored online yet."
    }

    static func isOffline(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        let offline: [URLError.Code] = [
            .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
            .dataNotAllowed, .internationalRoamingOff, .dnsLookupFailed,
        ]
        return offline.contains(error.code)
    }

    // MARK: Upload

    /// Uploads in queue order. Resolving a conflict can queue new changes (a scan kept as a new room, its moved
    /// drawings); those go up in the same sync, in further rounds, each record at most once per sync.
    private func push() async throws {
        var attempted = Set<RecordKey>()
        while true {
            let round = Outbox.ordered(storage.data.outbox).filter {
                $0.lastError == nil && !attempted.contains($0.key)
            }
            guard !round.isEmpty else { return }
            for item in round { attempted.insert(item.key) }
            try await pushRound(round)
        }
    }
    private func pushRound(_ items: [OutboxItem]) async throws {
        for item in items {
            guard storage.data.outboxItem(for: item.key) != nil else { continue }
            do {
                switch item.action {
                case .upsert: try await pushUpsert(item.key)
                case .delete: try await pushDelete(item.key)
                }
            } catch {
                // Offline or signed out: stop and keep everything queued. Anything else: mark this change failed.
                if Self.isOffline(error) || (error as? HTTPFailure)?.status == 401 { throw error }
                let reason = Self.readable(error, deleting: item.action == .delete)
                try await storage.change { data in
                    guard let i = data.outbox.firstIndex(where: { $0.key == item.key }) else { return }
                    data.outbox[i].failures += 1
                    data.outbox[i].lastError = reason
                }
            }
        }
    }

    private func finish(_ key: RecordKey) async throws {
        try await storage.change { $0.outbox.removeAll { $0.key == key } }
    }
    private func remember(_ row: JSONObject, for key: RecordKey) async throws {
        let version = SyncedVersion(revision: row["revision"]?.integer ?? 0, base: row)
        try await storage.change { $0.setVersion(version, of: key) }
    }
    private func fields(_ object: JSONObject, _ names: [String]) -> JSONObject {
        object.filter { names.contains($0.key) }
    }

    private func pushUpsert(_ key: RecordKey) async throws {
        guard var local = try storage.data.object(for: key) else { return try await finish(key) }
        let assets = storage.data.pendingAssets(of: key)
        if !storage.data.isOnServer(key) {
            if key.entity == .room, !assets.isEmpty {
                // The scan file is stored under the room, so the room has to exist on the server first.
                var bare = fields(local, key.entity.insertFields)
                for field in SyncEntity.scanFields { bare.removeValue(forKey: field) }
                try await insertOrAdopt(key, bare)
            } else {
                try await upload(assets)
                try await insertOrAdopt(key, fields(local, key.entity.insertFields))
            }
        }
        try await upload(storage.data.pendingAssets(of: key))
        // A conflict merges and tries again; three rounds cover even a busy record.
        for _ in 0..<3 {
            guard let version = storage.data.version(of: key) else { return }
            let changes = key.entity.writableFields.reduce(into: JSONObject()) { result, field in
                if local[field] ?? .null != version.base[field] ?? .null { result[field] = local[field] ?? .null }
            }
            if changes.isEmpty { return try await finish(key) }
            if let row = try await remote.update(key, revision: version.revision, changes) {
                try await remember(row, for: key)
                return try await finish(key)
            }
            guard let current = try await remote.fetch(key) else {
                // Deleted on the server while edited here: the edit wins and the record comes back.
                try await storage.change { $0.setVersion(nil, of: key) }
                try await insertOrAdopt(key, fields(local, key.entity.insertFields))
                try await notify("“\(storage.data.name(of: key))” was deleted on another device. Your changes kept it.")
                return try await finish(key)
            }
            switch FieldMerge.merge(key.entity, base: version.base, local: local, remote: current, policy: policy) {
            case .keepScanAsNewRoom:
                return try await keepScanAsNewRoom(key, server: current)
            case .merged(let merged, let conflicts):
                try await storage.change { data in
                    try data.replace(key, with: merged)
                    data.setVersion(SyncedVersion(revision: current["revision"]?.integer ?? 0, base: current), of: key)
                }
                local = merged
                if !conflicts.isEmpty {
                    try await notify(
                        "“\(storage.data.name(of: key))” was also changed on another device. Your version of "
                            + conflicts.joined(separator: ", ") + " was kept.")
                }
            }
        }
    }

    /// Creates the record; if it already exists (an earlier upload got through before the app stopped), adopts it.
    private func insertOrAdopt(_ key: RecordKey, _ fields: JSONObject) async throws {
        do {
            try await remember(try await remote.insert(key.entity, fields), for: key)
        } catch let failure as HTTPFailure where failure.status == 409 {
            guard let row = try await remote.fetch(key) else { throw failure }
            try await remember(row, for: key)
        }
    }

    private func upload(_ paths: [String]) async throws {
        for path in paths {
            if storage.hasAsset(path) {
                let type = path.hasSuffix(".png") ? "image/png" : "application/octet-stream"
                try await remote.upload(path: path, data: try storage.readAsset(path: path), type: type)
            }
            try await storage.change { $0.pendingAssets.removeAll { $0 == path } }
        }
    }

    /// The server already has another scan of this room. The server's room stays as it is; the phone's scan and the
    /// drawings placed in it move to a new room next to it, so neither scan is lost.
    private func keepScanAsNewRoom(_ key: RecordKey, server: JSONObject) async throws {
        guard let mine = storage.data.rooms.first(where: { $0.id == key.id }) else { return try await finish(key) }
        var copy = mine
        copy.id = UUID()
        copy.name = String("\(mine.name) (new scan)".prefix(DisplayName.maximumLength))
        copy.responsible_id = nil
        // Files live under their room, so the copy gets its own copies of the scan file.
        var moved: [String: String] = [:]
        if let path = mine.map_path {
            let newPath = path.replacingOccurrences(
                of: mine.id.uuidString.lowercased(), with: copy.id.uuidString.lowercased())
            if storage.hasAsset(path) { try storage.writeAsset(path: newPath, data: storage.readAsset(path: path)) }
            copy.map_path = newPath
            moved[path] = newPath
        }
        let newRoom = copy
        let text = "“\(mine.name)” was scanned on another device too. Your scan is kept as “\(newRoom.name)”."
        try await storage.change { data in
            try data.replace(key, with: server)
            data.setVersion(SyncedVersion(revision: server["revision"]?.integer ?? 0, base: server), of: key)
            data.outbox.removeAll { $0.key == key }
            data.rooms.append(newRoom)
            Outbox.enqueue(.upsert, for: RecordKey(.room, newRoom.id), existsOnServer: false, into: &data.outbox)
            data.pendingAssets += moved.values
            for i in data.drawings.indices
            where data.drawings[i].room_id == mine.id && data.drawings[i].coordinate_id == mine.coordinate_id {
                data.drawings[i].room_id = newRoom.id
                let drawing = RecordKey(.drawing, data.drawings[i].id)
                data.setVersion(nil, of: drawing)
                data.outbox.removeAll { $0.key == drawing }
                Outbox.enqueue(.upsert, for: drawing, existsOnServer: false, into: &data.outbox)
            }
            data.notices.append(SyncNotice(text: text))
        }
    }

    private func pushDelete(_ key: RecordKey) async throws {
        guard let version = storage.data.version(of: key) else { return try await finish(key) }
        let deleted: Bool
        do {
            deleted = try await remote.delete(key, revision: version.revision)
        } catch let failure as HTTPFailure where failure.status != 401 {
            // Already gone from the server (e.g. removed elsewhere): the delete is done anyway.
            guard try await remote.fetch(key) == nil else { throw failure }
            deleted = true
        }
        if deleted {
            try await storage.change { $0.setVersion(nil, of: key) }
            return try await finish(key)
        }
        guard let current = try await remote.fetch(key) else {
            try await storage.change { $0.setVersion(nil, of: key) }
            return try await finish(key)
        }
        // Changed on the server while deleted here: the edit wins, the record comes back.
        try await storage.change { data in
            try data.restore(key, from: current)
            data.setVersion(SyncedVersion(revision: current["revision"]?.integer ?? 0, base: current), of: key)
            data.outbox.removeAll { $0.key == key }
        }
        try await notify("“\(storage.data.name(of: key))” was changed on another device, so it was not deleted.")
    }

    private func notify(_ text: String) async throws {
        try await storage.change { $0.notices.append(SyncNotice(text: text)) }
    }

    // MARK: Download

    /// Reads every visible row and takes it over, except for records with a waiting change: those keep the phone's
    /// version until their upload merged it. Records gone from the server are removed unless they wait for upload.
    private func pull() async throws {
        var unreadable: [String] = []
        for entity in SyncEntity.allCases {
            let rows: [JSONObject]
            do {
                rows = try await remote.fetchAll(entity)
            } catch let failure as HTTPFailure where failure.status != 401 {
                unreadable.append(entity.table)
                continue
            }
            try await storage.change { data in try data.takeOver(entity, rows: rows) }
        }
        problem =
            unreadable.isEmpty
            ? nil
            : "The server can’t store \(unreadable.joined(separator: ", ")) yet. They stay on this iPhone until it can."
    }
}

extension LocalData {
    func object(for key: RecordKey) throws -> JSONObject? {
        switch key.entity {
        case .project: return try projects.first { $0.id == key.id }.map(RecordCoding.object)
        case .house: return try houses.first { $0.id == key.id }.map(RecordCoding.object)
        case .room: return try rooms.first { $0.id == key.id }.map(RecordCoding.object)
        case .drawing: return try drawings.first { $0.id == key.id }.map(RecordCoding.object)
        }
    }
    func name(of key: RecordKey) -> String {
        switch key.entity {
        case .project: return projects.first { $0.id == key.id }?.name ?? "A project"
        case .house: return houses.first { $0.id == key.id }?.name ?? "A house"
        case .room: return rooms.first { $0.id == key.id }?.name ?? "A room"
        case .drawing: return "A drawing"
        }
    }
    /// Files a record refers to that are not on the server yet.
    func pendingAssets(of key: RecordKey) -> [String] {
        let paths: [String?]
        switch key.entity {
        case .room: paths = [rooms.first { $0.id == key.id }?.map_path]
        case .drawing: paths = [drawings.first { $0.id == key.id }?.image?.path]
        case .project, .house: paths = []
        }
        return paths.compactMap { $0 }.filter(pendingAssets.contains)
    }
    /// Replaces the local record with `object`, or adds it.
    mutating func replace(_ key: RecordKey, with object: JSONObject) throws {
        switch key.entity {
        case .project: Self.put(try RecordCoding.decode(Project.self, from: object), into: &projects)
        case .house: Self.put(try RecordCoding.decode(House.self, from: object), into: &houses)
        case .room: Self.put(try RecordCoding.decode(Room.self, from: object), into: &rooms)
        case .drawing: Self.put(try RecordCoding.decode(Annotation.self, from: object), into: &drawings)
        }
    }
    mutating func restore(_ key: RecordKey, from object: JSONObject) throws { try replace(key, with: object) }
    private static func put<T: Identifiable>(_ value: T, into list: inout [T]) {
        if let i = list.firstIndex(where: { $0.id == value.id }) { list[i] = value } else { list.append(value) }
    }

    mutating func takeOver(_ entity: SyncEntity, rows: [JSONObject]) throws {
        var seen = Set<UUID>()
        for row in rows {
            guard case .string(let text)? = row["id"], let id = UUID(uuidString: text) else { continue }
            seen.insert(id)
            let key = RecordKey(entity, id)
            guard outboxItem(for: key) == nil else { continue }
            // A row this app version cannot read (e.g. a newer kind) is skipped, not allowed to break sync.
            guard (try? replace(key, with: row)) != nil else { continue }
            setVersion(SyncedVersion(revision: row["revision"]?.integer ?? 0, base: row), of: key)
        }
        let local: [UUID]
        switch entity {
        case .project: local = projects.map(\.id)
        case .house: local = houses.map(\.id)
        case .room: local = rooms.map(\.id)
        case .drawing: local = drawings.map(\.id)
        }
        for id in local where !seen.contains(id) {
            let key = RecordKey(entity, id)
            guard outboxItem(for: key) == nil, isOnServer(key) else { continue }
            setVersion(nil, of: key)
            switch entity {
            case .project: projects.removeAll { $0.id == id }
            case .house: houses.removeAll { $0.id == id }
            case .room: rooms.removeAll { $0.id == id }
            case .drawing: drawings.removeAll { $0.id == id }
            }
        }
    }
}
