import Foundation
import simd

public enum TrackingIssue: String, Equatable, Sendable {
    case none, initializing, excessiveMotion, insufficientFeatures, relocalizing, unavailable
    public var title:String {
        switch self {
        case .none: return "Tracking stable"
        case .initializing: return "Starting tracking"
        case .excessiveMotion: return "Move more slowly"
        case .insufficientFeatures: return "More visual detail needed"
        case .relocalizing: return "Recovering room position"
        case .unavailable: return "Tracking unavailable"
        }
    }
    public var instruction:String {
        switch self {
        case .none: return ""
        case .initializing: return "Move the phone gently sideways while looking at a corner or textured surface."
        case .excessiveMotion: return "Slow down and keep the phone steady. Fast turns and shaking blur the details used for tracking."
        case .insufficientFeatures: return "Look at textured objects, door frames or corners. Improve lighting; avoid blank walls, mirrors and glare."
        case .relocalizing: return "Look at details captured during the original scan, from overlapping viewpoints. Saved drawings stay hidden until aligned."
        case .unavailable: return "Keep the camera uncovered. If tracking does not resume, close AR and reopen this room. Your saved tasks remain available."
        }
    }
}

/// Checks whether a plane's depth and normal have settled, not its physical accuracy.
/// Evidence must stay fresh: observations more than one second apart restart settling.
public struct SurfaceStability: Sendable {
    private var reference:Pose?
    private var since:TimeInterval?
    private var lastTime:TimeInterval?
    public init() {}
    public mutating func observe(_ pose:Pose,at time:TimeInterval) {
        guard time.isFinite else { self=SurfaceStability();return }
        defer { self.lastTime=time }
        guard let previous=reference, let lastTime, time>=lastTime, time-lastTime<=1.0 else {
            reference=pose;since=time;return
        }
        let normal=previous.matrix.columns.1.xyz,newNormal=pose.matrix.columns.1.xyz
        let depthChange=abs(simd_dot(pose.matrix.columns.3.xyz-previous.matrix.columns.3.xyz,normal))
        let orientation=abs(simd_dot(normal,newNormal))
        // Tangential origin changes do not move the underlying plane; compare normal/depth only.
        if depthChange>0.02 || orientation<cos(Float.pi/60) { reference=pose;since=time }
    }
    public func isReady(at time:TimeInterval) -> Bool {
        guard let since,let lastTime,time.isFinite,time>=lastTime,time-lastTime<=1.0 else { return false }
        return time-since>=0.6
    }
}

public enum CameraCaptureQuality {
    /// Reject a frozen screenshot paired with a materially different camera pose.
    public static func isSteady(from:Pose,to:Pose) -> Bool {
        guard simd_distance(from.matrix.columns.3.xyz,to.matrix.columns.3.xyz)<=0.02 else { return false }
        return (0..<3).allSatisfy { simd_dot(from.matrix[$0].xyz,to.matrix[$0].xyz)>=cos(Float.pi/90) }
    }
}

/// Only the currently active frozen-view capture may publish its result.
public struct ViewCaptureRequest: Sendable {
    private var active:UUID?
    public init() {}
    public var isPending:Bool { active != nil }
    public mutating func begin() -> UUID? {
        guard active == nil else { return nil }
        let id=UUID();active=id;return id
    }
    public func accepts(_ id:UUID) -> Bool { active == id }
    @discardableResult public mutating func finish(_ id:UUID) -> Bool {
        guard accepts(id) else { return false };active=nil;return true
    }
    public mutating func cancel() { active=nil }
}
