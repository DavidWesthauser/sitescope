import Foundation

/// Where projects, houses, rooms, scans and drawings are stored. Screens and the AR screen only talk to this
/// protocol; `LocalRepository` writes to the phone first and queues the change for sync (T-008).
@MainActor protocol DataRepository: AnyObject {
    func createProject(_ project: Project) async throws
    func renameProject(_ project: Project, to name: String) async throws
    func deleteProject(_ project: Project) async throws

    func createHouse(_ house: House) async throws
    func renameHouse(_ house: House, to name: String) async throws
    func deleteHouse(_ house: House) async throws

    func createRoom(_ room: Room) async throws
    func renameRoom(_ room: Room, to name: String) async throws
    func describeRoom(_ room: Room, as text: String) async throws
    func deleteRoom(_ room: Room) async throws
    /// Saves a scanned room map. A published map is never replaced.
    func publishRoom(_ room: Room) async throws

    func loadAnnotations(of room: Room) async throws -> [Annotation]
    func saveDrawing(_ item: Annotation, in room: Room) async throws
    func deleteDrawing(_ item: Annotation) async throws

    /// Reads a scan or photo; from the phone if it is there, otherwise from the server.
    func downloadAsset(path: String) async throws -> Data
    /// Saves a file on the phone; it goes to the server with the next sync.
    func uploadAsset(path: String, data: Data, type: String) async throws
}

/// Accounts and rights (docs/DATABASE_API.md, "Permissions"). These need the network; the server decides.
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
    static func checkDrawing(_ item: Annotation, in room: Room) throws {
        try item.validate(room: room)
        guard room.map_path != nil else { throw AppError.message("Scan the room before drawing in it.") }
    }
}
