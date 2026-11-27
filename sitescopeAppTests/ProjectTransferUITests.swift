#if canImport(UIKit) && !canImport(sitescopeCore)
    import XCTest
    @testable import sitescope

    @MainActor final class ProjectTransferUITests: XCTestCase {
        /// The export button stays disabled until its share sheet finishes, so tearing the sheet down must finish it.
        func testTearingDownTheShareSheetReEnablesExport() {
            let presenter = ProjectActivityPresenter.Presenter()
            var finished = 0
            presenter.onFinish = { finished += 1 }
            presenter.requestedURL = FileManager.default.temporaryDirectory.appendingPathComponent("a.sitescope")
            ProjectActivityPresenter.dismantleUIViewController(presenter, coordinator: ())
            XCTAssertEqual(finished, 1)
            XCTAssertNil(presenter.requestedURL)
            ProjectActivityPresenter.dismantleUIViewController(presenter, coordinator: ())
            XCTAssertEqual(finished, 1, "Finishing twice must not run the cleanup twice")
        }
    }
#endif
