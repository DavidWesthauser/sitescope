import Foundation

public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var owner_id: UUID
    public var name: String
    public init(id: UUID = UUID(), owner_id: UUID, name: String) { self.id = id; self.owner_id = owner_id; self.name = name }
}
public struct Marker: Codable, Equatable, Sendable {
    public var id: UUID
    public var image_path: String
    public var width: Double
    public var height: Double
    public var room_from_marker: Pose
    public init(id: UUID, image_path: String, width: Double, height: Double, room_from_marker: Pose) {
        self.id = id; self.image_path = image_path; self.width = width; self.height = height; self.room_from_marker = room_from_marker
    }
}
public struct Room: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var project_id: UUID
    public var name: String
    public var spatial_version: Int = 1
    public var coordinate_id: UUID = UUID()
    public var map_path: String?
    /// Optional human-visible scene photo for revisiting a scan, never a localization marker.
    public var scan_guide_jpeg: String?
    public var marker: Marker?
    public var reference_points: [Point3] = []
    public var reference_notes: String = ""
    public var surfaces: [SurfacePatch]?
    public init(id: UUID = UUID(), project_id: UUID, name: String) { self.id = id; self.project_id = project_id; self.name = name }
    public func validate() throws {
        if let guide = scan_guide_jpeg {
            guard guide.utf8.count <= 87_384,
                  let bytes = Data(base64Encoded: guide), bytes.count >= 4, bytes.count <= 65_536,
                  bytes.base64EncodedString() == guide,
                  bytes.starts(with: [0xff, 0xd8]), bytes.suffix(2).elementsEqual([0xff, 0xd9]) else {
                throw SpatialError.invalidGeometry
            }
        }
        guard spatial_version == 1, reference_points.count == 0 || reference_points.count == 2,
              reference_points.allSatisfy({ [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) }),
              marker.map({ $0.width.isFinite && $0.height.isFinite && $0.width >= 0.05 && $0.width <= 2 && $0.height > 0 }) ?? true else { throw SpatialError.incompatibleVersion }
        if reference_points.count == 2 {
            guard !reference_notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SpatialError.invalidGeometry }
            _ = try AlignmentMath.manual(room: reference_points, session: reference_points)
        }
        guard (surfaces?.count ?? 0) <= 128 else { throw SpatialError.invalidGeometry }
        try surfaces?.forEach { try $0.validate() }
    }
}
public enum AnnotationKind: String, Codable, CaseIterable, Sendable { case marker, text, area, line, arrow, image }
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo, inProgress = "in_progress", completed
    public var label:String { switch self { case .todo:return "To do";case .inProgress:return "In progress";case .completed:return "Completed" } }
    public var symbol:String { switch self { case .todo:return "circle";case .inProgress:return "clock";case .completed:return "checkmark.circle.fill" } }
}
public struct SpatialImage: Codable, Equatable, Sendable {
    public var path: String
    public var width: Float
    public var height: Float
    public init(path: String, width: Float, height: Float) { self.path=path; self.width=width; self.height=height }
    public func validate() throws {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator:"/").contains(".."),
              width.isFinite,height.isFinite,width>0.001,height>0.001,width<=5,height<=5 else { throw SpatialError.invalidGeometry }
    }
}
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
    public var title: String
    public var detail: String
    public var status: TaskStatus = .todo
    public var priority: Int = 1
    public init(room: Room, kind: AnnotationKind, pose: Pose, points: [Point3] = [], title: String, detail: String) {
        room_id = room.id; coordinate_id = room.coordinate_id; self.kind = kind; self.pose = pose; self.points = points; self.title = title; self.detail = detail
    }
    public func validate(room: Room) throws {
        guard room_id == room.id, coordinate_id == room.coordinate_id, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count<=240,
              (0...2).contains(priority), points.count <= 128,
              points.allSatisfy({ [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) }),
              kind != .area || points.count >= 3,
              (kind != .line && kind != .arrow) || points.count >= 2 else { throw SpatialError.invalidGeometry }
        if kind == .image { guard let image else { throw SpatialError.invalidGeometry }; try image.validate() }
        if let strokes {
            guard kind == .line, !strokes.isEmpty, strokes.count<=32, strokes.reduce(0,{$0+$1.count})<=2048,
                  strokes.allSatisfy({ stroke in stroke.count>=2 && stroke.count<=256 && stroke.allSatisfy({[$0.x,$0.y,$0.z].allSatisfy(\.isFinite)}) }) else { throw SpatialError.invalidGeometry }
            for stroke in strokes { for (a,b) in zip(stroke,stroke.dropFirst()) {
                guard dot(b.vector-a.vector,b.vector-a.vector)>0.00000001 else { throw SpatialError.invalidGeometry }
            } }
        }
        if [.area,.line,.arrow].contains(kind) {
            for (a,b) in zip(points,points.dropFirst()) {
                let d = b.vector-a.vector
                guard dot(d,d) > 0.000004 else { throw SpatialError.invalidGeometry }
            }
        }
        if kind == .area {
            let p = points.map(\.vector)
            let normal = simdCross(p[1]-p[0],p[2]-p[0])
            let length = sqrt(normal.x*normal.x + normal.y*normal.y + normal.z*normal.z)
            guard length > 0.0001, p.allSatisfy({ abs(dot($0-p[0], normal)/length) < 0.03 }) else { throw SpatialError.invalidGeometry }
        }
    }
}
private func simdCross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { SIMD3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
private func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { a.x*b.x+a.y*b.y+a.z*b.z }
