import SwiftUI

/// On-device persistence while cloud accounts are not configured. Starts empty.
private struct LocalData: Codable, Sendable {
    var projects: [Project] = []; var rooms: [Room] = []; var annotations: [Annotation] = []
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

@MainActor final class Store: ObservableObject {
    @Published var projects: [Project] = []
    @Published var rooms: [Room] = []
    @Published var annotations: [Annotation] = []
    @Published var signedIn = false
    @Published var busy = false
    @Published var error: String?
    @Published private(set) var isLocalMode = false
    /// Set when on-device data exists but cannot be decoded. The file is left untouched until the user chooses to start fresh.
    @Published private(set) var unreadableLocalData: URL?
    let backend: Backend?
    private var localURL: URL?
    private var pendingLocalChange: Task<Void, Error>?
    init() {
        do { let client = Backend(config: try .load()); backend = client; signedIn = client.user != nil }
        catch {
            backend = nil
            #if DEBUG && os(iOS)
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("sitescope/local.json")
            openLocal(at: url)
            #else
            self.error = error.localizedDescription
            #endif
        }
    }
    /// Explicit local storage entry point; never changes cloud authentication or Keychain.
    init(localURL: URL) { backend = nil; openLocal(at: localURL) }
    init(backend: Backend) { self.backend = backend; signedIn = backend.user != nil }
    private func openLocal(at url: URL) {
        do {
            let data: LocalData
            if FileManager.default.fileExists(atPath: url.path) { data = try JSONDecoder().decode(LocalData.self, from: Data(contentsOf: url)) }
            else { data = LocalData(); try Self.persist(data, at: url) }
            localURL = url; isLocalMode = true; signedIn = true; apply(data)
        } catch { unreadableLocalData = url; self.error = "Could not open local data: \(error.localizedDescription)" }
    }
    /// Moves the unreadable file aside (never deletes it) and opens an empty on-device store. Returns the backup location.
    @discardableResult func startFreshKeepingBackup() throws -> URL {
        guard let url = unreadableLocalData else { throw AppError.message("Local data is already readable.") }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.deletingLastPathComponent().appendingPathComponent("local-unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: url, to: backup)
        unreadableLocalData = nil; error = nil
        openLocal(at: url)
        return backup
    }
    private nonisolated static func persist(_ data: LocalData, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: url, options: .atomic)
    }
    private func apply(_ data: LocalData) { projects = data.projects; rooms = data.rooms; annotations = data.annotations }
    /// Applies a change only after it is safely on disk. Encoding and the atomic write run off the main actor;
    /// changes are chained so each one starts from the previous result and concurrent edits cannot overwrite each other.
    private func changeLocal(_ operation: @escaping @MainActor (inout LocalData) throws -> Void) async throws {
        guard isLocalMode, let localURL else { throw AppError.message("Local storage is not active.") }
        let previous = pendingLocalChange
        let change = Task { @MainActor in
            _ = await previous?.result
            var data = LocalData(projects: projects, rooms: rooms, annotations: annotations)
            try operation(&data)
            let snapshot = data
            try await Task.detached(priority: .userInitiated) { try Self.persist(snapshot, at: localURL) }.value
            apply(snapshot)
        }
        pendingLocalChange = change
        try await change.value
    }
    var userID: UUID? { isLocalMode ? LocalData.userID : backend?.user?.id }
    func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }; busy = true
        Task { defer { busy = false }; do { try await operation() } catch { self.error = error.localizedDescription } }
    }
    func client() throws -> Backend { guard let backend else { throw AppError.message(isLocalMode ? "Cloud sharing requires Supabase. Your room data is saved on this device." : "Backend is not configured. See README.") }; return backend }
    func loadProjects() async throws {
        guard !isLocalMode else { return }
        projects = try await client().list("projects", query: "&order=name")
    }
    func loadRooms(_ project: Project) async throws {
        guard !isLocalMode else { return }
        rooms = try await client().list("rooms", query: "&project_id=eq.\(project.id)&order=name")
    }
    func room(id: UUID) async throws -> Room {
        if isLocalMode, let room = rooms.first(where: { $0.id == id }) { return room }
        let values: [Room] = try await client().list("rooms", query: "&id=eq.\(id)")
        guard let room = values.first else { throw AppError.message("Room no longer exists or access was removed.") }; return room
    }
    func loadAnnotations(_ room: Room) async throws {
        guard !isLocalMode else { return }
        let values: [Annotation] = try await client().list("annotations", query: "&room_id=eq.\(room.id)&order=title")
        try room.validate(); try values.forEach { try $0.validate(room: room) }; annotations = values
    }
    private func name(_ value: String) throws -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 120 else { throw AppError.message("Use a name between 1 and 120 characters.") }; return text
    }
    func createProject(name value: String) async throws {
        guard let owner = userID else { throw AppError.message("Please sign in.") }
        let project = Project(owner_id: owner, name: try name(value))
        if isLocalMode { try await changeLocal { $0.projects.append(project) } }
        else { try await client().insert("projects", value: project); try await loadProjects() }
    }
    func renameProject(_ project: Project, name value: String) async throws {
        let title = try name(value)
        if isLocalMode { try await changeLocal { data in
            guard let i = data.projects.firstIndex(where: { $0.id == project.id }) else { throw AppError.message("Project no longer exists.") }; data.projects[i].name = title
        } } else { try await client().update("projects", id: project.id, value: ["name": title]); try await loadProjects() }
    }
    func deleteProject(_ project: Project) async throws {
        if isLocalMode { try await changeLocal { data in
            let roomIDs = Set(data.rooms.filter { $0.project_id == project.id }.map(\.id))
            data.annotations.removeAll { roomIDs.contains($0.room_id) }; data.rooms.removeAll { $0.project_id == project.id }; data.projects.removeAll { $0.id == project.id }
        } } else { try await client().delete("projects", id: project.id); try await loadProjects() }
    }
    func createRoom(in project: Project, name value: String) async throws {
        let room = Room(project_id: project.id, name: try name(value))
        if isLocalMode { try await changeLocal { $0.rooms.append(room) } }
        else { try await client().insert("rooms", value: room); try await loadRooms(project) }
    }
    func renameRoom(_ room: Room, name value: String) async throws {
        let title = try name(value)
        if isLocalMode { try await changeLocal { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == room.id }) else { throw AppError.message("Room no longer exists.") }; data.rooms[i].name = title
        } } else { try await client().update("rooms", id: room.id, value: ["name": title]) }
    }
    func deleteRoom(_ room: Room) async throws {
        if isLocalMode { try await changeLocal { data in data.annotations.removeAll { $0.room_id == room.id }; data.rooms.removeAll { $0.id == room.id } } }
        else { try await client().delete("rooms", id: room.id) }
    }
    func saveTask(_ item: Annotation, room: Room, manager: Bool) async throws {
        try item.validate(room: room)
        if isLocalMode { try await changeLocal { data in
            guard let i = data.annotations.firstIndex(where: { $0.id == item.id }) else { throw AppError.message("Task no longer exists.") }; data.annotations[i] = item
        } } else if manager { try await client().update("annotations", id: item.id, value: item) }
        else { try await client().rpc("set_task_status", arguments: ["task": item.id.uuidString, "new_status": item.status.rawValue]) }
        try await loadAnnotations(room)
    }
    func deleteTask(_ item: Annotation, room: Room) async throws {
        if isLocalMode { try await changeLocal { $0.annotations.removeAll { $0.id == item.id } } }
        else { try await client().delete("annotations", id: item.id); try await loadAnnotations(room) }
    }
}

extension Store {
    private func assetURL(_ path: String) throws -> URL {
        guard let localURL, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { throw AppError.message("Invalid asset path.") }
        return localURL.deletingLastPathComponent().appendingPathComponent("assets").appendingPathComponent(path)
    }
    func downloadAsset(path: String) async throws -> Data {
        if isLocalMode { return try Data(contentsOf: assetURL(path)) }
        return try await client().download(path: path)
    }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        if isLocalMode {
            let url = try assetURL(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } else { try await client().upload(path: path, data: data, type: type) }
    }
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        if isLocalMode { try await changeLocal { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == room.id }), data.rooms[i].coordinate_id == room.coordinate_id else { throw AppError.message("Room coordinate system changed. Reopen the room.") }
            let old = data.rooms[i]
            if old.map_path != nil && (old.map_path != room.map_path || old.scan_guide_jpeg != room.scan_guide_jpeg || old.marker != room.marker || old.reference_points != room.reference_points || old.reference_notes != room.reference_notes || old.surfaces != room.surfaces) { throw AppError.message("Published room maps cannot be replaced. Create a new room for remapping.") }
            data.rooms[i] = room
        } } else { try await client().update("rooms", id: room.id, value: room) }
    }
    func saveInstruction(_ item: Annotation, room: Room, replacing: Bool) async throws {
        try item.validate(room: room)
        guard room.map_path != nil else { throw AppError.message("Map the room before placing instructions.") }
        if isLocalMode { try await changeLocal { data in
            guard data.rooms.contains(where: { $0.id == room.id && $0.coordinate_id == room.coordinate_id && $0.map_path != nil }) else { throw AppError.message("Saved room map unavailable.") }
            if replacing {
                guard let i = data.annotations.firstIndex(where: { $0.id == item.id && $0.room_id == room.id }) else { throw AppError.message("Instruction no longer exists.") }
                data.annotations[i] = item
            } else { data.annotations.append(item) }
        } } else if replacing { try await client().update("annotations", id: item.id, value: item) }
        else { try await client().insert("annotations", value: item) }
    }
}

extension Store {
    /// A portable copy of a local project. The share UI owns cleanup of the returned temporary folder.
    func exportProjectFile(_ project: Project) async throws -> URL {
        guard isLocalMode, let localURL else {
            throw AppError.message("Project files are available for projects saved on this device. Cloud projects use project sharing.")
        }
        guard let saved = projects.first(where: { $0.id == project.id }) else { throw AppError.message("Project no longer exists.") }
        var exportedRooms = rooms.filter { $0.project_id == saved.id }
        // The current workflow uses room-map recognition; obsolete recovery targets are not transferred.
        for index in exportedRooms.indices {
            exportedRooms[index].marker = nil; exportedRooms[index].reference_points = []; exportedRooms[index].reference_notes = ""
        }
        let roomIDs = Set(exportedRooms.map(\.id))
        let exportedAnnotations = annotations.filter { roomIDs.contains($0.room_id) }
        let assetRoot = localURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("sitescope-Export-\(UUID().uuidString)", isDirectory: true)
        let file = destination.appendingPathComponent("sitescope-\(saved.id.uuidString.prefix(8)).sitescope")
        let snapshotRooms = exportedRooms
        return try await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)
                try ProjectTransferArchive.write(project: saved, rooms: snapshotRooms, annotations: exportedAnnotations, assetRoot: assetRoot, to: file)
                return file
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }.value
    }

    /// Imports an independent copy; existing projects, identifiers and coordinate systems are never replaced.
    func importProjectFile(from source: URL) async throws -> Project {
        guard isLocalMode, let localURL, let owner = userID else {
            throw AppError.message("Import a project file in on-device mode. Cloud projects use project sharing.")
        }
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let stage = localURL.deletingLastPathComponent().appendingPathComponent(".sitescope-transfer-\(UUID().uuidString)", isDirectory: true)
        let extracted = stage.appendingPathComponent("extracted", isDirectory: true)
        let assetsRoot = localURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
        var installedAssets: URL?
        do {
            let manifest = try await Task.detached(priority: .userInitiated) {
                try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
                return try ProjectTransferArchive.read(from: source, extractTo: extracted)
            }.value
            try Task.checkCancellation()
            var identifiers = Set(projects.map(\.id) + rooms.map(\.id) + annotations.map(\.id))
            func newID() -> UUID {
                var id = UUID()
                while !identifiers.insert(id).inserted { id = UUID() }
                return id
            }
            let project = Project(id: newID(), owner_id: owner, name: try name(manifest.project.name))
            var roomIDs: [UUID: UUID] = [:]
            for room in manifest.rooms { roomIDs[room.id] = newID() }
            var paths: [String: String] = [:]
            for asset in manifest.assets {
                let parts = asset.path.split(separator: "/", omittingEmptySubsequences: false)
                guard parts.count >= 3, let oldRoom = UUID(uuidString: String(parts[1])), let newRoom = roomIDs[oldRoom] else {
                    throw ProjectTransferArchive.Failure.invalidProject
                }
                paths[asset.path] = "\(project.id.uuidString.lowercased())/\(newRoom.uuidString.lowercased())/" + parts.dropFirst(2).joined(separator: "/")
            }
            func remap(_ path: String) throws -> String {
                guard let mapped = paths[path] else { throw ProjectTransferArchive.Failure.missingAsset }
                return mapped
            }
            var importedRooms: [Room] = []
            for original in manifest.rooms {
                guard let id = roomIDs[original.id] else { throw ProjectTransferArchive.Failure.invalidProject }
                var room = original
                room.id = id; room.project_id = project.id; room.name = try name(original.name)
                room.marker = nil; room.reference_points = []; room.reference_notes = ""
                room.map_path = try original.map_path.map(remap)
                try room.validate(); importedRooms.append(room)
            }
            let newRooms = Dictionary(uniqueKeysWithValues: importedRooms.map { ($0.id, $0) })
            var importedAnnotations: [Annotation] = []
            for original in manifest.annotations {
                guard let roomID = roomIDs[original.room_id], let room = newRooms[roomID] else { throw ProjectTransferArchive.Failure.invalidProject }
                var annotation = original
                annotation.id = newID(); annotation.room_id = roomID
                if var image = annotation.image { image.path = try remap(image.path); annotation.image = image }
                try annotation.validate(room: room); importedAnnotations.append(annotation)
            }
            let assetCopies = manifest.assets.map { (source: $0.path, destination: paths[$0.path]!) }
            let projectAssets = assetsRoot.appendingPathComponent(project.id.uuidString.lowercased(), isDirectory: true)
            try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                try fm.createDirectory(at: assetsRoot, withIntermediateDirectories: true)
                let attributes = try fm.attributesOfItem(atPath: assetsRoot.path)
                guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw ProjectTransferArchive.Failure.unsafeFile }
                guard !fm.fileExists(atPath: projectAssets.path) else { throw ProjectTransferArchive.Failure.destinationExists }
                let prepared = stage.appendingPathComponent("prepared-assets", isDirectory: true)
                try fm.createDirectory(at: prepared, withIntermediateDirectories: false)
                for copy in assetCopies {
                    // The archive codec has already validated each path and extracted regular files.
                    let suffix = copy.destination.split(separator: "/").dropFirst().joined(separator: "/")
                    let target = prepared.appendingPathComponent(suffix)
                    try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: extracted.appendingPathComponent(copy.source), to: target)
                }
                // FileManager refuses an existing destination. Only this new project's asset tree moves.
                try fm.moveItem(at: prepared, to: projectAssets)
            }.value
            installedAssets = projectAssets
            try Task.checkCancellation()
            let roomsToAdd = importedRooms, annotationsToAdd = importedAnnotations
            try await changeLocal { data in
                guard !data.projects.contains(where: { $0.id == project.id }),
                      Set(data.rooms.map(\.id)).isDisjoint(with: roomsToAdd.map(\.id)),
                      Set(data.annotations.map(\.id)).isDisjoint(with: annotationsToAdd.map(\.id)) else { throw ProjectTransferArchive.Failure.destinationExists }
                data.projects.append(project); data.rooms.append(contentsOf: roomsToAdd); data.annotations.append(contentsOf: annotationsToAdd)
            }
            await Task.detached { try? FileManager.default.removeItem(at: stage) }.value
            return project
        } catch {
            let rollback = installedAssets
            await Task.detached {
                if let rollback { try? FileManager.default.removeItem(at: rollback) }
                try? FileManager.default.removeItem(at: stage)
            }.value
            throw error
        }
    }
}
