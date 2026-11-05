import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class RoomSurfaceModelTests: XCTestCase {
    private func rectangle(_ number: Int, origin: SIMD3<Float> = .zero, width: Float = 2, depth: Float = 2,
                           yaw: Float = 0, vertical: Bool = false) throws -> SurfacePatch {
        var matrix = simd_float4x4(simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)))
        matrix.columns.3 = SIMD4(origin, 1)
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
        return SurfacePatch(id: id, pose: try Pose(matrix),
                            vertices: [Point3(.zero), Point3(SIMD3(width, 0, 0)),
                                       Point3(SIMD3(width, 0, depth)), Point3(SIMD3(0, 0, depth))], vertical: vertical)
    }

    func testOverlappingPatchesBecomeOneObservedRectangle() throws {
        let first = try rectangle(1), second = try rectangle(2, origin: SIMD3(1, 0, 0))
        let result = RoomSurfaceModel.consolidate([first, second])
        XCTAssertEqual(result.count, 1)
        let model = try XCTUnwrap(result.first)
        XCTAssertEqual(model.id, first.id)
        XCTAssertEqual(model.pose, first.pose)
        XCTAssertEqual(model.vertices.count, 4)
        XCTAssertEqual(model.worldVertices.map(\.x).min()!, 0, accuracy: 0.00001)
        XCTAssertEqual(model.worldVertices.map(\.x).max()!, 3, accuracy: 0.00001)
        XCTAssertEqual(model.worldVertices.map(\.z).max()!, 2, accuracy: 0.00001)
        XCTAssertEqual(first.vertices.count, 4) // Consolidation never mutates the source patches.
    }

    func testSeparateTouchingAndDifferentPlanesDoNotMerge() throws {
        let first = try rectangle(1)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, try rectangle(2, origin: SIMD3(3, 0, 0))]).count, 2)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, try rectangle(2, origin: SIMD3(2, 0, 0))]).count, 2)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, try rectangle(2, origin: SIMD3(0, 0.031, 0))]).count, 2)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, try rectangle(2, origin: SIMD3(0, 0.02, 0))]).count, 1)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, try rectangle(2, vertical: true)]).count, 2)
        var tilted = try rectangle(2)
        tilted.pose = try Pose(simd_float4x4(simd_quatf(angle: 0.1, axis: SIMD3(1, 0, 0))))
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, tilted]).count, 2)
        tilted.pose = try Pose(simd_float4x4(simd_quatf(angle: Float.pi / 90, axis: SIMD3(1, 0, 0))))
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, tilted]).count, 2) // Normal is close, but distant vertices exceed the depth tolerance.
    }

    func testLShapeDoesNotFillAnUnobservedCorner() throws {
        let horizontal = try rectangle(1, width: 2, depth: 1)
        let upright = try rectangle(2, origin: SIMD3(0, 0, 0.5), width: 1, depth: 1.5)
        XCTAssertEqual(RoomSurfaceModel.consolidate([horizontal, upright]).count, 2)
    }

    func testMinimumIdentityPoseAndWorldGeometrySurviveInPlaneRotation() throws {
        let first = try rectangle(2)
        let reference = try rectangle(1, origin: SIMD3(1, 0, 2), yaw: Float.pi / 2)
        let model = try XCTUnwrap(RoomSurfaceModel.consolidate([first, reference]).first)
        XCTAssertEqual(RoomSurfaceModel.consolidate([first, reference]).count, 1)
        XCTAssertEqual(model.id, reference.id)
        XCTAssertEqual(model.pose, reference.pose)
        XCTAssertEqual(model.worldVertices.map(\.x).min()!, 0, accuracy: 0.00001)
        XCTAssertEqual(model.worldVertices.map(\.x).max()!, 3, accuracy: 0.00001)
        XCTAssertEqual(model.worldVertices.map(\.z).min()!, 0, accuracy: 0.00001)
        XCTAssertEqual(model.worldVertices.map(\.z).max()!, 2, accuracy: 0.00001)
        XCTAssertTrue(model.worldVertices.allSatisfy { abs($0.y) < 0.00001 })
        XCTAssertEqual(RoomSurfaceModel.consolidate([reference, first]), RoomSurfaceModel.consolidate([first, reference]))
    }

    func testContainmentAndRepeatedOverlapRemainDeterministic() throws {
        let outer = try rectangle(3, width: 3, depth: 2)
        let contained = try rectangle(2, origin: SIMD3(0.5, 0, 0.5), width: 1, depth: 1)
        let extensionPatch = try rectangle(1, origin: SIMD3(2, 0, 0))
        let patches = [outer, contained, extensionPatch]
        let result = RoomSurfaceModel.consolidate(patches)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result, RoomSurfaceModel.consolidate(Array(patches.reversed())))
        XCTAssertEqual(result.first?.id, extensionPatch.id)
        let model = try XCTUnwrap(result.first)
        XCTAssertEqual(model.worldVertices.map(\.x).max()!, 4, accuracy: 0.00001)
    }

    func testOutputBudgetsAndInvalidGeometry() throws {
        let separate = try (1...50).map { try rectangle($0, origin: SIMD3(Float($0) * 3, 0, 0), width: 1, depth: 1) }
        let bounded = RoomSurfaceModel.consolidate(separate)
        XCTAssertEqual(bounded.count, 24)
        XCTAssertEqual(bounded.map(\.id), Array(separate.prefix(24)).map(\.id))
        XCTAssertEqual(RoomSurfaceModel.consolidate(separate, maximum: 4).count, 4)
        XCTAssertEqual(RoomSurfaceModel.consolidate(separate, maximum: 100).count, 24)
        XCTAssertTrue(RoomSurfaceModel.consolidate(separate, maximum: 0).isEmpty)
        var polygon = try rectangle(1)
        polygon.vertices = (0..<100).map { index in
            let angle = Float(index) * 2 * Float.pi / 100
            return Point3(SIMD3(cos(angle), 0, sin(angle)))
        }
        let single = try XCTUnwrap(RoomSurfaceModel.consolidate([polygon]).first)
        XCTAssertLessThanOrEqual(single.vertices.count, 24)
        XCTAssertTrue(single.worldVertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        polygon.vertices[0].x = .nan
        XCTAssertTrue(RoomSurfaceModel.consolidate([polygon]).isEmpty)
    }
}
