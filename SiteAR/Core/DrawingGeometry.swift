import Foundation
import simd

public struct SpatialRay: Sendable {
    public var origin: SIMD3<Float>
    public var direction: SIMD3<Float>
    public init(origin: SIMD3<Float>, direction: SIMD3<Float>) { self.origin = origin; self.direction = direction }
}
public struct ArrowGeometry: Sendable {
    public let tail: SIMD3<Float>; public let tip: SIMD3<Float>
    public let left: SIMD3<Float>; public let right: SIMD3<Float>
}
public enum DrawingGeometry {
    /// Construct an XY drawing plane with Z facing the observer. Orientation is fixed at placement.
    public static func plane(at point: SIMD3<Float>, normal: SIMD3<Float>, camera: SIMD3<Float>, preferredRight: SIMD3<Float>) throws -> Pose {
        guard simd_length(normal) > 0.001 else { throw SpatialError.invalidGeometry }
        var z = simd_normalize(normal)
        if simd_dot(z,camera-point) < 0 { z = -z }
        var x: SIMD3<Float>
        if abs(z.y) < 0.9 { x = simd_normalize(simd_cross(SIMD3(0,1,0),z)) }
        else {
            let projected = preferredRight-z*simd_dot(preferredRight,z)
            guard simd_length(projected) > 0.001 else { throw SpatialError.invalidGeometry }
            x = simd_normalize(projected)
        }
        let y = simd_normalize(simd_cross(z,x))
        return try Pose(simd_float4x4(columns: (SIMD4(x,0),SIMD4(y,0),SIMD4(z,0),SIMD4(point,1))))
    }
    /// A measured distance follows the selected screen ray, including off-centre crosshairs.
    public static func measuredPoint(camera:SIMD3<Float>,direction:SIMD3<Float>,distance:Float) -> SIMD3<Float>? {
        guard distance.isFinite, (0.1...10).contains(distance),
              [camera.x,camera.y,camera.z,direction.x,direction.y,direction.z].allSatisfy(\.isFinite),
              simd_length(direction)>0.001 else { return nil }
        return camera+simd_normalize(direction)*distance
    }
    /// Screen coordinates are normalized top-left 0...1, using the captured camera's exact projection.
    public static func ray(screen: SIMD2<Float>, inverseViewProjection: simd_float4x4) -> SpatialRay? {
        let ndc = SIMD2(2*screen.x-1,1-2*screen.y)
        let a = inverseViewProjection*SIMD4(ndc.x,ndc.y,0,1), b = inverseViewProjection*SIMD4(ndc.x,ndc.y,1,1)
        guard abs(a.w)>0.000001, abs(b.w)>0.000001 else { return nil }
        let origin = a.xyz/a.w, delta = b.xyz/b.w-origin
        guard [origin.x,origin.y,origin.z,delta.x,delta.y,delta.z].allSatisfy(\.isFinite), simd_length(delta)>0.0001 else { return nil }
        return SpatialRay(origin:origin,direction:simd_normalize(delta))
    }
    public static func intersection(_ ray: SpatialRay, plane: Pose) -> SIMD3<Float>? {
        let normal = plane.matrix.columns.2.xyz
        let denominator = simd_dot(normal,ray.direction)
        guard abs(denominator)>0.001 else { return nil }
        let distance = simd_dot(plane.matrix.columns.3.xyz-ray.origin,normal)/denominator
        guard distance>0, distance<20 else { return nil }
        let point = ray.origin+ray.direction*distance
        return [point.x,point.y,point.z].allSatisfy(\.isFinite) ? point : nil
    }
    public static func project(_ point: SIMD3<Float>, viewProjection: simd_float4x4) -> SIMD2<Float>? {
        let clip = viewProjection*SIMD4(point,1)
        guard clip.w>0.001 else { return nil }
        let p = clip.xyz/clip.w
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2((p.x+1)/2,(1-p.y)/2)
    }
    /// Straight shaft and a triangular head in the drawing plane, independent of camera rotation.
    public static func arrow(tail: SIMD3<Float>, tip: SIMD3<Float>, normal: SIMD3<Float>) -> ArrowGeometry? {
        let delta = tip-tail, length = simd_length(delta)
        guard length>0.01, length.isFinite, simd_length(normal)>0.001 else { return nil }
        let forward = delta/length, side = simd_cross(simd_normalize(normal),forward)
        guard simd_length(side)>0.001 else { return nil }
        let headLength = min(length*0.35,0.22), halfWidth = headLength*0.55
        let base = tip-forward*headLength, width = simd_normalize(side)*halfWidth
        return ArrowGeometry(tail:tail,tip:tip,left:base+width,right:base-width)
    }
    /// Remove collinear boundary samples; do not turn detected patches into filled room faces.
    public static func outline(_ points: [Point3], tolerance: Float = 0.025) -> [Point3] {
        var result = points
        var changed = true
        while result.count>4 && changed {
            changed = false
            for i in result.indices {
                let a=result[(i+result.count-1)%result.count].vector, b=result[i].vector, c=result[(i+1)%result.count].vector
                let edge=c-a, length=simd_length(edge)
                if length>0.001 && simd_length(simd_cross(b-a,edge))/length<tolerance {
                    result.remove(at:i); changed=true; break
                }
            }
        }
        return result
    }
}
