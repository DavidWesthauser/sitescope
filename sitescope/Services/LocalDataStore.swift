import Foundation

/// The server version a record was last seen at: the base for merging (T-008) and the revision for conditional
/// writes (T-029).
struct SyncedVersion: Codable, Equatable, Sendable {
    var revision: Int
    var base: JSONObject
}

/// Everything one account keeps on the phone. Screens read only this; the sync engine fills it from the server.
/// Every field decodes with a default, so files written by older app versions keep opening.
struct LocalData: Codable, Sendable {
    var projects: [Project] = []
    var houses: [House] = []
    var rooms: [Room] = []
    var drawings: [Annotation] = []
    /// Keyed by `LocalData.key(_:)`.
    var synced: [String: SyncedVersion] = [:]
    var outbox: [OutboxItem] = []
    /// Files saved on the phone that still have to go to the server.
    var pendingAssets: [String] = []
    var notices: [SyncNotice] = []
    /// The last known level per scope (`AccessScope.cacheKey`), so rights work offline.
    var levels: [String: Int] = [:]
    var profiles: [Profile] = []
    var isAdmin = false
    var lastSync: Date?

    init() {}
    static func key(_ key: RecordKey) -> String { "\(key.entity.rawValue)/\(key.id.uuidString.lowercased())" }

    private enum CodingKeys: String, CodingKey {
        case projects, houses, rooms, drawings, synced, outbox, pendingAssets, notices, levels, profiles, isAdmin
        case lastSync
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        houses = try c.decodeIfPresent([House].self, forKey: .houses) ?? []
        rooms = try c.decodeIfPresent([Room].self, forKey: .rooms) ?? []
        drawings = try c.decodeIfPresent([Annotation].self, forKey: .drawings) ?? []
        synced = try c.decodeIfPresent([String: SyncedVersion].self, forKey: .synced) ?? [:]
        outbox = try c.decodeIfPresent([OutboxItem].self, forKey: .outbox) ?? []
        pendingAssets = try c.decodeIfPresent([String].self, forKey: .pendingAssets) ?? []
        notices = try c.decodeIfPresent([SyncNotice].self, forKey: .notices) ?? []
        levels = try c.decodeIfPresent([String: Int].self, forKey: .levels) ?? [:]
        profiles = try c.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        lastSync = try c.decodeIfPresent(Date.self, forKey: .lastSync)
    }

    func version(of key: RecordKey) -> SyncedVersion? { synced[Self.key(key)] }
    mutating func setVersion(_ version: SyncedVersion?, of key: RecordKey) { synced[Self.key(key)] = version }
    func isOnServer(_ key: RecordKey) -> Bool { version(of: key) != nil }
    func outboxItem(for key: RecordKey) -> OutboxItem? { outbox.first { $0.key == key } }
}

/// Reads and writes one account's `data.json` and the `assets/` folder beside it
/// (`Application Support/sitescope/accounts/<user>/`).
@MainActor final class LocalDataStore {
    let fileURL: URL
    private(set) var data: LocalData
    /// Called after each successful write, on the main actor.
    var onChange: (@MainActor (LocalData) -> Void)?
    private var pendingChange: Task<Void, Error>?

    /// Opens the file, or creates an empty one. An unreadable file is moved aside (never deleted) and a fresh one
    /// started, so a damaged cache never blocks the app; what was on the server comes back with the next sync.
    init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                data = try JSONDecoder().decode(LocalData.self, from: Data(contentsOf: fileURL))
                return
            } catch {
                _ = try Self.moveAside(fileURL)
            }
        }
        data = LocalData()
        try Self.persist(data, at: fileURL)
    }

    /// The folder of one account. The pre-account file `sitescope/local.json` is left untouched.
    static func accountFile(for user: UUID, in root: URL? = nil) -> URL {
        let base =
            root
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sitescope", isDirectory: true)
        return base.appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(user.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("data.json")
    }

    var assetRoot: URL { fileURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true) }

    /// Applies a change only after it is safely on disk. Encoding and the atomic write run off the main actor.
    /// Changes are chained, so each starts from the previous result and concurrent edits cannot overwrite each other.
    func change(_ operation: @escaping @MainActor (inout LocalData) throws -> Void) async throws {
        let previous = pendingChange
        let url = fileURL
        let change = Task { @MainActor in
            _ = await previous?.result
            var next = self.data
            try operation(&next)
            let snapshot = next
            try await Task.detached(priority: .userInitiated) { try Self.persist(snapshot, at: url) }.value
            self.data = snapshot
            self.onChange?(snapshot)
        }
        pendingChange = change
        try await change.value
    }

    /// Resolves a relative asset path inside `assets/`; absolute paths and `..` are rejected.
    func assetURL(_ path: String) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw AppError.message("Invalid file path.")
        }
        return assetRoot.appendingPathComponent(path)
    }
    func hasAsset(_ path: String) -> Bool {
        (try? assetURL(path)).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }
    func readAsset(path: String) throws -> Data { try Data(contentsOf: assetURL(path)) }
    func writeAsset(path: String, data: Data) throws {
        let url = try assetURL(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Moves an unreadable file aside and returns the backup location.
    static func moveAside(_ url: URL) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.deletingLastPathComponent().appendingPathComponent("data-unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: url, to: backup)
        return backup
    }

    /// Nonisolated so encoding and the write run off the main actor.
    /// The atomic write means a crash never leaves a half-written file.
    private nonisolated static func persist(_ data: LocalData, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: url, options: .atomic)
    }
}
