import Foundation
import simd

public enum SpatialError: Error, LocalizedError {
    case invalidTransform, invalidGeometry, incompatibleVersion, degenerateReference
    public var errorDescription: String? { "Spatial data is invalid or incompatible. Open the room again or ask its manager to repair it." }
}

/// Column-major rigid transform, metres, right-handed ARKit coordinates. Never Euler angles.
public struct Pose: Codable, Equatable, Sendable {
    public let elements: [Float]
    public init(_ matrix: simd_float4x4) throws {
        let e = (0..<4).flatMap { c in (0..<4).map { r in matrix[c][r] } }
        guard e.allSatisfy(\.isFinite), abs(matrix[0].w) < 0.001,
              abs(matrix[1].w) < 0.001, abs(matrix[2].w) < 0.001,
              abs(matrix[3].w - 1) < 0.001 else { throw SpatialError.invalidTransform }
        let basis = simd_float3x3(SIMD3(matrix[0].x, matrix[0].y, matrix[0].z), SIMD3(matrix[1].x, matrix[1].y, matrix[1].z), SIMD3(matrix[2].x, matrix[2].y, matrix[2].z))
        guard abs(simd_determinant(basis) - 1) < 0.01,
              (0..<3).allSatisfy({ abs(simd_length(basis[$0]) - 1) < 0.01 }),
              abs(simd_dot(basis[0], basis[1])) < 0.01,
              abs(simd_dot(basis[0], basis[2])) < 0.01,
              abs(simd_dot(basis[1], basis[2])) < 0.01 else { throw SpatialError.invalidTransform }
        elements = e
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer(); let e = try c.decode([Float].self)
        guard e.count == 16 else { throw SpatialError.invalidTransform }
        try self.init(simd_float4x4(columns: (SIMD4(e[0...3]), SIMD4(e[4...7]), SIMD4(e[8...11]), SIMD4(e[12...15]))))
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(elements) }
    public var matrix: simd_float4x4 { simd_float4x4(columns: (SIMD4(elements[0...3]), SIMD4(elements[4...7]), SIMD4(elements[8...11]), SIMD4(elements[12...15]))) }
    public static let identity = try! Pose(matrix_identity_float4x4)
}

public struct Point3: Codable, Equatable, Sendable {
    public var x: Float; public var y: Float; public var z: Float
    public init(_ v: SIMD3<Float>) { x = v.x; y = v.y; z = v.z }
    public var vector: SIMD3<Float> { SIMD3(x,y,z) }
}

public enum AlignmentMath {
    /// sessionFromRoom = sessionFromMarker × inverse(roomFromMarker).
    public static func marker(sessionFromMarker: Pose, roomFromMarker: Pose) throws -> Pose {
        try Pose(sessionFromMarker.matrix * simd_inverse(roomFromMarker.matrix))
    }
    /// Gravity-aligned two-point recovery. Points must be at least 30 cm apart horizontally.
    public static func manual(room: [Point3], session: [Point3]) throws -> Pose {
        guard room.count == 2, session.count == 2 else { throw SpatialError.degenerateReference }
        let a = room[1].vector - room[0].vector, b = session[1].vector - session[0].vector
        guard simd_length(SIMD2(a.x,a.z)) > 0.3, simd_length(SIMD2(b.x,b.z)) > 0.3,
              abs(simd_length(a) - simd_length(b)) < 0.15,
              abs(a.y - b.y) < 0.1 else { throw SpatialError.degenerateReference }
        let angle = atan2(a.z,a.x) - atan2(b.z,b.x)
        var m = simd_float4x4(simd_quatf(angle: angle, axis: SIMD3(0,1,0)))
        m.columns.3 = SIMD4(session[0].vector - (m * SIMD4(room[0].vector,1)).xyz, 1)
        return try Pose(m)
    }
}
public extension SIMD4 where Scalar == Float { var xyz: SIMD3<Float> { SIMD3(x,y,z) } }

public enum LocalizationState: String, Sendable { case searching, relocalizing, verifying, aligned, lost, failed }
public enum AlignmentMethod: String, Sendable { case map, marker, manual }
/// Map recovery needs restored anchors and stable normal tracking. Fallback candidates require confirmation.
public struct Localization: Sendable {
    public private(set) var state: LocalizationState = .searching
    public private(set) var candidate: Pose?
    public private(set) var method: AlignmentMethod?
    public private(set) var searchTimedOut = false
    public init() {}
    public var roomToSession: Pose? { state == .aligned ? candidate : nil }
    public mutating func searching() { self = Localization(); state = .relocalizing }
    public mutating func propose(_ pose: Pose, method: AlignmentMethod) { searchTimedOut = false; candidate = pose; self.method = method; state = .verifying }
    public mutating func confirm(normalTracking: Bool) { if normalTracking && candidate != nil && state == .verifying { state = .aligned } }
    @discardableResult public mutating func recoverMap(restoredRoomAnchor: Bool, normalTracking: Bool, stableSeconds: Double, mapAvailable: Bool) -> Bool {
        guard state == .relocalizing || (state == .failed && searchTimedOut),
              restoredRoomAnchor, normalTracking, stableSeconds >= 2, mapAvailable else { return false }
        propose(.identity, method: .map); confirm(normalTracking: true); return true
    }
    /// The live ARKit search continues after a guidance timeout; hard failures do not.
    public mutating func timedOut() {
        guard state == .relocalizing else { return }
        lose(); state = .failed; searchTimedOut = true
    }
    public mutating func lose() { searchTimedOut = false; candidate = nil; method = nil; state = .lost }
    public mutating func fail() { lose(); state = .failed }
}
