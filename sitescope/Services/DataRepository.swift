import Foundation

/// Where projects, rooms, instructions and their files are stored. View models only talk to this protocol:
/// `LocalRepository` keeps everything on the device, `CloudRepository` uses Supabase. Every implementation
/// validates records before it stores them.
@MainActor protocol DataRepository: AnyObject {
    /// The signed-in user, or the fixed on-device user.
    var userID: UUID? { get }

    func loadProjects() async throws -> [Project]
    /// The cloud returns the project's rooms; on-device storage returns all rooms, and views filter by project.
    func loadRooms(of project: Project) async throws -> [Room]
    func loadRoom(id: UUID) async throws -> Room
    /// The cloud returns the room's instructions; on-device storage returns all of them, and callers filter by room.
    func loadAnnotations(of room: Room) async throws -> [Annotation]

    func createProject(_ project: Project) async throws
    func renameProject(_ project: Project, to name: String) async throws
    func deleteProject(_ project: Project) async throws

    func createRoom(_ room: Room) async throws
    func renameRoom(_ room: Room, to name: String) async throws
    func deleteRoom(_ room: Room) async throws
    /// Saves a scanned room map. A published map is never replaced.
    func publishRoom(_ room: Room) async throws

    /// Workers may only change the status of a task; managers may change all of it.
    func saveTask(_ item: Annotation, in room: Room, asManager: Bool) async throws
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws
    func deleteTask(_ item: Annotation) async throws

    func downloadAsset(path: String) async throws -> Data
    func uploadAsset(path: String, data: Data, type: String) async throws
}

/// Cloud-only project sharing between accounts.
@MainActor protocol ProjectSharing: AnyObject {
    func members(of project: Project) async throws -> [Membership]
    func share(_ project: Project, withEmail email: String) async throws
    func revoke(_ member: Membership, from project: Project) async throws
}

/// Rules both repositories apply before a write.
enum RecordRules {
    static func checkInstruction(_ item: Annotation, in room: Room) throws {
        try item.validate(room: room)
        guard room.map_path != nil else { throw AppError.message("Map the room before placing instructions.") }
    }
}
