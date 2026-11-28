import Foundation

/// The server side of sync: plain reads and conditional writes of whole rows (T-029). Every write carries the
/// revision the phone based it on; an empty answer means someone else changed or deleted the row meanwhile.
@MainActor protocol RemoteSyncing: AnyObject {
    /// Every row of a table the user may see (RLS filters them).
    func fetchAll(_ entity: SyncEntity) async throws -> [JSONObject]
    func fetch(_ key: RecordKey) async throws -> JSONObject?
    /// Creates the row with the phone's id. Throws `HTTPFailure` 409 when it already exists.
    func insert(_ entity: SyncEntity, _ fields: JSONObject) async throws -> JSONObject
    /// The updated row, or nil when its revision is no longer `revision` (or it was deleted).
    func update(_ key: RecordKey, revision: Int, _ fields: JSONObject) async throws -> JSONObject?
    /// True when the row was deleted; false when its revision changed or it was already gone.
    func delete(_ key: RecordKey, revision: Int) async throws -> Bool
    func upload(path: String, data: Data, type: String) async throws
    func download(path: String) async throws -> Data
}

/// Supabase for sync and for rights. Knows table, RPC and bucket names; every right is enforced by RLS.
@MainActor final class RemoteStore: RemoteSyncing, AccessManagement {
    private let backend: Backend
    init(backend: Backend) { self.backend = backend }

    // MARK: Sync

    private func rows(_ data: Data) throws -> [JSONObject] { try JSONDecoder().decode([JSONObject].self, from: data) }
    private func body(_ fields: JSONObject) throws -> Data { try JSONEncoder().encode(fields) }
    private func filter(_ key: RecordKey) -> String { "id=eq.\(key.id.uuidString.lowercased())" }

    func fetchAll(_ entity: SyncEntity) async throws -> [JSONObject] {
        try rows(await backend.send("GET", "/rest/v1/\(entity.table)?select=*"))
    }
    func fetch(_ key: RecordKey) async throws -> JSONObject? {
        try rows(await backend.send("GET", "/rest/v1/\(key.entity.table)?select=*&\(filter(key))")).first
    }
    func insert(_ entity: SyncEntity, _ fields: JSONObject) async throws -> JSONObject {
        let result = try rows(
            await backend.send("POST", "/rest/v1/\(entity.table)", body: body(fields), prefer: "return=representation"))
        guard let row = result.first else { throw AppError.message("The server did not return the new record.") }
        return row
    }
    func update(_ key: RecordKey, revision: Int, _ fields: JSONObject) async throws -> JSONObject? {
        try rows(
            await backend.send(
                "PATCH", "/rest/v1/\(key.entity.table)?\(filter(key))&revision=eq.\(revision)", body: body(fields),
                prefer: "return=representation")
        ).first
    }
    func delete(_ key: RecordKey, revision: Int) async throws -> Bool {
        try !rows(
            await backend.send(
                "DELETE", "/rest/v1/\(key.entity.table)?\(filter(key))&revision=eq.\(revision)",
                prefer: "return=representation")
        ).isEmpty
    }
    /// Files are never overwritten, so a file that already exists from an earlier, interrupted upload counts as done.
    func upload(path: String, data: Data, type: String) async throws {
        do {
            try await backend.upload(path: path, data: data, type: type)
        } catch let failure as HTTPFailure
            where failure.status == 409 || failure.message.localizedCaseInsensitiveContains("already exists")
        {
            return
        }
    }
    func download(path: String) async throws -> Data { try await backend.download(path: path) }

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
