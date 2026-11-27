import Foundation

/// On-device storage: every change goes through `LocalDataStore`, which writes it to disk first.
/// Deleting cascades to rooms and instructions, as the database does in the cloud.
@MainActor final class LocalRepository: DataRepository {
    let storage: LocalDataStore
    init(storage: LocalDataStore) { self.storage = storage }

    var userID: UUID? { LocalData.userID }

    func loadProjects() async throws -> [Project] { storage.data.projects }
    func loadRooms(of project: Project) async throws -> [Room] { storage.data.rooms }
    func loadRoom(id: UUID) async throws -> Room {
        guard let room = storage.data.rooms.first(where: { $0.id == id }) else {
            throw AppError.message("Room no longer exists or access was removed.")
        }
        return room
    }
    func loadAnnotations(of room: Room) async throws -> [Annotation] { storage.data.annotations }

    func createProject(_ project: Project) async throws {
        try await storage.change { $0.projects.append(project) }
    }
    func renameProject(_ project: Project, to name: String) async throws {
        try await storage.change { data in
            guard let i = data.projects.firstIndex(where: { $0.id == project.id }) else {
                throw AppError.message("Project no longer exists.")
            }
            data.projects[i].name = name
        }
    }
    func deleteProject(_ project: Project) async throws {
        try await storage.change { data in
            let roomIDs = Set(data.rooms.filter { $0.project_id == project.id }.map(\.id))
            data.annotations.removeAll { roomIDs.contains($0.room_id) }
            data.rooms.removeAll { $0.project_id == project.id }
            data.projects.removeAll { $0.id == project.id }
        }
    }

    func createRoom(_ room: Room) async throws {
        try await storage.change { $0.rooms.append(room) }
    }
    func renameRoom(_ room: Room, to name: String) async throws {
        try await storage.change { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == room.id }) else {
                throw AppError.message("Room no longer exists.")
            }
            data.rooms[i].name = name
        }
    }
    func deleteRoom(_ room: Room) async throws {
        try await storage.change { data in
            data.annotations.removeAll { $0.room_id == room.id }
            data.rooms.removeAll { $0.id == room.id }
        }
    }
    /// Mirrors the database trigger `preserve_coordinates`: a published map and its spatial data are immutable.
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        try await storage.change { data in
            guard let i = data.rooms.firstIndex(where: { $0.id == room.id }),
                data.rooms[i].coordinate_id == room.coordinate_id
            else { throw AppError.message("Room coordinate system changed. Reopen the room.") }
            let old = data.rooms[i]
            if old.map_path != nil
                && (old.map_path != room.map_path || old.scan_guide_jpeg != room.scan_guide_jpeg
                    || old.marker != room.marker || old.reference_points != room.reference_points
                    || old.reference_notes != room.reference_notes || old.surfaces != room.surfaces)
            {
                throw AppError.message("Published room maps cannot be replaced. Create a new room for remapping.")
            }
            data.rooms[i] = room
        }
    }

    /// On the device the user owns everything, so `asManager` does not restrict anything.
    func saveTask(_ item: Annotation, in room: Room, asManager: Bool) async throws {
        try item.validate(room: room)
        try await storage.change { data in
            guard let i = data.annotations.firstIndex(where: { $0.id == item.id }) else {
                throw AppError.message("Task no longer exists.")
            }
            data.annotations[i] = item
        }
    }
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws {
        try RecordRules.checkInstruction(item, in: room)
        try await storage.change { data in
            guard
                data.rooms.contains(where: {
                    $0.id == room.id && $0.coordinate_id == room.coordinate_id && $0.map_path != nil
                })
            else { throw AppError.message("Saved room map unavailable.") }
            if replacing {
                guard let i = data.annotations.firstIndex(where: { $0.id == item.id && $0.room_id == room.id })
                else { throw AppError.message("Instruction no longer exists.") }
                data.annotations[i] = item
            } else {
                data.annotations.append(item)
            }
        }
    }
    func deleteTask(_ item: Annotation) async throws {
        try await storage.change { $0.annotations.removeAll { $0.id == item.id } }
    }

    func downloadAsset(path: String) async throws -> Data { try storage.readAsset(path: path) }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        try storage.writeAsset(path: path, data: data)
    }
}
