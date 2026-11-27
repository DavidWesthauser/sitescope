import Foundation

/// Supabase storage. Knows the table, RPC and bucket names; access rules are enforced by RLS on the server.
@MainActor final class CloudRepository: DataRepository, ProjectSharing {
    private let backend: Backend
    init(backend: Backend) { self.backend = backend }

    var userID: UUID? { backend.user?.id }

    func loadProjects() async throws -> [Project] {
        try await backend.list("projects", query: "&order=name")
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

    func createProject(_ project: Project) async throws { try await backend.insert("projects", value: project) }
    func renameProject(_ project: Project, to name: String) async throws {
        try await backend.update("projects", id: project.id, value: ["name": name])
    }
    func deleteProject(_ project: Project) async throws { try await backend.delete("projects", id: project.id) }

    func createRoom(_ room: Room) async throws { try await backend.insert("rooms", value: room) }
    func renameRoom(_ room: Room, to name: String) async throws {
        try await backend.update("rooms", id: room.id, value: ["name": name])
    }
    func deleteRoom(_ room: Room) async throws { try await backend.delete("rooms", id: room.id) }
    func publishRoom(_ room: Room) async throws {
        try room.validate()
        try await backend.update("rooms", id: room.id, value: room)
    }

    /// Workers have no update right on `annotations`; they change the status through the `set_task_status` RPC.
    func saveTask(_ item: Annotation, in room: Room, asManager: Bool) async throws {
        try item.validate(room: room)
        if asManager {
            try await backend.update("annotations", id: item.id, value: item)
        } else {
            try await backend.rpc(
                "set_task_status", arguments: ["task": item.id.uuidString, "new_status": item.status.rawValue])
        }
    }
    func saveInstruction(_ item: Annotation, in room: Room, replacing: Bool) async throws {
        try RecordRules.checkInstruction(item, in: room)
        if replacing {
            try await backend.update("annotations", id: item.id, value: item)
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

    func members(of project: Project) async throws -> [Membership] {
        try await backend.list("memberships", query: "&project_id=eq.\(project.id)")
    }
    func share(_ project: Project, withEmail email: String) async throws {
        try await backend.rpc("share_project", arguments: ["project": project.id.uuidString, "worker_email": email])
    }
    func revoke(_ member: Membership, from project: Project) async throws {
        try await backend.rpc(
            "revoke_worker", arguments: ["project": project.id.uuidString, "worker": member.user_id.uuidString])
    }
}
