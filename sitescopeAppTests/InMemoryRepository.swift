import Foundation

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

/// Storage for tests that need records and files but no server: keeps everything in memory, one instance per test.
@MainActor final class InMemoryRepository: DataRepository {
    var projects: [Project] = []
    var houses: [House] = []
    var rooms: [Room] = []
    var annotations: [Annotation] = []
    var assets: [String: Data] = [:]
    let userID: UUID? = UUID()

    func loadProjects() async throws -> [Project] { projects }
    func loadHouses(of project: Project) async throws -> [House] { houses.filter { $0.project_id == project.id } }
    func loadRooms(of house: House) async throws -> [Room] { rooms.filter { $0.house_id == house.id } }
    func loadRoom(id: UUID) async throws -> Room {
        guard let room = rooms.first(where: { $0.id == id }) else { throw AppError.message("Room fixture missing") }
        return room
    }
    func loadAnnotations(of room: Room) async throws -> [Annotation] { annotations.filter { $0.room_id == room.id } }

    func createProject(_ project: Project) async throws { projects.append(project) }
    func renameProject(_ project: Project, to name: String) async throws {
        projects = projects.map {
            $0.id == project.id ? Project(id: $0.id, name: name, responsible_id: $0.responsible_id) : $0
        }
    }
    func deleteProject(_ project: Project) async throws { projects.removeAll { $0.id == project.id } }

    func createHouse(_ house: House) async throws { houses.append(house) }
    func renameHouse(_ house: House, to name: String) async throws {
        if let i = houses.firstIndex(where: { $0.id == house.id }) { houses[i].name = name }
    }
    func deleteHouse(_ house: House) async throws { houses.removeAll { $0.id == house.id } }

    func createRoom(_ room: Room) async throws { rooms.append(room) }
    func renameRoom(_ room: Room, to name: String) async throws {
        if let i = rooms.firstIndex(where: { $0.id == room.id }) { rooms[i].name = name }
    }
    func updateRoomDetails(_ room: Room) async throws {
        if let i = rooms.firstIndex(where: { $0.id == room.id }) { rooms[i] = room }
    }
    func deleteRoom(_ room: Room) async throws { rooms.removeAll { $0.id == room.id } }
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        if let i = rooms.firstIndex(where: { $0.id == room.id }) { rooms[i] = room }
    }

    func saveTask(_ item: Annotation, in room: Room, canEdit: Bool) async throws {
        try await saveInstruction(item, in: room, replacing: true)
    }
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws {
        try RecordRules.checkInstruction(item, in: room)
        annotations.removeAll { $0.id == item.id }
        annotations.append(item)
    }
    func deleteTask(_ item: Annotation) async throws { annotations.removeAll { $0.id == item.id } }

    func downloadAsset(path: String) async throws -> Data {
        guard let data = assets[path] else { throw AppError.message("Asset fixture missing") }
        return data
    }
    func uploadAsset(path: String, data: Data, type: String) async throws { assets[path] = data }
}
