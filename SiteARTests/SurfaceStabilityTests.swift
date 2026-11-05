import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class SurfaceStabilityTests: XCTestCase {
    private func pose(depth:Float=0,tilt:Float=0,tangent:Float=0) throws -> Pose {
        var matrix=simd_float4x4(simd_quatf(angle:tilt,axis:SIMD3<Float>(1,0,0)))
        matrix.columns.3=SIMD4<Float>(tangent,depth,tangent,1)
        return try Pose(matrix)
    }

    func testSmallDepthChangesAccumulateAgainstOriginalReference() throws {
        var stability=SurfaceStability()
        stability.observe(.identity,at:0)
        stability.observe(try pose(depth:0.008),at:0.2)
        stability.observe(try pose(depth:0.016),at:0.4)
        stability.observe(try pose(depth:0.024),at:0.6)
        XCTAssertFalse(stability.isReady(at:0.6))
        stability.observe(try pose(depth:0.024),at:0.9)
        stability.observe(try pose(depth:0.024),at:1.21)
        XCTAssertTrue(stability.isReady(at:1.21))
    }

    func testSmallNormalChangesAccumulateAgainstOriginalReference() throws {
        var stability=SurfaceStability()
        stability.observe(.identity,at:0)
        for step in 1...4 {
            stability.observe(try pose(tilt:Float(step)*Float.pi/180),at:Double(step)*0.2)
        }
        XCTAssertFalse(stability.isReady(at:0.8))
        stability.observe(try pose(tilt:4*Float.pi/180),at:1.41)
        XCTAssertTrue(stability.isReady(at:1.41))
    }

    func testTangentialOriginChangesDoNotRestartSettling() throws {
        var stability=SurfaceStability()
        stability.observe(.identity,at:0)
        stability.observe(try pose(tangent:3),at:0.3)
        stability.observe(try pose(tangent:6),at:0.6)
        XCTAssertTrue(stability.isReady(at:0.6))
    }

    func testReadinessExpiresWhenLastObservationIsStale() {
        var stability=SurfaceStability()
        stability.observe(.identity,at:0)
        stability.observe(.identity,at:0.6)
        XCTAssertTrue(stability.isReady(at:1.6))
        XCTAssertFalse(stability.isReady(at:1.601))
    }

    func testObservationAfterLongGapMustSettleAgain() {
        var stability=SurfaceStability()
        stability.observe(.identity,at:0)
        stability.observe(.identity,at:0.6)
        XCTAssertTrue(stability.isReady(at:0.6))
        stability.observe(.identity,at:2)
        XCTAssertFalse(stability.isReady(at:2))
        stability.observe(.identity,at:2.3)
        stability.observe(.identity,at:2.61)
        XCTAssertTrue(stability.isReady(at:2.61))
    }

    func testBackwardsObservationRestartsEvidence() {
        var stability=SurfaceStability()
        stability.observe(.identity,at:10)
        stability.observe(.identity,at:10.6)
        stability.observe(.identity,at:1)
        XCTAssertFalse(stability.isReady(at:1.1))
        stability.observe(.identity,at:1.61)
        XCTAssertTrue(stability.isReady(at:1.61))
    }

    func testNonfiniteObservationClearsEvidenceAndInvalidQueriesAreRejected() {
        for invalid in [Double.nan,Double.infinity,-Double.infinity] {
            var stability=SurfaceStability()
            stability.observe(.identity,at:0)
            stability.observe(.identity,at:0.6)
            XCTAssertFalse(stability.isReady(at:invalid))
            XCTAssertFalse(stability.isReady(at:0.5))
            stability.observe(.identity,at:invalid)
            XCTAssertFalse(stability.isReady(at:0.7))
            stability.observe(.identity,at:1)
            XCTAssertFalse(stability.isReady(at:1.1))
            stability.observe(.identity,at:1.61)
            XCTAssertTrue(stability.isReady(at:1.61))
        }
    }
}
