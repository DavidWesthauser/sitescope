import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class ScanRenderingBudgetTests: XCTestCase {
    private let square = [Point3(SIMD3<Float>(0, 0, 0)), Point3(SIMD3<Float>(1, 0, 0)),
                          Point3(SIMD3<Float>(1, 0, 1)), Point3(SIMD3<Float>(0, 0, 1))]

    func testBoundarySamplingIsBoundedOrderedAndDoesNotChangeSource() {
        let source = (0..<240).map { index in
            let angle = Float(index) * 2 * Float.pi / 240
            return Point3(SIMD3<Float>(cos(angle), 0, sin(angle)))
        }
        let sampled = ScanRenderingBudget.displayBoundary(source)
        XCTAssertEqual(sampled.count, 24)
        XCTAssertEqual(sampled, (0..<24).map { source[$0 * 10] })
        XCTAssertEqual(source.count, 240)
        XCTAssertEqual(ScanRenderingBudget.displayBoundary(source, maximum: 100).count, 64)
        XCTAssertEqual(ScanRenderingBudget.displayBoundary(source, maximum: 4).count, 4)
        XCTAssertTrue(ScanRenderingBudget.displayBoundary(source, maximum: 2).isEmpty)
    }

    func testBoundaryDropsDuplicateClosureAndRejectsNonfiniteInput() {
        let repeated = [square[0], square[0]] + Array(square.dropFirst()) + [square[0]]
        XCTAssertEqual(ScanRenderingBudget.displayBoundary(repeated), square)
        XCTAssertTrue(ScanRenderingBudget.displayBoundary([square[0], square[0], square[0]]).isEmpty)
        XCTAssertTrue(ScanRenderingBudget.displayBoundary(square + [Point3(SIMD3(.nan, 0, 0))]).isEmpty)
    }

    func testNearestSelectionIsBoundedAndDeterministicAcrossInputOrder() throws {
        let patches = try (1...40).map { value -> SurfacePatch in
            var matrix = matrix_identity_float4x4
            matrix.columns.3.x = Float(value)
            return SurfacePatch(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!,
                                pose: try Pose(matrix), vertices: square, vertical: false)
        }
        let selected = ScanRenderingBudget.visiblePatches(Array(patches.reversed()), camera: .zero)
        XCTAssertEqual(selected.map(\.id), Array(patches.prefix(24)).map(\.id))
        XCTAssertEqual(ScanRenderingBudget.visiblePatches(patches, camera: .zero).map(\.id), selected.map(\.id))
        let nearFarEnd = ScanRenderingBudget.visiblePatches(patches, camera: SIMD3(40.5, 0, 0.5), maximum: 1)
        XCTAssertEqual(nearFarEnd.first?.id, patches.last?.id)
        XCTAssertTrue(ScanRenderingBudget.visiblePatches(patches, camera: SIMD3(.nan, 0, 0)).isEmpty)
        XCTAssertTrue(ScanRenderingBudget.visiblePatches(patches, camera: .zero, maximum: 0).isEmpty)

        var first = patches[0], second = patches[1]
        first.pose = .identity; second.pose = .identity
        XCTAssertEqual(ScanRenderingBudget.visiblePatches([second, first], camera: .zero).map(\.id), [first.id, second.id])
    }

    func testRevealUsesPerimeterDistanceAndEndsAtExpectedPosition() throws {
        XCTAssertNil(ScanRenderingBudget.outline(square, thickness: 0.01, reveal: 0))
        let partial = try XCTUnwrap(ScanRenderingBudget.outline(square, thickness: 0.01, reveal: 0.125))
        XCTAssertEqual(partial.positions.count, 8)
        XCTAssertEqual(partial.indices.count, 36)
        XCTAssertEqual(partial.positions.map(\.x).max()!, 0.5, accuracy: 0.00001)
        let firstEdge = try XCTUnwrap(ScanRenderingBudget.outline(square, thickness: 0.01, reveal: 0.25))
        XCTAssertEqual(firstEdge.positions.count, 8)
        XCTAssertEqual(firstEdge.positions.map(\.x).max()!, 1, accuracy: 0.00001)
        let full = try XCTUnwrap(ScanRenderingBudget.outline(square, thickness: 0.01))
        XCTAssertEqual(full.positions.count, 32)
        XCTAssertEqual(full.indices.count, 144)
        XCTAssertTrue(full.indices.allSatisfy { Int($0) < full.positions.count })
        XCTAssertEqual(ScanRenderingBudget.outline(square, thickness: 0.01, reveal: 2)?.positions, full.positions)
    }

    func testMeshRemainsBoundedFiniteAndHandlesVerticalEdges() throws {
        let boundary = (0..<1000).map { index in
            let angle = Float(index) * 2 * Float.pi / 1000
            return Point3(SIMD3<Float>(cos(angle), sin(angle), 0))
        }
        let mesh = try XCTUnwrap(ScanRenderingBudget.outline(boundary, thickness: 0.004))
        XCTAssertLessThanOrEqual(mesh.positions.count, 24 * 8)
        XCTAssertLessThanOrEqual(mesh.indices.count, 24 * 36)
        XCTAssertTrue(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        XCTAssertNil(ScanRenderingBudget.outline(square, thickness: 0))
        XCTAssertNil(ScanRenderingBudget.outline(square, thickness: .nan))
        XCTAssertNil(ScanRenderingBudget.outline(square, thickness: 0.004, reveal: .nan))
        XCTAssertNil(ScanRenderingBudget.outline([Point3(.zero), Point3(.zero)], thickness: 0.004))
        XCTAssertNil(ScanRenderingBudget.outline([Point3(.zero), Point3(SIMD3(1, 0, 0)), Point3(SIMD3(2, 0, 0))], thickness: 0.004))
    }
}
