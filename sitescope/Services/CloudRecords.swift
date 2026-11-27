import Foundation

/// Row shapes of the Supabase tables (docs/DATABASE_API.md) and how they map to the app's models.
/// The `Core` models stay as they are, because `local.json` and `.sitescope` files persist them.
/// Writes send only the columns the database lets clients set; ids, authors and timestamps are fixed after insert.

/// `projects` row. The app's `owner_id` is the project's responsible person.
struct CloudProject: Decodable {
    let id: UUID
    let name: String
    let responsible_id: UUID
    var project: Project { Project(id: id, owner_id: responsible_id, name: name) }
}

struct NewCloudProject: Encodable {
    let id: UUID
    let name: String
}

/// `houses` row. The app has no house screens yet (T-005); each project gets one house that holds its rooms.
struct CloudHouse: Codable {
    let id: UUID
    let project_id: UUID
    let name: String
    static let defaultName = "Main building"
}

/// A new room: the app's room plus the house it belongs to.
struct NewCloudRoom: Encodable {
    let room: Room
    let house_id: UUID
    private enum Keys: String, CodingKey { case house_id }
    func encode(to encoder: Encoder) throws {
        try room.encode(to: encoder)
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(house_id, forKey: .house_id)
    }
}

/// The scan data written when a room map is published. Optionals are sent as `null`, never left out,
/// so the stored row always matches the room.
struct RoomMapUpdate: Encodable {
    let room: Room
    private enum Keys: String, CodingKey {
        case spatial_version, map_path, scan_guide_jpeg, marker, reference_points, reference_notes, surfaces
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(room.spatial_version, forKey: .spatial_version)
        try container.encode(room.map_path, forKey: .map_path)
        try container.encode(room.scan_guide_jpeg, forKey: .scan_guide_jpeg)
        try container.encode(room.marker, forKey: .marker)
        try container.encode(room.reference_points, forKey: .reference_points)
        try container.encode(room.reference_notes, forKey: .reference_notes)
        try container.encode(room.surfaces, forKey: .surfaces)
    }
}

/// The editable content of a note. Its room and coordinate system are fixed after insert.
struct AnnotationUpdate: Encodable {
    let item: Annotation
    private enum Keys: String, CodingKey { case kind, pose, points, strokes, image, title, detail, status, priority }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(item.kind, forKey: .kind)
        try container.encode(item.pose, forKey: .pose)
        try container.encode(item.points, forKey: .points)
        try container.encode(item.strokes, forKey: .strokes)
        try container.encode(item.image, forKey: .image)
        try container.encode(item.title, forKey: .title)
        try container.encode(item.detail, forKey: .detail)
        try container.encode(item.status, forKey: .status)
        try container.encode(item.priority, forKey: .priority)
    }
}
