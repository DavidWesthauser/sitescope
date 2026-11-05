import Foundation
import simd

/// A detected plane boundary, not a classified furniture model or proof of room coverage.
public struct SurfacePatch: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var pose: Pose
    public var vertices: [Point3]
    public var vertical: Bool
    public init(id: UUID, pose: Pose, vertices: [Point3], vertical: Bool) {
        self.id = id; self.pose = pose; self.vertices = vertices; self.vertical = vertical
    }
    public func validate() throws {
        guard vertices.count >= 3, vertices.count <= 2048,
              vertices.allSatisfy({ [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) }) else { throw SpatialError.invalidGeometry }
    }
    public var worldVertices: [SIMD3<Float>] { vertices.map { (pose.matrix * SIMD4($0.vector,1)).xyz } }
}

/// Observable ARKit evidence, deliberately not a percentage of the physical room scanned.
public struct ScanProgress: Equatable, Sendable {
    /// A per-frame observation heuristic, not confidence in the complete room map.
    public static let minimumFeatureCount = 20
    public var normalTracking = false
    public var mapReady = false
    public var stableSeconds: Double = 0
    public var featureCount = 0
    public var surfaces: [SurfacePatch] = []
    public var coverage = ScanCoverage()
    public var cameraYaw:Float=0
    public var observedSurfaceCount=0
    public var renderingReduced=false
    public init() {}
    public var verticalCount: Int { surfaces.filter(\.vertical).count }
    public var horizontalCount: Int { surfaces.count - verticalCount }
    public var hasUsefulFeatures: Bool { featureCount >= Self.minimumFeatureCount }
    public var canFinish: Bool { normalTracking && mapReady && hasUsefulFeatures && stableSeconds >= 2 && !surfaces.isEmpty && coverage.ready }
    public var stage: Int {
        guard normalTracking else { return 0 }
        if canFinish { return 3 }
        if !surfaces.isEmpty { return 2 }
        return normalTracking ? 1 : 0
    }
}

/// Movement evidence for a multi-view scan; not a guarantee of geometric or recognition coverage.
public struct ScanCoverage: Equatable, Sendable {
    public private(set) var headings: Set<Int> = []
    public private(set) var positions: [Point3] = []
    public private(set) var currentHeading: Int?
    private var previousTime: TimeInterval?
    private var pendingHeading: Int?
    private var pendingPosition: SIMD3<Float>?
    private var pendingStart: TimeInterval?
    private var pendingElapsed: TimeInterval = 0
    private var pendingRecorded = false
    private static let dwell: TimeInterval = 0.75

    public init() {}
    public var ready: Bool { headings.count >= 4 && positions.count >= 3 }
    public var directionProgress: [Double] {
        (0..<4).map { heading in
            if headings.contains(heading) { return 1 }
            guard pendingHeading == heading else { return 0 }
            return min(1, max(0, pendingElapsed / Self.dwell))
        }
    }

    /// Only a continuous reliable pause qualifies a view. Tracking loss preserves completed views.
    public mutating func observe(position: SIMD3<Float>, forward: SIMD3<Float>, reliable: Bool, at time: TimeInterval) {
        guard time.isFinite, reliable,
              [position.x,position.y,position.z,forward.x,forward.y,forward.z].allSatisfy(\.isFinite),
              hypot(Double(forward.x), Double(forward.z)) > 0.3 else {
            resetPending()
            currentHeading = nil
            previousTime = time.isFinite ? time : nil
            return
        }
        let angle = atan2(Double(forward.x), Double(forward.z)) + Double.pi
        let heading = max(0, min(3, Int(angle / (Double.pi / 2))))
        currentHeading = heading
        let continuous = previousTime.map { time >= $0 && time - $0 <= 1 } ?? false
        previousTime = time
        let stationary = pendingPosition.map {
            hypot(Double(position.x) - Double($0.x), Double(position.z) - Double($0.z)) <= 0.35
        } ?? false
        guard continuous, pendingHeading == heading, stationary, let start = pendingStart else {
            // A finite out-of-order sample starts a fresh candidate at its own timestamp.
            pendingHeading = heading
            pendingPosition = position
            pendingStart = time
            pendingElapsed = 0
            pendingRecorded = false
            return
        }
        pendingElapsed = min(Self.dwell, max(0, time - start))
        guard pendingElapsed >= Self.dwell, !pendingRecorded else { return }
        headings.insert(heading)
        let horizontal = SIMD2(position.x,position.z)
        if positions.count < 32 && positions.allSatisfy({
            hypot(Double($0.x) - Double(horizontal.x), Double($0.z) - Double(horizontal.y)) >= 0.5
        }) {
            positions.append(Point3(position))
            pendingRecorded = true
        }
    }

    private mutating func resetPending() {
        pendingHeading = nil
        pendingPosition = nil
        pendingStart = nil
        pendingElapsed = 0
        pendingRecorded = false
    }

    /// Discards only the in-progress view when tracking or observation is interrupted.
    public mutating func interrupt() {
        resetPending()
        previousTime = nil
        currentHeading = nil
    }

    public var instruction: String {
        if positions.count < 3 { return "Walk to three positions at least 0.5 m apart. Pause at each to capture textured details." }
        if headings.count < 4 { return "Turn toward each remaining direction and pause to capture a steady view." }
        return "Look back at captured details as you return, so the room map connects."
    }
}
