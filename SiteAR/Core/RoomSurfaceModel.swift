import Foundation
import simd

/// Consolidates observed display geometry only. Original AR maps and raycast planes stay unchanged.
public enum RoomSurfaceModel {
    private typealias Point = SIMD2<Double>
    private static let maximumWorkingPatches = 64
    private static let epsilon = 0.000000001

    private struct Bounds {
        let lower: SIMD3<Float>
        let upper: SIMD3<Float>

        init?(_ vertices: [SIMD3<Float>]) {
            guard let first = vertices.first, vertices.allSatisfy(RoomSurfaceModel.finite) else { return nil }
            var minimum = first, maximum = first
            for point in vertices.dropFirst() {
                minimum = SIMD3(min(minimum.x, point.x), min(minimum.y, point.y), min(minimum.z, point.z))
                maximum = SIMD3(max(maximum.x, point.x), max(maximum.y, point.y), max(maximum.z, point.z))
            }
            lower = minimum
            upper = maximum
        }

        func overlaps(_ other: Bounds) -> Bool {
            // Pad BOTH boxes so projection of a near-coplanar polygon cannot be rejected early.
            let padding: Float = 0.031
            return (0..<3).allSatisfy {
                lower[$0] - padding <= other.upper[$0] + padding &&
                    upper[$0] + padding >= other.lower[$0] - padding
            }
        }
    }

    private struct Group {
        var patch: SurfacePatch
        let worldVertices: [SIMD3<Float>]
        let bounds: Bounds
        // Lower bound on observed coverage INSIDE this group's displayed polygon.
        // Keeping this prevents the small permitted gap from accumulating across merges.
        var observedArea: Double
        var revision = 0
    }

    private struct Pair: Hashable {
        let first: UUID
        let firstRevision: Int
        let second: UUID
        let secondRevision: Int
    }

    /// Merge overlapping, near-coplanar convex patches without spanning unobserved gaps.
    /// Work is bounded to 64 deterministic input patches; output has at most 24 patches/vertices.
    public static func consolidate(_ patches: [SurfacePatch], maximum: Int = 24) -> [SurfacePatch] {
        let limit = min(24, maximum)
        guard limit > 0 else { return [] }
        var identities = Set<UUID>()
        var groups: [Group] = []
        for patch in patches.sorted(by: precedes).prefix(maximumWorkingPatches) {
            guard !identities.contains(patch.id), let group = normalized(patch) else { continue }
            identities.insert(patch.id)
            groups.append(group)
            if groups.count == maximumWorkingPatches { break }
        }

        var rejected = Set<Pair>()
        var changed = true
        while changed {
            changed = false
            mergePass: for first in groups.indices {
                for second in (first + 1)..<groups.count {
                    // Cheap broad phase before UUID-pair caching, transforms or polygon clipping.
                    guard groups[first].bounds.overlaps(groups[second].bounds) else { continue }
                    let pair = Pair(first: groups[first].patch.id, firstRevision: groups[first].revision,
                                    second: groups[second].patch.id, secondRevision: groups[second].revision)
                    guard !rejected.contains(pair) else { continue }
                    if let combined = merge(groups[first], groups[second]) {
                        groups[first] = combined
                        groups.remove(at: second)
                        changed = true
                        break mergePass
                    }
                    rejected.insert(pair)
                }
            }
        }
        return groups.prefix(limit).map(\.patch)
    }

    private static func normalized(_ patch: SurfacePatch) -> Group? {
        guard (3...2048).contains(patch.vertices.count),
              patch.vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && abs($0.y) <= 0.001 }) else { return nil }
        let original = patch.vertices.map { Point(Double($0.x), Double($0.z)) }
        let hull = convexHull(original)
        let originalArea = area(original), hullArea = area(hull)
        // A concave/self-intersecting source must not become an invented convex surface.
        guard originalArea > epsilon, hull.count >= 3,
              hullArea - originalArea <= max(0.00001, originalArea * 0.00001) else { return nil }
        let boundary = sampled(hull)
        var copy = patch
        copy.vertices = boundary.map { Point3(SIMD3(Float($0.x), 0, Float($0.y))) }
        let world = copy.worldVertices
        guard let bounds = Bounds(world) else { return nil }
        return Group(patch: copy, worldVertices: world, bounds: bounds, observedArea: area(boundary))
    }

    private static func merge(_ first: Group, _ second: Group) -> Group? {
        let a = first.patch, b = second.patch
        guard a.vertical == b.vertical else { return nil }
        let normalA = a.pose.matrix.columns.1.xyz, normalB = b.pose.matrix.columns.1.xyz
        guard abs(simd_dot(normalA, normalB)) >= cos(Float.pi / 60) else { return nil }
        let worldA = first.worldVertices, worldB = second.worldVertices
        let originA = a.pose.matrix.columns.3.xyz, originB = b.pose.matrix.columns.3.xyz
        // Check the entire observed extent, not just possibly shifted anchor origins.
        guard worldB.allSatisfy({ abs(simd_dot($0 - originA, normalA)) <= 0.030001 }),
              worldA.allSatisfy({ abs(simd_dot($0 - originB, normalB)) <= 0.030001 }) else { return nil }

        let inverse = simd_inverse(a.pose.matrix)
        let polygonA = a.vertices.map { Point(Double($0.x), Double($0.z)) }
        let polygonB = convexHull(worldB.map { point in
            let local = (inverse * SIMD4(point, 1)).xyz
            return Point(Double(local.x), Double(local.z))
        })
        guard polygonB.count >= 3, polygonB.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let intersection = area(clipped(polygonA, by: polygonB))
        // Edge contact alone is insufficient; disjoint patches never form a connecting hull.
        guard intersection > 0.000001 else { return nil }
        let hull = convexHull(polygonA + polygonB)
        let hullArea = area(hull)
        let projectedAreaB = area(polygonB)
        // Projection can slightly reduce a tilted polygon's area; reduce its coverage bound too.
        let coverageB = max(0, second.observedArea - max(0, area(b.vertices.map { Point(Double($0.x), Double($0.z)) }) - projectedAreaB))
        let observed = max(max(first.observedArea, coverageB), first.observedArea + coverageB - intersection)
        guard allowed(hullArea: hullArea, observedArea: observed) else { return nil }

        let boundary = sampled(hull), displayArea = area(boundary)
        let retainedCoverage = max(0, min(displayArea, observed - max(0, hullArea - displayArea)))
        guard allowed(hullArea: displayArea, observedArea: retainedCoverage) else { return nil }
        var combined = a // Sorted input makes this the minimum UUID and its exact room-relative pose.
        combined.vertices = boundary.map { Point3(SIMD3(Float($0.x), 0, Float($0.y))) }
        let world = combined.worldVertices
        guard let bounds = Bounds(world) else { return nil }
        return Group(patch: combined, worldVertices: world, bounds: bounds,
                     observedArea: retainedCoverage, revision: first.revision + 1)
    }

    private static func allowed(hullArea: Double, observedArea: Double) -> Bool {
        hullArea.isFinite && observedArea.isFinite && observedArea > epsilon &&
            hullArea - observedArea <= observedArea * 0.02 + 0.005 + epsilon
    }

    private static func sampled(_ polygon: [Point]) -> [Point] {
        guard polygon.count > 24 else { return polygon }
        return (0..<24).map { polygon[$0 * polygon.count / 24] }
    }

    private static func convexHull(_ points: [Point]) -> [Point] {
        let ordered = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        var unique: [Point] = []
        for point in ordered where unique.last != point { unique.append(point) }
        guard unique.count >= 3 else { return [] }
        func half(_ input: [Point]) -> [Point] {
            var result: [Point] = []
            for point in input {
                while result.count >= 2 && cross(result[result.count - 1] - result[result.count - 2], point - result[result.count - 1]) <= epsilon {
                    result.removeLast()
                }
                result.append(point)
            }
            return result
        }
        let lower = half(unique), upper = half(Array(unique.reversed()))
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    /// Sutherland-Hodgman intersection; both convex polygons are counterclockwise.
    private static func clipped(_ subject: [Point], by clipper: [Point]) -> [Point] {
        var output = subject
        for index in clipper.indices {
            let a = clipper[index], b = clipper[(index + 1) % clipper.count]
            let input = output
            output = []
            guard var previous = input.last else { break }
            var previousDistance = cross(b - a, previous - a)
            for current in input {
                let distance = cross(b - a, current - a)
                let previousInside = previousDistance >= -epsilon, inside = distance >= -epsilon
                if previousInside != inside {
                    let denominator = previousDistance - distance
                    if abs(denominator) > epsilon {
                        let t = min(1, max(0, previousDistance / denominator))
                        output.append(previous + (current - previous) * t)
                    }
                }
                if inside { output.append(current) }
                previous = current
                previousDistance = distance
            }
        }
        return output
    }

    private static func area(_ polygon: [Point]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        let origin = polygon[0]
        let twice = (1..<(polygon.count - 1)).reduce(0.0) { sum, index in
            sum + cross(polygon[index] - origin, polygon[index + 1] - origin)
        }
        return abs(twice) / 2
    }

    private static func cross(_ a: Point, _ b: Point) -> Double { a.x * b.y - a.y * b.x }
    private static func finite(_ point: SIMD3<Float>) -> Bool { point.x.isFinite && point.y.isFinite && point.z.isFinite }

    private static func precedes(_ a: SurfacePatch, _ b: SurfacePatch) -> Bool {
        if a.id != b.id { return a.id.uuidString < b.id.uuidString }
        if a.pose.elements != b.pose.elements { return a.pose.elements.lexicographicallyPrecedes(b.pose.elements) }
        if a.vertical != b.vertical { return !a.vertical }
        // Bit patterns also provide a total deterministic order for malformed NaN coordinates.
        let valuesA = a.vertices.flatMap { [$0.x.bitPattern, $0.y.bitPattern, $0.z.bitPattern] }
        let valuesB = b.vertices.flatMap { [$0.x.bitPattern, $0.y.bitPattern, $0.z.bitPattern] }
        return valuesA.lexicographicallyPrecedes(valuesB)
    }
}
