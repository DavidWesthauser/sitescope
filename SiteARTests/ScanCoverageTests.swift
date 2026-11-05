import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class ScanCoverageTests: XCTestCase {
    private let forward = SIMD3<Float>(0,0,1)

    private func pause(_ coverage: inout ScanCoverage, position: SIMD3<Float> = .zero, forward: SIMD3<Float> = SIMD3(0,0,1), at time: TimeInterval) {
        coverage.observe(position: position, forward: forward, reliable: true, at: time)
        coverage.observe(position: position, forward: forward, reliable: true, at: time + 0.75)
    }

    func testBriefSweepDoesNotQualifyButPausedViewsDo() {
        var coverage = ScanCoverage()
        for i in 0..<4 {
            let angle = Float(i) * .pi / 2 + 0.2
            coverage.observe(position: .zero, forward: SIMD3(sin(angle),0,cos(angle)), reliable: true, at: Double(i) * 0.1)
        }
        XCTAssertTrue(coverage.headings.isEmpty)
        XCTAssertTrue(coverage.positions.isEmpty)
        for i in 0..<4 {
            let angle = Float(i) * .pi / 2 + 0.2
            pause(&coverage, position: SIMD3(Float(i) * 0.6,0,0), forward: SIMD3(sin(angle),0,cos(angle)), at: 1 + Double(i))
        }
        XCTAssertEqual(coverage.headings.count, 4)
        XCTAssertEqual(coverage.directionProgress, [1,1,1,1])
        XCTAssertEqual(coverage.positions.count, 4)
        XCTAssertTrue(coverage.ready)
    }

    func testProgressAccumulatesOnlyWithinOneSteadySector() {
        var coverage = ScanCoverage()
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 0)
        let heading = coverage.currentHeading!
        coverage.observe(position: SIMD3(0.1,0,0), forward: forward, reliable: true, at: 0.375)
        XCTAssertEqual(coverage.directionProgress[heading], 0.5, accuracy: 0.0001)
        XCTAssertEqual(coverage.directionProgress.filter { $0 > 0 }.count, 1)
        coverage.observe(position: .zero, forward: SIMD3(1,0,0), reliable: true, at: 0.5)
        XCTAssertEqual(coverage.directionProgress, [0,0,0,0])
        XCTAssertTrue(coverage.headings.isEmpty)
        coverage.observe(position: .zero, forward: SIMD3(1,0,0), reliable: true, at: 1.25)
        XCTAssertEqual(coverage.headings.count, 1)
    }

    func testMotionAndLongGapsRestartDwell() {
        var coverage = ScanCoverage()
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 0)
        coverage.observe(position: SIMD3(0.36,0,0), forward: forward, reliable: true, at: 0.75)
        XCTAssertTrue(coverage.headings.isEmpty)
        XCTAssertEqual(coverage.directionProgress, [0,0,0,0])
        coverage.observe(position: SIMD3(0.36,0,0), forward: forward, reliable: true, at: 1.4)
        XCTAssertTrue(coverage.headings.isEmpty)
        coverage.observe(position: SIMD3(0.36,0,0), forward: forward, reliable: true, at: 2.41)
        XCTAssertEqual(coverage.directionProgress, [0,0,0,0])
        coverage.observe(position: SIMD3(0.36,0,0), forward: forward, reliable: true, at: 3.16)
        XCTAssertEqual(coverage.headings.count, 1)
        XCTAssertEqual(coverage.positions.count, 1)
    }

    func testTrackingLossPreservesCompletedViewsAndResetsPendingView() {
        var coverage = ScanCoverage()
        pause(&coverage, at: 0)
        let confirmed = coverage.headings
        let other = SIMD3<Float>(1,0,0)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: true, at: 1)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: true, at: 1.4)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: false, at: 1.5)
        XCTAssertNil(coverage.currentHeading)
        XCTAssertEqual(coverage.headings, confirmed)
        XCTAssertEqual(coverage.positions.count, 1)
        XCTAssertEqual(coverage.directionProgress.reduce(0,+), 1)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: true, at: 1.6)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: true, at: 2)
        XCTAssertEqual(coverage.headings, confirmed)
        coverage.observe(position: SIMD3(1,0,0), forward: other, reliable: true, at: 2.35)
        XCTAssertEqual(coverage.headings.count, 2)
    }

    func testBackwardClockStartsFreshCandidateAndRepeatedTimeCannotFinish() {
        var coverage = ScanCoverage()
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 10)
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 10.5)
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 9)
        XCTAssertEqual(coverage.directionProgress, [0,0,0,0])
        for _ in 0..<10 { coverage.observe(position: .zero, forward: forward, reliable: true, at: 9) }
        XCTAssertTrue(coverage.headings.isEmpty)
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 9.75)
        XCTAssertEqual(coverage.headings.count, 1)
    }

    func testExplicitInterruptRetainsCompletedEvidenceAndClearsPendingTiming() {
        var coverage = ScanCoverage()
        pause(&coverage, at: 0)
        let headings = coverage.headings, positions = coverage.positions
        coverage.observe(position: SIMD3(1,0,0), forward: SIMD3(1,0,0), reliable: true, at: 1)
        coverage.observe(position: SIMD3(1,0,0), forward: SIMD3(1,0,0), reliable: true, at: 1.4)
        coverage.interrupt()
        XCTAssertNil(coverage.currentHeading)
        XCTAssertEqual(coverage.headings, headings)
        XCTAssertEqual(coverage.positions, positions)
        XCTAssertEqual(coverage.directionProgress.reduce(0,+), 1)
        coverage.observe(position: SIMD3(1,0,0), forward: SIMD3(1,0,0), reliable: true, at: 100)
        XCTAssertEqual(coverage.headings, headings)
        coverage.observe(position: SIMD3(1,0,0), forward: SIMD3(1,0,0), reliable: true, at: 100.75)
        XCTAssertEqual(coverage.headings.count, 2)
    }

    func testInvalidNumbersAndVerticalViewNeverProduceNaNProgress() {
        let invalid: [(SIMD3<Float>, SIMD3<Float>, TimeInterval)] = [
            (.zero, forward, .nan), (.zero, forward, .infinity),
            (SIMD3(.nan,0,0), forward, 1), (SIMD3(0,.infinity,0), forward, 1),
            (.zero, SIMD3(.infinity,0,1), 1), (.zero, SIMD3(0,1,0), 1)
        ]
        for (position, direction, time) in invalid {
            var coverage = ScanCoverage()
            coverage.observe(position: .zero, forward: forward, reliable: true, at: 0)
            coverage.observe(position: position, forward: direction, reliable: true, at: time)
            XCTAssertNil(coverage.currentHeading)
            XCTAssertTrue(coverage.directionProgress.allSatisfy { $0.isFinite && (0...1).contains($0) })
            XCTAssertTrue(coverage.headings.isEmpty)
            pause(&coverage, at: 2)
            XCTAssertEqual(coverage.headings.count, 1)
        }
    }

    func testQualifiedPositionsAreSpacedAndBounded() {
        var coverage = ScanCoverage()
        pause(&coverage, at: 0)
        pause(&coverage, position: SIMD3(0.49,0,0), at: 1)
        XCTAssertEqual(coverage.positions.count, 1)
        pause(&coverage, position: SIMD3(0.5,0,0), at: 2)
        XCTAssertEqual(coverage.positions.count, 2)
        for i in 1...50 {
            pause(&coverage, position: SIMD3(Float(i),0,0), at: 3 + Double(i))
        }
        XCTAssertEqual(coverage.positions.count, 32)
        XCTAssertEqual(coverage.headings.count, 1)
        XCTAssertFalse(coverage.ready)
        for (index, point) in coverage.positions.enumerated() {
            for other in coverage.positions.dropFirst(index + 1) {
                XCTAssertGreaterThanOrEqual(simd_distance(SIMD2(point.x,point.z), SIMD2(other.x,other.z)), 0.5)
            }
        }
    }

    func testOneQualifiedPauseCannotAddMultiplePositionSamples() {
        var coverage = ScanCoverage()
        coverage.observe(position: .zero, forward: forward, reliable: true, at: 0)
        coverage.observe(position: SIMD3(0.3,0,0), forward: forward, reliable: true, at: 0.75)
        coverage.observe(position: SIMD3(-0.3,0,0), forward: forward, reliable: true, at: 0.8)
        XCTAssertEqual(coverage.positions.count, 1)
    }
}
