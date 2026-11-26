#if DEBUG
    import XCTest

    #if canImport(sitescopeCore)
        @testable import sitescopeCore
    #else
        @testable import sitescope
    #endif

    final class DebugReadoutTests: XCTestCase {
        func testFrameRateIsZeroUntilTwoFrames() {
            var meter = FrameRateMeter()
            XCTAssertEqual(meter.fps, 0)
            meter.tick(10)
            XCTAssertEqual(meter.fps, 0)
        }
        func testFrameRateFollowsTimestamps() {
            var meter = FrameRateMeter()
            for index in 0..<120 { meter.tick(Double(index) / 60) }
            XCTAssertEqual(meter.fps, 60, accuracy: 0.5)
        }
        func testFrameRateIgnoresRepeatedOrOlderTimestamps() {
            var meter = FrameRateMeter()
            meter.tick(1)
            meter.tick(1.5)
            let before = meter.fps
            meter.tick(1.5)
            meter.tick(1.0)
            XCTAssertEqual(meter.fps, before)
        }
        func testResetClearsFrameRate() {
            var meter = FrameRateMeter()
            meter.tick(1)
            meter.tick(1.1)
            meter.reset()
            XCTAssertEqual(meter.fps, 0)
        }
        func testReadoutTextHasOneLinePerValue() {
            var readout = DebugReadout()
            readout.fps = 59.6
            readout.featurePoints = 412
            readout.device = "iPhone"
            readout.system = "iOS 17"
            XCTAssertEqual(readout.lines.count, 9)
            XCTAssertTrue(readout.text.contains("FPS 60"))
            XCTAssertTrue(readout.text.contains("Feature points 412"))
            XCTAssertTrue(readout.text.hasSuffix("iPhone · iOS 17"))
        }
    }
#endif
