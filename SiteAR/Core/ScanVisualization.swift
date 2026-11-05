import Foundation
import simd

public struct ScanModelFace: Sendable {
    public let vertices: [SIMD3<Float>]
    public let shade: Float
    public init(vertices:[SIMD3<Float>],shade:Float) { self.vertices=vertices; self.shade=shade }
}
public enum ScanVisualization {
    /// The miniature is drawn on the CPU next to a live camera feed; 30 fps is smooth at its size and leaves the frame budget to AR.
    public static let animationFrameInterval: TimeInterval = 1.0/30
    /// Thin slabs of observed patches only. No inferred walls, windows, furniture or floor.
    public static func faces(_ patch: SurfacePatch, vertices:[SIMD3<Float>]? = nil, thickness:Float=0.025) -> [ScanModelFace] {
        let p=vertices ?? patch.worldVertices
        guard p.count>=3 else { return [] }
        let offset=patch.pose.matrix.columns.1.xyz*thickness/2
        let front=p.map { $0+offset }, back=p.map { $0-offset }
        var faces=[ScanModelFace(vertices:front,shade:patch.vertical ? 0.97 : 1),
                   ScanModelFace(vertices:Array(back.reversed()),shade:0.86)]
        for i in p.indices { let j=(i+1)%p.count
            faces.append(ScanModelFace(vertices:[front[i],front[j],back[j],back[i]],shade:0.76))
        }
        return faces
    }
    public static func rotate(_ p:SIMD3<Float>,yaw:Float) -> SIMD3<Float> {
        SIMD3(cos(yaw)*p.x-sin(yaw)*p.z,p.y,sin(yaw)*p.x+cos(yaw)*p.z)
    }
    public static func shortAngle(from:Float,to:Float) -> Float { from+atan2(sin(to-from),cos(to-from)) }
}
