import Foundation

/// Supabase storage for the design in docs/DATABASE_API.md. Knows the table and RPC names; every right is enforced
/// by RLS and triggers on the server. The design has no tables for AR scans and instructions yet (T-029), so those
/// calls report that instead of failing with a server error.
@MainActor final class CloudRepository: DataRepository, AccessManagement {
    private let backend: Backend
    init(backend: Backend) { self.backend = backend }

    var userID: UUID? { backend.user?.id }

    // MARK: Projects, houses, rooms

    /// RLS returns only what the user may see, including projects they only navigate through.
    func loadProjects() async throws -> [Project] {
        try await backend.list("projects", query: "&order=name")
    }
    func loadHouses(of project: Project) async throws -> [House] {
        try await backend.list("houses", query: "&project_id=eq.\(project.id)&order=name")
    }
    func loadRooms(of house: House) async throws -> [Room] {
        try await backend.list("rooms", query: "&house_id=eq.\(house.id)&order=name")
    }
    func loadRoom(id: UUID) async throws -> Room {
        let values: [Room] = try await backend.list("rooms", query: "&id=eq.\(id)")
        guard let room = values.first else { throw AppError.message("Room no longer exists or access was removed.") }
        return room
    }

    /// The creator becomes responsible (trigger `set_creator`).
    func createProject(_ project: Project) async throws {
        try await backend.insert("projects", value: NewProject(id: project.id, name: project.name))
    }
    func renameProject(_ project: Project, to name: String) async throws {
        try await backend.update("projects", id: project.id, value: ["name": name])
    }
    func deleteProject(_ project: Project) async throws { try await backend.delete("projects", id: project.id) }

    func createHouse(_ house: House) async throws {
        try await backend.insert(
            "houses", value: NewHouse(id: house.id, project_id: house.project_id, name: house.name))
    }
    func renameHouse(_ house: House, to name: String) async throws {
        try await backend.update("houses", id: house.id, value: ["name": name])
    }
    func deleteHouse(_ house: House) async throws { try await backend.delete("houses", id: house.id) }

    func createRoom(_ room: Room) async throws { try await backend.insert("rooms", value: NewRoom(room: room)) }
    func renameRoom(_ room: Room, to name: String) async throws {
        try await backend.update("rooms", id: room.id, value: ["name": name])
    }
    func updateRoomDetails(_ room: Room) async throws {
        try await backend.update("rooms", id: room.id, value: RoomDetailsUpdate(room: room))
    }
    func deleteRoom(_ room: Room) async throws { try await backend.delete("rooms", id: room.id) }

    // MARK: AR data (no tables yet, T-029)

    private var arUnavailable: AppError {
        AppError.message("Saving scans and instructions in the cloud is not available yet (T-029).")
    }
    func loadAnnotations(of room: Room) async throws -> [Annotation] { [] }
    func publishRoom(_ room: Room) async throws { throw arUnavailable }
    func saveTask(_ item: Annotation, in room: Room, canEdit: Bool) async throws { throw arUnavailable }
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws { throw arUnavailable }
    func deleteTask(_ item: Annotation) async throws { throw arUnavailable }
    func downloadAsset(path: String) async throws -> Data { throw arUnavailable }
    func uploadAsset(path: String, data: Data, type: String) async throws { throw arUnavailable }

    // MARK: Rights

    func level(on scope: AccessScope) async throws -> AccessLevel {
        let value = try await backend.rpc("scope_level", body: ScopeArguments(scope: scope), returning: Int.self)
        return AccessLevel(serverValue: value)
    }
    func isAdmin() async throws -> Bool {
        try await backend.rpc("is_admin", body: [String: String](), returning: Bool.self)
    }

    /// `access_grants` has two foreign keys to `profiles`, so the embed names the constraint.
    func grants(on scope: AccessScope) async throws -> [AccessGrant] {
        let house = scope.houseID.map { "eq.\($0)" } ?? "is.null"
        let room = scope.roomID.map { "eq.\($0)" } ?? "is.null"
        return try await backend.list(
            "access_grants", select: "*,user:profiles!access_grants_user_id_fkey(display_name)",
            query: "&project_id=eq.\(scope.project.id)&house_id=\(house)&room_id=\(room)&order=created_at")
    }
    func grant(_ role: AccessRole, on scope: AccessScope, toEmail email: String) async throws {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { throw AppError.message("Enter the person's email.") }
        try await backend.rpc("grant_access", body: GrantArguments(email: address, role: role, scope: scope))
    }
    func revoke(_ grant: AccessGrant) async throws {
        try await backend.rpc("revoke_access", arguments: ["grant_id": grant.id.uuidString])
    }
    func setResponsible(_ person: UUID, of scope: AccessScope) async throws {
        let update = ResponsibleUpdate(responsible_id: person)
        switch scope {
        case .project(let project): try await backend.update("projects", id: project.id, value: update)
        case .house(_, let house): try await backend.update("houses", id: house.id, value: update)
        case .room(_, _, let room): try await backend.update("rooms", id: room.id, value: update)
        }
    }

    // MARK: People and organizations

    func profiles() async throws -> [Profile] {
        try await backend.list("profiles", query: "&order=display_name")
    }
    func setDisplayName(_ name: String, of profile: Profile) async throws {
        try await backend.update("profiles", key: "user_id", id: profile.user_id, value: ["display_name": name])
    }
    func setActive(_ active: Bool, of profile: Profile) async throws {
        try await backend.update("profiles", key: "user_id", id: profile.user_id, value: ["is_active": active])
    }
    func setOrganization(_ organization: UUID?, of profile: Profile) async throws {
        try await backend.update(
            "profiles", key: "user_id", id: profile.user_id,
            value: OrganizationAssignment(organization_id: organization))
    }
    func organizations() async throws -> [Organization] {
        try await backend.list("organizations", query: "&order=name")
    }
    func saveOrganization(_ organization: Organization, isNew: Bool) async throws {
        if isNew {
            try await backend.insert(
                "organizations", value: OrganizationRecord(organization: organization, includesID: true))
        } else {
            try await backend.update(
                "organizations", id: organization.id,
                value: OrganizationRecord(organization: organization, includesID: false))
        }
    }
}
