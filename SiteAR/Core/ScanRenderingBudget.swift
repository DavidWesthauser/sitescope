import Foundation
import simd

/// Display-only geometry. Never use these samples to replace a saved map or annotation.
public enum ScanRenderingBudget {
    public static let maximumPatches = 24
    public static let maximumBoundaryVertices = 24
    public static let maximumCachedBoundaryVertices = 64

    public struct OutlineMesh: Sendable {
        public let positions: [SIMD3<Float>]
        public let indices: [UInt32]
    }

    /// Deterministic, ordered samples of a closed boundary; no repeated closing vertex.
    public static func displayBoundary(_ points: [Point3], maximum: Int = 24) -> [Point3] {
        let limit = min(maximum, maximumCachedBoundaryVertices)
        guard limit >= 3 else { return [] }

        var distinct: [Point3] = []
        distinct.reserveCapacity(points.count)
        for point in points {
            guard finite(point.vector) else { return [] }
            if let previous = distinct.last, simd_distance_squared(previous.vector, point.vector) <= 0.0000000001 {
                continue
            }
            distinct.append(point)
        }
        if let first = distinct.first, let last = distinct.last,
           distinct.count > 1, simd_distance_squared(first.vector, last.vector) <= 0.0000000001 {
            distinct.removeLast()
        }
        guard distinct.count >= 3 else { return [] }
        var area = SIMD3<Float>.zero
        for index in 1..<(distinct.count - 1) {
            area += simd_cross(distinct[index].vector - distinct[0].vector,
                               distinct[index + 1].vector - distinct[0].vector)
        }
        guard finite(area), simd_length_squared(area) > 0.000000000001 else { return [] }
        guard distinct.count > limit else { return distinct }
        return (0..<limit).map { distinct[$0 * distinct.count / limit] }
    }

    /// Nearest sampled boundary centroids, with UUID tie-breaking independent of input order.
    public static func visiblePatches(_ patches: [SurfacePatch], camera: SIMD3<Float>, maximum: Int = 24) -> [SurfacePatch] {
        let limit = min(maximum, maximumPatches)
        guard limit > 0, finite(camera) else { return [] }

        let ranked: [(patch: SurfacePatch, distance: Double)] = patches.compactMap { patch in
            let boundary = displayBoundary(patch.vertices)
            guard !boundary.isEmpty else { return nil }
            // Double arithmetic keeps large but finite input coordinates from overflowing the rank.
            var center = SIMD3<Double>.zero
            for point in boundary {
                let world = (patch.pose.matrix * SIMD4(point.vector, 1)).xyz
                guard finite(world) else { return nil }
                center += SIMD3(Double(world.x), Double(world.y), Double(world.z)) / Double(boundary.count)
            }
            let delta = center - SIMD3(Double(camera.x), Double(camera.y), Double(camera.z))
            let distance = simd_dot(delta, delta)
            guard distance.isFinite else { return nil }
            return (patch, distance)
        }
        return ranked.sorted { a, b in
            if a.distance != b.distance { return a.distance < b.distance }
            return a.patch.id.uuidString < b.patch.id.uuidString
        }.prefix(limit).map { $0.patch }
    }

    /// One indexed mesh of solid boxes tracing the closed boundary by total perimeter length.
    /// Zero reveal and invalid/degenerate geometry produce no drawable mesh.
    public static func outline(_ points: [Point3], thickness: Float, reveal: Float = 1) -> OutlineMesh? {
        guard thickness.isFinite, thickness > 0, reveal.isFinite, reveal > 0 else { return nil }
        let boundary = displayBoundary(points).map(\.vector)
        guard boundary.count >= 3 else { return nil }
        var area = SIMD3<Float>.zero
        for index in 1..<(boundary.count - 1) {
            area += simd_cross(boundary[index] - boundary[0], boundary[index + 1] - boundary[0])
        }
        guard finite(area), simd_length_squared(area) > 0.000000000001 else { return nil }

        var edges: [(start: SIMD3<Float>, direction: SIMD3<Float>, length: Float)] = []
        var perimeter: Float = 0
        for index in boundary.indices {
            let start = boundary[index], end = boundary[(index + 1) % boundary.count]
            let delta = end - start, length = simd_length(delta)
            guard length.isFinite else { return nil }
            guard length > 0.00001 else { continue }
            edges.append((start, delta / length, length))
            perimeter += length
        }
        guard !edges.isEmpty, perimeter.isFinite, perimeter > 0.00001 else { return nil }

        var remaining = min(1, reveal) * perimeter
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(edges.count * 8)
        indices.reserveCapacity(edges.count * 36)
        let boxIndices: [UInt32] = [
            0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
            0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
            2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7
        ]
        for edge in edges {
            guard remaining > 0.00001 else { break }
            let length = min(edge.length, remaining)
            let end = edge.start + edge.direction * length
            let helper: SIMD3<Float> = abs(edge.direction.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
            let unitSide = simd_normalize(simd_cross(helper, edge.direction))
            let side = unitSide * (thickness / 2)
            let up = simd_cross(edge.direction, unitSide) * (thickness / 2)
            let corners = [
                edge.start - side - up, edge.start + side - up,
                edge.start + side + up, edge.start - side + up,
                end - side - up, end + side - up, end + side + up, end - side + up
            ]
            guard corners.allSatisfy(finite) else { return nil }
            let base = UInt32(positions.count)
            positions += corners
            indices += boxIndices.map { base + $0 }
            remaining -= length
        }
        return positions.isEmpty ? nil : OutlineMesh(positions: positions, indices: indices)
    }

    private static func finite(_ point: SIMD3<Float>) -> Bool {
        point.x.isFinite && point.y.isFinite && point.z.isFinite
    }
}
