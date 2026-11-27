import Foundation

/// Where projects, houses, rooms, instructions and their files are stored. View models only talk to this protocol;
/// `CloudRepository` implements it with Supabase. Every implementation validates records before it stores them.
@MainActor protocol DataRepository: AnyObject {
    /// The signed-in user.
    var userID: UUID? { get }

    func loadProjects() async throws -> [Project]
    func loadHouses(of project: Project) async throws -> [House]
    func loadRooms(of house: House) async throws -> [Room]
    func loadRoom(id: UUID) async throws -> Room
    func loadAnnotations(of room: Room) async throws -> [Annotation]

    func createProject(_ project: Project) async throws
    func renameProject(_ project: Project, to name: String) async throws
    func deleteProject(_ project: Project) async throws

    func createHouse(_ house: House) async throws
    func renameHouse(_ house: House, to name: String) async throws
    func deleteHouse(_ house: House) async throws

    func createRoom(_ room: Room) async throws
    func renameRoom(_ room: Room, to name: String) async throws
    /// Name, dimensions and status (level ≥ 2 on the room).
    func updateRoomDetails(_ room: Room) async throws
    func deleteRoom(_ room: Room) async throws
    /// Saves a scanned room map. A published map is never replaced.
    func publishRoom(_ room: Room) async throws

    /// Without edit rights only the status changes; with them the whole task.
    func saveTask(_ item: Annotation, in room: Room, canEdit: Bool) async throws
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws
    func deleteTask(_ item: Annotation) async throws

    func downloadAsset(path: String) async throws -> Data
    func uploadAsset(path: String, data: Data, type: String) async throws
}

/// Accounts and rights (docs/DATABASE_API.md, "Permissions"). The server decides; these calls read and change them.
@MainActor protocol AccessManagement: AnyObject {
    func level(on scope: AccessScope) async throws -> AccessLevel
    func isAdmin() async throws -> Bool

    func grants(on scope: AccessScope) async throws -> [AccessGrant]
    func grant(_ role: AccessRole, on scope: AccessScope, toEmail email: String) async throws
    func revoke(_ grant: AccessGrant) async throws
    /// Project: admin only. House: level ≥ 3 on the project. Room: level ≥ 3 on the house.
    func setResponsible(_ person: UUID, of scope: AccessScope) async throws

    /// Every signed-in user reads all profiles (name and organization).
    func profiles() async throws -> [Profile]
    func setDisplayName(_ name: String, of profile: Profile) async throws
    /// Admin only. Users are deactivated, never deleted.
    func setActive(_ active: Bool, of profile: Profile) async throws
    func setOrganization(_ organization: UUID?, of profile: Profile) async throws

    /// Your own organization; admins see all.
    func organizations() async throws -> [Organization]
    /// Admin only.
    func saveOrganization(_ organization: Organization, isNew: Bool) async throws
}

/// Rules checked before a write.
enum RecordRules {
    static func checkInstruction(_ item: Annotation, in room: Room) throws {
        try item.validate(room: room)
        guard room.map_path != nil else { throw AppError.message("Map the room before placing instructions.") }
    }
}
