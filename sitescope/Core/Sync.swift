import Foundation

// Offline-first sync rules (T-008): changes are saved on the phone, queued, and uploaded with the server revision
// they were based on (T-029). These types decide what to upload and how to merge; they do no I/O.

/// A JSON value, so records of any type can be compared and merged field by field.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
    public var integer: Int? {
        if case .number(let value) = self, value.rounded() == value { return Int(value) }
        return nil
    }
}
public typealias JSONObject = [String: JSONValue]

/// Converts records to and from field dictionaries.
public enum RecordCoding {
    public static func object<T: Encodable>(_ value: T) throws -> JSONObject {
        let value = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
        guard case .object(let object) = value else { throw SyncError.notARecord }
        return object
    }
    public static func decode<T: Decodable>(_ type: T.Type, from object: JSONObject) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(JSONValue.object(object)))
    }
}

public enum SyncError: Error, Equatable {
    case notARecord
}

/// The record types that sync, in the order parents must exist on the server: projects, houses, rooms, drawings.
public enum SyncEntity: String, Codable, CaseIterable, Comparable, Sendable {
    case project, house, room, drawing

    public var table: String {
        switch self {
        case .project: return "projects"
        case .house: return "houses"
        case .room: return "rooms"
        case .drawing: return "drawings"
        }
    }
    /// Columns the app changes after creating a record (T-029 grants exactly these).
    public var writableFields: [String] {
        switch self {
        case .project, .house: return ["name"]
        case .room: return ["name", "description"] + Self.scanFields
        case .drawing: return ["pose", "points", "strokes", "image"]
        }
    }
    /// Columns sent when creating a record.
    public var insertFields: [String] {
        switch self {
        case .project: return ["id", "name"]
        case .house: return ["id", "project_id", "name"]
        case .room: return ["id", "house_id", "project_id", "coordinate_id"] + writableFields
        case .drawing: return ["id", "room_id", "coordinate_id", "kind"] + writableFields
        }
    }
    /// A room's scan. Once the server has a scan, these never change (trigger `preserve_room_map`).
    public static let scanFields = ["map_path", "scan_guide_jpeg", "surfaces", "spatial_version"]

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    public static func < (lhs: SyncEntity, rhs: SyncEntity) -> Bool { lhs.order < rhs.order }
}

/// Identifies one record across types.
public struct RecordKey: Codable, Hashable, Sendable {
    public let entity: SyncEntity
    public let id: UUID
    public init(_ entity: SyncEntity, _ id: UUID) {
        self.entity = entity
        self.id = id
    }
}

/// What to do when the phone and the server changed the same field since the last sync. H-002 is still open, so the
/// rule is one swappable type.
public protocol ConflictPolicy: Sendable {
    func choose(field: String, local: JSONValue, remote: JSONValue) -> JSONValue
}

/// The default rule: the change that reaches the server last wins. The phone's change is being uploaded now, after
/// the server's, so it wins. The overwritten server value is reported as a notice, never dropped silently.
public struct LastChangeWins: ConflictPolicy {
    public init() {}
    public func choose(field: String, local: JSONValue, remote: JSONValue) -> JSONValue { local }
}

public enum MergeResult: Equatable, Sendable {
    /// The record to write, and the fields where both sides changed (decided by the policy).
    case merged(JSONObject, conflicts: [String])
    /// The phone has a new scan but the server already has a different one: the phone's scan becomes a new room.
    case keepScanAsNewRoom
}

public enum FieldMerge {
    /// Three-way merge of one record: `base` is the server version the phone last saw (nil for a record the phone
    /// created), `local` the phone's version, `remote` the server's current version.
    /// Fields only the phone changed take the phone's value; fields only the server changed keep the server's;
    /// fields both changed go to `policy`. A published scan on the server is never overwritten.
    public static func merge(
        _ entity: SyncEntity, base: JSONObject?, local: JSONObject, remote: JSONObject,
        policy: ConflictPolicy = LastChangeWins()
    ) -> MergeResult {
        func value(_ object: JSONObject?, _ field: String) -> JSONValue { object?[field] ?? .null }
        func changed(_ object: JSONObject, _ field: String) -> Bool {
            guard let base else { return true }
            return value(object, field) != value(base, field)
        }
        if entity == .room, changed(local, "map_path"), value(remote, "map_path") != .null,
            value(remote, "map_path") != value(local, "map_path")
        {
            return .keepScanAsNewRoom
        }
        var merged = remote
        var conflicts: [String] = []
        for field in entity.writableFields {
            let mine = value(local, field)
            let theirs = value(remote, field)
            guard changed(local, field), mine != theirs else { continue }
            if entity == .room, SyncEntity.scanFields.contains(field), value(remote, "map_path") != .null {
                continue  // The server's scan stays as it is.
            }
            if base != nil, changed(remote, field) {
                merged[field] = policy.choose(field: field, local: mine, remote: theirs)
                conflicts.append(field)
            } else {
                merged[field] = mine
            }
        }
        return .merged(merged, conflicts: conflicts)
    }
}

/// One waiting upload. A record has at most one entry; files referenced by records are tracked separately and go up
/// right before the record that needs them.
public struct OutboxItem: Codable, Equatable, Identifiable, Sendable {
    public enum Action: String, Codable, Sendable { case upsert, delete }
    public var id: RecordKey { key }
    public let key: RecordKey
    public var action: Action
    /// Attempts that failed for a reason other than being offline.
    public var failures: Int = 0
    /// Set when the server refused the change; the user can retry it.
    public var lastError: String?
    public init(key: RecordKey, action: Action) {
        self.key = key
        self.action = action
    }
}

public enum Outbox {
    /// Adds a change to the queue without duplicates. A delete replaces a waiting upload; a delete of a record that
    /// never reached the server just removes it from the queue.
    public static func enqueue(
        _ action: OutboxItem.Action, for key: RecordKey, existsOnServer: Bool, into queue: inout [OutboxItem]
    ) {
        let waiting = queue.firstIndex { $0.key == key }
        switch action {
        case .upsert:
            if let waiting {
                guard queue[waiting].action == .upsert else { return }  // A deleted record cannot be edited.
                queue[waiting].failures = 0
                queue[waiting].lastError = nil
            } else {
                queue.append(OutboxItem(key: key, action: .upsert))
            }
        case .delete:
            if let waiting { queue.remove(at: waiting) }
            if existsOnServer { queue.append(OutboxItem(key: key, action: .delete)) }
        }
    }
    /// Upload order: creates and edits parents first; deletes children first, after all edits.
    public static func ordered(_ queue: [OutboxItem]) -> [OutboxItem] {
        let upserts = queue.filter { $0.action == .upsert }.enumerated().sorted {
            ($0.element.key.entity, $0.offset) < ($1.element.key.entity, $1.offset)
        }.map(\.element)
        let deletes = queue.filter { $0.action == .delete }.enumerated().sorted {
            ($0.element.key.entity, $0.offset) > ($1.element.key.entity, $1.offset)
        }.map(\.element)
        return upserts + deletes
    }
}

/// Something sync resolved on the user's behalf, shown until they dismiss it.
public struct SyncNotice: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let text: String
    public init(text: String, date: Date = Date()) {
        id = UUID()
        self.date = date
        self.text = text
    }
}

/// How far one record is on its way to the server.
public enum ItemSyncState: Equatable, Sendable {
    case synced
    case waiting
    case failed(String)
}
