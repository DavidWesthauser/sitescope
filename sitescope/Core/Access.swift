import Foundation

/// Roles a person responsible can hand out (`access_grants.role`). Responsible and admin are not grants.
public enum AccessRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case member
    case external
    public var id: String { rawValue }
    /// Named like Apple's sharing roles; the database names are `member` and `external`.
    public var label: String {
        switch self {
        case .member: return "Can Edit"
        case .external: return "View Only"
        }
    }
    /// The same sentence wherever the role is explained (Add Person, the access footers).
    public var summary: String {
        switch self {
        case .member: return "Can add and edit rooms, scans and drawings."
        case .external: return "Can view everything, but not change it."
        }
    }
}

/// The caller's level on a project, house or room, as the `scope_level` RPC returns it.
/// Encodes the permission table in docs/DATABASE_API.md. The app uses it only to show or hide controls;
/// the database enforces the same rules, so a wrong level hides a button or makes a request fail, nothing more.
public enum AccessLevel: Int, Comparable, Codable, Sendable {
    case none = 0
    case external = 1
    case member = 2
    case responsible = 3
    case admin = 4

    /// Unknown numbers count as no access.
    public init(serverValue: Int) { self = AccessLevel(rawValue: serverValue) ?? .none }

    public static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .none: return "On the way to a shared room"
        case .external: return "External"
        case .member: return "Member"
        case .responsible: return "Responsible"
        case .admin: return "Administrator"
        }
    }

    /// See a room, read and write comments (≥ 1).
    public var canView: Bool { self >= .external }
    /// On a house: create rooms. On a room: edit name, dimensions and status (≥ 2).
    public var canContribute: Bool { self >= .member }
    /// On a project or house: edit or delete it, create houses (project). On a room: delete it.
    /// On any scope: grant and revoke access, and change who is responsible one level below (≥ 3).
    public var canManage: Bool { self >= .responsible }
    /// Change who is responsible for a project (admin only).
    public var isAdmin: Bool { self == .admin }
}

/// A place access is granted on: a whole project, a house in it, or one room. Grants on a project or house also
/// cover everything below it.
public enum AccessScope: Equatable, Sendable {
    case project(Project)
    case house(Project, House)
    case room(Project, House, Room)

    public var project: Project {
        switch self {
        case .project(let project), .house(let project, _), .room(let project, _, _): return project
        }
    }
    public var houseID: UUID? {
        switch self {
        case .project: return nil
        case .house(_, let house), .room(_, let house, _): return house.id
        }
    }
    public var roomID: UUID? {
        if case .room(_, _, let room) = self { return room.id }
        return nil
    }
    public var name: String {
        switch self {
        case .project(let project): return project.name
        case .house(_, let house): return house.name
        case .room(_, _, let room): return room.name
        }
    }
    /// Key for the phone's cache of levels, so rights are known offline.
    public var cacheKey: String {
        [project.id, houseID, roomID].map { $0?.uuidString.lowercased() ?? "-" }.joined(separator: "/")
    }
    /// Grants made exactly on this scope; inherited ones are listed where they were made.
    public func contains(_ grant: AccessGrant) -> Bool {
        grant.project_id == project.id && grant.house_id == houseID && grant.room_id == roomID
    }
}
