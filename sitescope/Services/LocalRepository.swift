import Foundation

/// Local-first storage (T-008): every change is written to the phone, queued for upload, and then `changed` asks
/// the sync engine to upload it. Works the same with and without network. Deleting cascades on the phone as the
/// database does on the server, so only the deleted parent is queued.
@MainActor final class LocalRepository: DataRepository {
    let storage: LocalDataStore
    /// Called after every change, so sync can start.
    var changed: (@MainActor () -> Void)?
    /// Reads a file from the server when the phone does not have it.
    var fetchAsset: (@MainActor (String) async throws -> Data)?

    init(storage: LocalDataStore) { self.storage = storage }

    private func save(_ operation: @escaping @MainActor (inout LocalData) throws -> Void) async throws {
        try await storage.change(operation)
        changed?()
    }
    private static func queue(_ action: OutboxItem.Action, _ key: RecordKey, in data: inout LocalData) {
        let label = action == .delete ? data.name(of: key) : nil
        Outbox.enqueue(action, for: key, existsOnServer: data.isOnServer(key), label: label, into: &data.outbox)
    }
    /// Forgets the queued changes and server versions of records removed together with their parent.
    private static func forget(_ entity: SyncEntity, _ ids: [UUID], in data: inout LocalData) {
        for id in ids {
            let key = RecordKey(entity, id)
            data.outbox.removeAll { $0.key == key }
            data.setVersion(nil, of: key)
        }
    }

    // MARK: Projects

    func createProject(_ project: Project) async throws {
        try await save { data in
            data.projects.append(project)
            Self.queue(.upsert, RecordKey(.project, project.id), in: &data)
        }
    }
    func renameProject(_ project: Project, to name: String) async throws {
        try await save { data in
            guard let i = data.projects.firstIndex(where: { $0.id == project.id }) else {
                throw AppError.message("This project no longer exists.")
            }
            data.projects[i].name = name
            Self.queue(.upsert, RecordKey(.project, project.id), in: &data)
        }
    }
    func deleteProject(_ project: Project) async throws {
        try await save { data in
            let houses = data.houses.filter { $0.project_id == project.id }.map(\.id)
            let rooms = data.rooms.filter { $0.project_id == project.id }.map(\.id)
            let drawings = data.drawings.filter { rooms.contains($0.room_id) }.map(\.id)
            Self.forget(.house, houses, in: &data)
            Self.forget(.room, rooms, in: &data)
            Self.forget(.drawing, drawings, in: &data)
            data.drawings.removeAll { drawings.contains($0.id) }
            data.rooms.removeAll { $0.project_id == project.id }
            data.houses.removeAll { $0.project_id == project.id }
            Self.queue(.delete, RecordKey(.project, project.id), in: &data)
            data.projects.removeAll { $0.id == project.id }
        }
    }

    // MARK: Houses

    func createHouse(_ house: House) async throws {
        try await save { data in
            data.houses.append(house)
            Self.queue(.upsert, RecordKey(.house, house.id), in: &data)
        }
    }
    func renameHouse(_ house: House, to name: String) async throws {
        try await save { data in
            guard let i = data.houses.firstIndex(where: { $0.id == house.id }) else {
                throw AppError.message("This house no longer exists.")
            }
            data.houses[i].name = name
            Self.queue(.upsert, RecordKey(.house, house.id), in: &data)
        }
    }
    func deleteHouse(_ house: House) async throws {
        try await save { data in
            let rooms = data.rooms.filter { $0.house_id == house.id }.map(\.id)
            let drawings = data.drawings.filter { rooms.contains($0.room_id) }.map(\.id)
            Self.forget(.room, rooms, in: &data)
            Self.forget(.drawing, drawings, in: &data)
            data.drawings.removeAll { drawings.contains($0.id) }
            data.rooms.removeAll { $0.house_id == house.id }
            Self.queue(.delete, RecordKey(.house, house.id), in: &data)
            data.houses.removeAll { $0.id == house.id }
        }
    }

    // MARK: Rooms

    func createRoom(_ room: Room) async throws {
        try room.validate()
        try await save { data in
            data.rooms.append(room)
            Self.queue(.upsert, RecordKey(.room, room.id), in: &data)
        }
    }
    func renameRoom(_ room: Room, to name: String) async throws {
        try await updateRoom(room.id) { $0.name = name }
    }
    func describeRoom(_ room: Room, as text: String) async throws {
        guard text.count <= Room.maximumDescriptionLength else {
            throw AppError.message("Use at most \(Room.maximumDescriptionLength) characters.")
        }
        try await updateRoom(room.id) { $0.description = text }
    }
    private func updateRoom(_ id: UUID, _ edit: @escaping (inout Room) -> Void) async throws {
        try await save { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == id }) else {
                throw AppError.message("This room no longer exists.")
            }
            edit(&data.rooms[i])
            Self.queue(.upsert, RecordKey(.room, id), in: &data)
        }
    }
    func deleteRoom(_ room: Room) async throws {
        try await save { data in
            let drawings = data.drawings.filter { $0.room_id == room.id }.map(\.id)
            Self.forget(.drawing, drawings, in: &data)
            data.drawings.removeAll { $0.room_id == room.id }
            Self.queue(.delete, RecordKey(.room, room.id), in: &data)
            data.rooms.removeAll { $0.id == room.id }
        }
    }
    /// A published scan and its coordinate system never change: drawings are placed in them. A new scan of a
    /// scanned room is a new room.
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        try await save { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == room.id }),
                data.rooms[i].coordinate_id == room.coordinate_id
            else { throw AppError.message("The room's coordinate system changed. Open the room again.") }
            let old = data.rooms[i]
            if old.map_path != nil
                && (old.map_path != room.map_path || old.scan_guide_jpeg != room.scan_guide_jpeg
                    || old.surfaces != room.surfaces)
            {
                throw AppError.message("A saved scan cannot be replaced. Create a new room to scan again.")
            }
            data.rooms[i] = room
            Self.queue(.upsert, RecordKey(.room, room.id), in: &data)
        }
    }

    // MARK: Drawings

    func loadAnnotations(of room: Room) async throws -> [Annotation] {
        storage.data.drawings.filter { $0.room_id == room.id }
    }
    func saveDrawing(_ item: Annotation, in room: Room) async throws {
        try RecordRules.checkDrawing(item, in: room)
        try await save { data in
            guard
                data.rooms.contains(where: {
                    $0.id == room.id && $0.coordinate_id == room.coordinate_id && $0.map_path != nil
                })
            else { throw AppError.message("The room's scan is not available.") }
            if let i = data.drawings.firstIndex(where: { $0.id == item.id }) {
                data.drawings[i] = item
            } else {
                data.drawings.append(item)
            }
            Self.queue(.upsert, RecordKey(.drawing, item.id), in: &data)
        }
    }
    func deleteDrawing(_ item: Annotation) async throws {
        try await save { data in
            data.drawings.removeAll { $0.id == item.id }
            Self.queue(.delete, RecordKey(.drawing, item.id), in: &data)
        }
    }

    // MARK: Files

    func downloadAsset(path: String) async throws -> Data {
        if storage.hasAsset(path) { return try storage.readAsset(path: path) }
        guard let fetchAsset else { throw AppError.message("This file is not on this iPhone yet.") }
        let data = try await fetchAsset(path)
        try storage.writeAsset(path: path, data: data)
        return data
    }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        try storage.writeAsset(path: path, data: data)
        try await storage.change { if !$0.pendingAssets.contains(path) { $0.pendingAssets.append(path) } }
    }
}
