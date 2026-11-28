import Foundation

/// A `projects` row. Fields mirror the database columns (docs/DATABASE_API.md); the server sets the rest.
public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// The person responsible (access level 3). The creator by default.
    public var responsible_id: UUID?
    public init(id: UUID = UUID(), name: String, responsible_id: UUID? = nil) {
        self.id = id
        self.name = name
        self.responsible_id = responsible_id
    }
}
/// A `houses` row: a building of a project that holds rooms.
public struct House: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var project_id: UUID
    public var name: String
    public var responsible_id: UUID?
    public init(id: UUID = UUID(), project_id: UUID, name: String, responsible_id: UUID? = nil) {
        self.id = id
        self.project_id = project_id
        self.name = name
        self.responsible_id = responsible_id
    }
}
/// Printed marker used to recover room alignment; width and height are in metres.
public struct Marker: Codable, Equatable, Sendable {
    public var id: UUID
    public var image_path: String
    public var width: Double
    public var height: Double
    public var room_from_marker: Pose
    public init(id: UUID, image_path: String, width: Double, height: Double, room_from_marker: Pose) {
        self.id = id
        self.image_path = image_path
        self.width = width
        self.height = height
        self.room_from_marker = room_from_marker
    }
}
/// A room: name, description, the scan (`coordinate_id`, `map_path`, `scan_guide_jpeg`, `surfaces`) and, in
/// `Annotation`, its drawings. Columns as in the database target of T-029; missing ones decode as defaults.
public struct Room: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var project_id: UUID
    public var house_id: UUID
    public var name: String
    /// Free text about the room and the work in it; at most `maximumDescriptionLength` characters.
    public var description: String = ""
    public var responsible_id: UUID?
    public var spatial_version: Int = 1
    public var coordinate_id: UUID = UUID()
    public var map_path: String?
    /// Optional human-visible scene photo for revisiting a scan, never a localization marker.
    public var scan_guide_jpeg: String?
    public var marker: Marker?
    public var reference_points: [Point3] = []
    public var reference_notes: String = ""
    public var surfaces: [SurfacePatch]?
    public init(id: UUID = UUID(), project_id: UUID, house_id: UUID, name: String) {
        self.id = id
        self.project_id = project_id
        self.house_id = house_id
        self.name = name
    }
    private enum CodingKeys: String, CodingKey {
        case id, project_id, house_id, name, description, responsible_id
        case spatial_version, coordinate_id, map_path, scan_guide_jpeg, marker, reference_points, reference_notes
        case surfaces
    }
    public static let maximumDescriptionLength = 4000
    /// Rows from older databases lack columns; missing ones keep their defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        project_id = try c.decode(UUID.self, forKey: .project_id)
        house_id = try c.decode(UUID.self, forKey: .house_id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        responsible_id = try c.decodeIfPresent(UUID.self, forKey: .responsible_id)
        spatial_version = try c.decodeIfPresent(Int.self, forKey: .spatial_version) ?? 1
        coordinate_id = try c.decodeIfPresent(UUID.self, forKey: .coordinate_id) ?? id
        map_path = try c.decodeIfPresent(String.self, forKey: .map_path)
        scan_guide_jpeg = try c.decodeIfPresent(String.self, forKey: .scan_guide_jpeg)
        marker = try c.decodeIfPresent(Marker.self, forKey: .marker)
        reference_points = try c.decodeIfPresent([Point3].self, forKey: .reference_points) ?? []
        reference_notes = try c.decodeIfPresent(String.self, forKey: .reference_notes) ?? ""
        surfaces = try c.decodeIfPresent([SurfacePatch].self, forKey: .surfaces)
    }
    /// Rejects malformed or oversized records before they are stored or sent. The scan guide must be a
    /// strict base64 JPEG of at most 64 KiB (the 87_384-character cap is that size encoded).
    public func validate() throws {
        guard description.count <= Self.maximumDescriptionLength else { throw SpatialError.invalidGeometry }
        if let guide = scan_guide_jpeg {
            guard guide.utf8.count <= 87_384,
                let bytes = Data(base64Encoded: guide), bytes.count >= 4, bytes.count <= 65_536,
                bytes.base64EncodedString() == guide,
                bytes.starts(with: [0xff, 0xd8]), bytes.suffix(2).elementsEqual([0xff, 0xd9])
            else {
                throw SpatialError.invalidGeometry
            }
        }
        // Two reference points are the manual alignment input; zero means no manual reference was taken.
        guard spatial_version == 1, reference_points.count == 0 || reference_points.count == 2,
            reference_points.allSatisfy({ [$0.x, $0.y, $0.z].allSatisfy(\.isFinite) }),
            marker.map({ $0.width.isFinite && $0.height.isFinite && $0.width >= 0.05 && $0.width <= 2 && $0.height > 0 }
            ) ?? true
        else { throw SpatialError.incompatibleVersion }
        if reference_points.count == 2 {
            guard !reference_notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpatialError.invalidGeometry
            }
            _ = try AlignmentMath.manual(room: reference_points, session: reference_points)
        }
        guard (surfaces?.count ?? 0) <= 128 else { throw SpatialError.invalidGeometry }
        if let surfaces {
            for surface in surfaces {
                try surface.validate()
            }
        }
    }
}
public enum AnnotationKind: String, Codable, CaseIterable, Sendable { case marker, text, area, line, arrow, image }
public struct SpatialImage: Codable, Equatable, Sendable {
    public var path: String
    public var width: Float
    public var height: Float
    public init(path: String, width: Float, height: Float) {
        self.path = path
        self.width = width
        self.height = height
    }
    /// Paths must stay relative, so an imported project cannot point at files outside its own folder.
    public func validate() throws {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains(".."),
            width.isFinite, height.isFinite, width > 0.001, height > 0.001, width <= 5, height <= 5
        else { throw SpatialError.invalidGeometry }
    }
}
/// A drawing placed in a room's scan: a freehand line, a marked area or a pinned photo. It has no text of its own;
/// the room's description holds what to do. `marker`, `text` and `arrow` are no longer created (T-027).
public struct Annotation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var room_id: UUID
    public var coordinate_id: UUID
    public var kind: AnnotationKind
    public var pose: Pose
    /// Vertices local to pose. Areas close the polygon; lines/arrows connect in order.
    public var points: [Point3]
    public var strokes: [[Point3]]?
    public var image: SpatialImage?
    public init(room: Room, kind: AnnotationKind, pose: Pose, points: [Point3] = []) {
        room_id = room.id
        coordinate_id = room.coordinate_id
        self.kind = kind
        self.pose = pose
        self.points = points
    }
    /// Checks the annotation against its room. The count limits bound the size of one annotation,
    /// so a malformed or hostile import cannot exhaust memory or rendering time.
    public func validate(room: Room) throws {
        guard room_id == room.id, coordinate_id == room.coordinate_id, points.count <= 128,
            points.allSatisfy({ [$0.x, $0.y, $0.z].allSatisfy(\.isFinite) }),
            kind != .area || points.count >= 3,
            (kind != .line && kind != .arrow) || points.count >= 2
        else { throw SpatialError.invalidGeometry }
        if kind == .image {
            guard let image else { throw SpatialError.invalidGeometry }
            try image.validate()
        }
        // Zero-length segments have no direction and would make later direction math degenerate.
        if let strokes {
            guard kind == .line, !strokes.isEmpty, strokes.count <= 32, strokes.reduce(0, { $0 + $1.count }) <= 2048,
                strokes.allSatisfy({ stroke in
                    stroke.count >= 2 && stroke.count <= 256
                        && stroke.allSatisfy({ [$0.x, $0.y, $0.z].allSatisfy(\.isFinite) })
                })
            else { throw SpatialError.invalidGeometry }
            for stroke in strokes {
                for (a, b) in zip(stroke, stroke.dropFirst()) {
                    guard dot(b.vector - a.vector, b.vector - a.vector) > 0.00000001 else {
                        throw SpatialError.invalidGeometry
                    }
                }
            }
        }
        if [.area, .line, .arrow].contains(kind) {
            for (a, b) in zip(points, points.dropFirst()) {
                let d = b.vector - a.vector
                guard dot(d, d) > 0.000004 else { throw SpatialError.invalidGeometry }
            }
        }
        // An area must be flat: every vertex lies within 3 cm of the plane through the first three points.
        if kind == .area {
            let p = points.map(\.vector)
            let normal = simdCross(p[1] - p[0], p[2] - p[0])
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            guard length > 0.0001, p.allSatisfy({ abs(dot($0 - p[0], normal) / length) < 0.03 }) else {
                throw SpatialError.invalidGeometry
            }
        }
    }
}
private func simdCross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
private func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { a.x * b.x + a.y * b.y + a.z * b.z }
/// Project and room names: trimmed, 1 to 120 characters. The database enforces the same limits.
public enum DisplayName {
    public static let maximumLength = 120
    /// The trimmed name, or nil when it is empty or too long.
    public static func normalized(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || text.count > maximumLength ? nil : text
    }
}
/// An `access_grants` row with the person's profile name. Its scope is the most specific id that is set.
public struct AccessGrant: Codable, Identifiable, Equatable, Sendable {
    public struct Person: Codable, Equatable, Sendable {
        public let display_name: String
    }
    public let id: UUID
    public let user_id: UUID
    public let role: AccessRole
    public let project_id: UUID
    public let house_id: UUID?
    public let room_id: UUID?
    public let user: Person?
}
/// `profiles` row, readable by every signed-in user. Users change only their `display_name`; admins change
/// `organization_id` and `is_active`. Users are deactivated, never deleted.
public struct Profile: Codable, Identifiable, Equatable, Sendable {
    public let user_id: UUID
    public var display_name: String
    public var organization_id: UUID?
    public var is_active: Bool
    public var id: UUID { user_id }
}
/// `organizations` row; created and edited by admins only.
public struct Organization: Codable, Identifiable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case active, inactive
    }
    public var id: UUID
    public var name: String
    public var status: Status
    public var responsible_id: UUID?
    public init(id: UUID = UUID(), name: String, status: Status = .active, responsible_id: UUID? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.responsible_id = responsible_id
    }
}
