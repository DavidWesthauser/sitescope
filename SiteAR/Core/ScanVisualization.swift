import Foundation
import simd

/// One flat face of a thin slab, as world-space corners plus a brightness multiplier for shading.
public struct ScanModelFace: Sendable {
    public let vertices: [SIMD3<Float>]
    public let shade: Float

    public init(vertices: [SIMD3<Float>], shade: Float) {
        self.vertices = vertices
        self.shade = shade
    }
}

/// Helpers for drawing the scan miniature. Pure math, no UI or AR dependencies.
public enum ScanVisualization {
    /// The miniature is drawn on the CPU next to a live camera feed; 30 fps is smooth at its size and leaves the frame budget to AR.
    public static let animationFrameInterval: TimeInterval = 1.0 / 30

    /// Thin slabs of observed patches only. No inferred walls, windows, furniture or floor.
    /// Front and back faces are offset along the patch normal; the front is brightest and sides are darkest for depth cues.
    public static func faces(_ patch: SurfacePatch, vertices: [SIMD3<Float>]? = nil, thickness: Float = 0.025)
        -> [ScanModelFace]
    {
        let p = vertices ?? patch.worldVertices
        guard p.count >= 3 else { return [] }

        let offset = patch.pose.matrix.columns.1.xyz * thickness / 2
        let front = p.map { $0 + offset }
        let back = p.map { $0 - offset }
        var faces = [
            ScanModelFace(vertices: front, shade: patch.vertical ? 0.97 : 1),
            ScanModelFace(vertices: Array(back.reversed()), shade: 0.86),
        ]
        for i in p.indices {
            let j = (i + 1) % p.count
            faces.append(ScanModelFace(vertices: [front[i], front[j], back[j], back[i]], shade: 0.76))
        }
        return faces
    }

    /// Rotates a point around the vertical (Y) axis by `yaw` radians.
    public static func rotate(_ p: SIMD3<Float>, yaw: Float) -> SIMD3<Float> {
        SIMD3(cos(yaw) * p.x - sin(yaw) * p.z, p.y, sin(yaw) * p.x + cos(yaw) * p.z)
    }

    /// Signed angle step from `from` to `to` along the shorter arc, so animation never spins the long way round.
    public static func shortAngle(from: Float, to: Float) -> Float { from + atan2(sin(to - from), cos(to - from)) }
}
