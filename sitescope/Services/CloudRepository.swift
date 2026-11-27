import Foundation

/// Supabase storage (docs/DATABASE_API.md). Knows the table, RPC and bucket names; access rules are enforced by RLS
/// on the server. Row shapes that differ from the app's models are in `CloudRecords.swift`.
@MainActor final class CloudRepository: DataRepository, ProjectSharing {
    private let backend: Backend
    init(backend: Backend) { self.backend = backend }

    var userID: UUID? { backend.user?.id }

    func loadProjects() async throws -> [Project] {
        let values: [CloudProject] = try await backend.list("projects", query: "&order=name")
        return values.map(\.project)
    }
    func loadRooms(of project: Project) async throws -> [Room] {
        try await backend.list("rooms", query: "&project_id=eq.\(project.id)&order=name")
    }
    func loadRoom(id: UUID) async throws -> Room {
        let values: [Room] = try await backend.list("rooms", query: "&id=eq.\(id)")
        guard let room = values.first else { throw AppError.message("Room no longer exists or access was removed.") }
        return room
    }
    /// Server data is checked before it reaches the AR scene.
    func loadAnnotations(of room: Room) async throws -> [Annotation] {
        let values: [Annotation] = try await backend.list("annotations", query: "&room_id=eq.\(room.id)&order=title")
        try room.validate()
        for value in values { try value.validate(room: room) }
        return values
    }

    /// The creator becomes responsible on the server. The project gets its first house right away.
    func createProject(_ project: Project) async throws {
        try await backend.insert("projects", value: NewCloudProject(id: project.id, name: project.name))
        try await backend.insert(
            "houses", value: CloudHouse(id: UUID(), project_id: project.id, name: CloudHouse.defaultName))
    }
    func renameProject(_ project: Project, to name: String) async throws {
        try await backend.update("projects", id: project.id, value: ["name": name])
    }
    func deleteProject(_ project: Project) async throws { try await backend.delete("projects", id: project.id) }

    func createRoom(_ room: Room) async throws {
        try await backend.insert("rooms", value: NewCloudRoom(room: room, house_id: try await houseID(of: room)))
    }
    /// The house that holds a project's rooms until houses get their own screens (T-005): the oldest one, or a new
    /// default house when the project has none (only the person responsible may create it).
    private func houseID(of room: Room) async throws -> UUID {
        let houses: [CloudHouse] = try await backend.list(
            "houses", query: "&project_id=eq.\(room.project_id)&order=created_at&limit=1")
        if let house = houses.first { return house.id }
        let house = CloudHouse(id: UUID(), project_id: room.project_id, name: CloudHouse.defaultName)
        try await backend.insert("houses", value: house)
        return house.id
    }
    func renameRoom(_ room: Room, to name: String) async throws {
        try await backend.update("rooms", id: room.id, value: ["name": name])
    }
    func deleteRoom(_ room: Room) async throws { try await backend.delete("rooms", id: room.id) }
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        try await backend.update("rooms", id: room.id, value: RoomMapUpdate(room: room))
    }

    /// Workers have no update right on `annotations`; they change the status through the `set_task_status` RPC.
    func saveTask(_ item: Annotation, in room: Room, asManager: Bool) async throws {
        try item.validate(room: room)
        if asManager {
            try await backend.update("annotations", id: item.id, value: AnnotationUpdate(item: item))
        } else {
            try await backend.rpc(
                "set_task_status", arguments: ["task": item.id.uuidString, "new_status": item.status.rawValue])
        }
    }
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws {
        try RecordRules.checkInstruction(item, in: room)
        if replacing {
            try await backend.update("annotations", id: item.id, value: AnnotationUpdate(item: item))
        } else {
            try await backend.insert("annotations", value: item)
        }
    }
    func deleteTask(_ item: Annotation) async throws { try await backend.delete("annotations", id: item.id) }

    func downloadAsset(path: String) async throws -> Data { try await backend.download(path: path) }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        try await backend.upload(path: path, data: data, type: type)
    }

    // MARK: ProjectSharing

    /// Grants on the whole project; grants on single houses or rooms come with T-006. `access_grants` has two foreign
    /// keys to `profiles`, so the embed names the constraint.
    func members(of project: Project) async throws -> [Membership] {
        try await backend.list(
            "access_grants", select: "*,user:profiles!access_grants_user_id_fkey(display_name)",
            query: "&project_id=eq.\(project.id)&house_id=is.null&room_id=is.null&order=created_at")
    }
    /// The app's worker is the role `external`: reads everything in the project and changes task status.
    func share(_ project: Project, withEmail email: String) async throws {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { throw AppError.message("Enter the worker's email.") }
        try await backend.rpc(
            "grant_access", arguments: ["target_email": address, "new_role": "external", "p": project.id.uuidString])
    }
    func revoke(_ member: Membership, from project: Project) async throws {
        try await backend.rpc("revoke_access", arguments: ["grant_id": member.id.uuidString])
    }
}
