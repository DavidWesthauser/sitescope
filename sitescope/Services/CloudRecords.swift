import Foundation

/// Request bodies for the Supabase tables and RPCs in docs/DATABASE_API.md. Writes send only the columns clients
/// may set ("Updatable columns"); the creator, timestamps and organizations are set by the server.
/// Optional values are sent as `null`, never left out, so clearing a field works and RPCs get every argument.

struct NewProject: Encodable {
    let id: UUID
    let name: String
}

struct NewHouse: Encodable {
    let id: UUID
    let project_id: UUID
    let name: String
}

struct NewRoom: Encodable {
    let room: Room
    private enum Keys: String, CodingKey { case id, house_id, project_id, name, height, length, width, status }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(room.id, forKey: .id)
        try c.encode(room.house_id, forKey: .house_id)
        try c.encode(room.project_id, forKey: .project_id)
        try c.encode(room.name, forKey: .name)
        try c.encode(room.height, forKey: .height)
        try c.encode(room.length, forKey: .length)
        try c.encode(room.width, forKey: .width)
        try c.encode(room.status, forKey: .status)
    }
}

/// Room fields a member may change (level ≥ 2): name, dimensions, status.
struct RoomDetailsUpdate: Encodable {
    let room: Room
    private enum Keys: String, CodingKey { case name, height, length, width, status }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(room.name, forKey: .name)
        try c.encode(room.height, forKey: .height)
        try c.encode(room.length, forKey: .length)
        try c.encode(room.width, forKey: .width)
        try c.encode(room.status, forKey: .status)
    }
}

struct ResponsibleUpdate: Encodable {
    let responsible_id: UUID
}

/// `p`, `h`, `r` of `scope_level` and `grant_access`; the design gives `scope_level` no defaults.
struct ScopeArguments: Encodable {
    let scope: AccessScope
    private enum Keys: String, CodingKey { case p, h, r }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(scope.project.id, forKey: .p)
        try c.encode(scope.houseID, forKey: .h)
        try c.encode(scope.roomID, forKey: .r)
    }
}

struct GrantArguments: Encodable {
    let email: String
    let role: AccessRole
    let scope: AccessScope
    private enum Keys: String, CodingKey { case target_email, new_role }
    func encode(to encoder: Encoder) throws {
        try ScopeArguments(scope: scope).encode(to: encoder)
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(email, forKey: .target_email)
        try c.encode(role, forKey: .new_role)
    }
}

/// The columns of an organization an admin sets; the id only on insert.
struct OrganizationRecord: Encodable {
    let organization: Organization
    let includesID: Bool
    private enum Keys: String, CodingKey { case id, name, status, responsible_id }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        if includesID { try c.encode(organization.id, forKey: .id) }
        try c.encode(organization.name, forKey: .name)
        try c.encode(organization.status, forKey: .status)
        try c.encode(organization.responsible_id, forKey: .responsible_id)
    }
}

struct OrganizationAssignment: Encodable {
    let organization_id: UUID?
    private enum Keys: String, CodingKey { case organization_id }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(organization_id, forKey: .organization_id)
    }
}
