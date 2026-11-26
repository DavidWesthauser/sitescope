import XCTest

/// Walks every reachable screen, sheet and dialog and saves full-screen PNGs for the T-012 visual review.
/// Skipped unless `SITESCOPE_SCREENSHOT_DIR` is set (pass `TEST_RUNNER_SITESCOPE_SCREENSHOT_DIR` to xcodebuild);
/// `scripts/screenshots.sh` sets it and switches appearance, text size and device.
final class ScreenshotTour: XCTestCase {
    private var output: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SITESCOPE_SCREENSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("Set SITESCOPE_SCREENSHOT_DIR to record the screenshot tour.")
        }
        continueAfterFailure = true
        output = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    }

    func testEmptyStates() throws {
        launch(dataDirectory: "screens-empty-" + UUID().uuidString)
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        shot("01-projects-empty")
        app.buttons["projects.new"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        shot("02-projects-new-alert")
        app.alerts.buttons["Cancel"].tap()
    }

    func testRecoveryScreen() throws {
        let folder = try seedFolder(contents: "{ not json")
        launch(dataDirectory: folder.path)
        let start = app.buttons["Start fresh, keep backup"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        dismissAlertIfPresent()
        shot("30-recovery")
        start.tap()
        pause()
        shot("31-recovery-dialog")
    }

    func testTour() throws {
        launch(dataDirectory: try seedFolder(contents: Self.seed).path)
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        shot("03-projects-list")

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            search.tap()
            search.typeText("zzz")
            shot("04-projects-search-empty")
            tapFirst(["Cancel", "Close", "close"])
            pause()
        }

        if tapFirst(["settings.open", "Settings", "gearshape"]) {
            pause()
            shot("05-settings")
            swipeUpShot("05-settings")
            if app.buttons["settings.appearance"].exists {
                tap(app.buttons["settings.appearance"])
                pause()
                shot("05-settings-appearance-menu")
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
                pause()
            }
            if tapFirst(["Camera-only scanning tips"]) {
                pause()
                shot("06-scanning-tips")
                goBack()
            }
            goBack()
        }

        tap(app.staticTexts["Riverside Office"])
        XCTAssertTrue(app.buttons["rooms.new"].waitForExistence(timeout: 5))
        shot("07-project-detail")
        swipeUpShot("07-project-detail")
        app.swipeDown()

        tap(app.buttons["rooms.new"])
        pause()
        shot("08-project-add-room-alert")
        app.alerts.buttons["Cancel"].tap()

        if app.buttons["Rename project"].exists {
            app.buttons["Rename project"].tap()
            pause()
            shot("09-project-rename")
            app.alerts.buttons["Cancel"].tap()
        } else if app.textFields["project.name"].exists {
            tap(app.textFields["project.name"])
            pause()
            shot("09-project-rename")
            app.textFields["project.name"].typeText("\n")
        }

        app.swipeUp()
        if tapFirst(["project.delete", "Delete project and all rooms"]) {
            pause()
            shot("10-project-delete-dialog")
            dismissDialog()
        }
        app.swipeDown()

        let export = app.buttons["project.export"]
        if export.exists {
            tap(export)
            let sheet = app.collectionViews["activityCollectionView"]
            if sheet.waitForExistence(timeout: 10) {
                pause()
                shot("11-project-export-sheet")
                if app.otherElements["PopoverDismissRegion"].exists {
                    app.otherElements["PopoverDismissRegion"].tap()
                } else {
                    app.buttons["header.closeButton"].tap()
                }
                _ = sheet.waitForNonExistence(timeout: 5)
            }
        }

        tap(app.staticTexts["Kitchen"])
        XCTAssertTrue(app.staticTexts["Install upper cabinets"].waitForExistence(timeout: 5))
        shot("12-room-detail")
        swipeUpShot("12-room-detail")
        if app.textFields["room.name"].exists {
            tap(app.textFields["room.name"])
            pause()
            shot("13-room-rename")
            app.textFields["room.name"].typeText("\n")
        } else if tapFirst(["Rename room"]) {
            pause()
            shot("13-room-rename")
            app.alerts.buttons["Cancel"].tap()
        }
        app.swipeUp()
        if tapFirst(["room.delete", "Delete room"]) {
            pause()
            shot("14-room-delete-dialog")
            dismissDialog()
        }
        app.swipeDown()
        app.swipeDown()

        tap(app.staticTexts["Install upper cabinets"])
        pause()
        shot("15-task-editor")
        app.swipeUp()
        if tapFirst(["task.delete", "Delete instruction"]) {
            pause()
            shot("16-task-delete-dialog")
            dismissDialog()
        }
        app.swipeDown()
        let title = app.textFields.firstMatch
        if title.exists {
            tap(title)
            title.typeText(" now")
            dismissKeyboard()
            goBack()
            pause()
            shot("17-task-discard-dialog")
            tapFirst(["Discard Changes", "Discard changes"])
        }
        pause()
        goBack()

        XCTAssertTrue(app.staticTexts["Bathroom"].waitForExistence(timeout: 5))
        tap(app.staticTexts["Bathroom"])
        XCTAssertTrue(app.buttons["Map room"].waitForExistence(timeout: 5))
        shot("18-room-unmapped")
        tap(app.buttons["Map room"])
        if app.alerts.firstMatch.waitForExistence(timeout: 5) {
            pause()
            shot("19-ar-unsupported-alert")
            app.alerts.buttons.firstMatch.tap()
        }
        if app.buttons["scan.finish"].waitForExistence(timeout: 5) {
            pause()
            shot("20-ar-scan")
            if tapFirst(["Scan options and progress"]) {
                pause()
                shot("21-ar-scan-options")
                if tapFirst(["Restart scan"]) {
                    pause()
                    shot("22-ar-restart-dialog")
                    dismissDialog()
                }
                tapFirst(["Done"])
            }
            pause()
            tapFirst(["Close"])
            pause()
            tapFirst(["Close AR"])
        }
    }

    /// Switches the in-app Appearance setting and records a list, a sheet and dialogs for each choice.
    /// Run it once with the simulator in light mode and once in dark mode.
    func testAppearanceSetting() throws {
        launch(dataDirectory: try seedFolder(contents: Self.seed).path)
        for choice in ["Dark", "Light", "System"] {
            XCTAssertTrue(app.buttons["settings.open"].waitForExistence(timeout: 10))
            tap(app.buttons["settings.open"])
            tap(app.buttons["settings.appearance"])
            app.buttons[choice].tap()
            pause()
            let name = "40-app-" + choice.lowercased()
            shot(name + "-settings")
            goBack()
            shot(name + "-projects")
            app.buttons["projects.new"].tap()
            pause()
            shot(name + "-alert")
            app.alerts.buttons["Cancel"].tap()
            tap(app.staticTexts["Riverside Office"])
            pause()
            tap(app.buttons["project.export"])
            if app.collectionViews["activityCollectionView"].waitForExistence(timeout: 10) {
                pause()
                shot(name + "-share-sheet")
                if app.otherElements["PopoverDismissRegion"].exists {
                    app.otherElements["PopoverDismissRegion"].tap()
                } else {
                    app.buttons["header.closeButton"].tap()
                }
                _ = app.collectionViews["activityCollectionView"].waitForNonExistence(timeout: 5)
            }
            app.swipeUp()
            tapFirst(["project.delete"])
            pause()
            shot(name + "-delete-dialog")
            dismissDialog()
            app.swipeDown()
            tap(app.staticTexts["Bathroom"])
            tap(app.buttons["Map room"])
            if app.alerts.firstMatch.waitForExistence(timeout: 5) {
                pause()
                shot(name + "-ar-alert")
                app.alerts.buttons.firstMatch.tap()
            }
            if tapFirst(["Scan options and progress"]) {
                pause()
                shot(name + "-ar-options-sheet")
                tapFirst(["Done"])
            }
            pause()
            tapFirst(["Close"])
            pause()
            tapFirst(["Close AR"])
            pause()
            goBack()
            goBack()
        }
    }

    // MARK: - Helpers

    private func launch(dataDirectory: String) {
        app = XCUIApplication()
        app.launchEnvironment["SITESCOPE_LOCAL_DATA_DIR"] = dataDirectory
        app.launchArguments.append("-disableAnimations")
        app.launch()
    }

    private func seedFolder(contents: String) throws -> URL {
        let folder = output.deletingLastPathComponent().appendingPathComponent(".seed-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try contents.write(to: folder.appendingPathComponent("local.json"), atomically: true, encoding: .utf8)
        // Placeholder map files, so export finds every referenced asset. AR never opens them in the tour.
        for path in Self.mapPaths {
            let file = folder.appendingPathComponent("assets").appendingPathComponent(path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("map".utf8).write(to: file)
        }
        return folder
    }

    /// Store layout for room assets: `<project>/<room>/<file>`, lower-case IDs.
    private static func mapPath(_ project: String, _ room: String) -> String {
        "\(project.lowercased())/\(room.lowercased())/map.worldmap"
    }
    private static let mapPaths = [
        mapPath("10000000-0000-0000-0000-000000000001", "20000000-0000-0000-0000-000000000001"),
        mapPath("10000000-0000-0000-0000-000000000001", "20000000-0000-0000-0000-000000000003"),
    ]

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: output.appendingPathComponent(name + ".png"))
    }

    private func swipeUpShot(_ name: String) {
        app.swipeUp()
        pause()
        shot(name + "-bottom")
        app.swipeDown()
    }

    private func pause() { Thread.sleep(forTimeInterval: 0.8) }

    /// Scrolls until the element is on screen, then taps it; large text sizes push rows off screen.
    private func tap(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("Missing \(element)")
            return
        }
        for _ in 0..<3 where !element.isHittable { app.swipeDown() }
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        if element.isHittable { element.tap() } else { XCTFail("Not reachable: \(element)") }
    }

    @discardableResult private func tapFirst(_ labels: [String]) -> Bool {
        for label in labels where app.buttons[label].exists {
            tap(app.buttons[label])
            return true
        }
        return false
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        pause()
    }

    private func dismissDialog() {
        if tapFirst(["Cancel"]) { return }
        if app.otherElements["PopoverDismissRegion"].exists {
            app.otherElements["PopoverDismissRegion"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        pause()
    }

    private func dismissKeyboard() {
        if app.keyboards.firstMatch.exists { app.typeText("\n") }
    }

    private func dismissAlertIfPresent() {
        if app.alerts.firstMatch.waitForExistence(timeout: 2) { app.alerts.buttons.firstMatch.tap() }
    }

    /// Local store with long and short names, mapped and unmapped rooms and tasks in every status.
    private static let seed: String = {
        let owner = "00000000-0000-0000-0000-000000000001"
        let identity = "[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]"
        let p1 = "10000000-0000-0000-0000-000000000001"
        let p2 = "10000000-0000-0000-0000-000000000002"
        let p3 = "10000000-0000-0000-0000-000000000003"
        let kitchen = "20000000-0000-0000-0000-000000000001"
        let bath = "20000000-0000-0000-0000-000000000002"
        let office = "20000000-0000-0000-0000-000000000003"
        let kitchenCoordinate = "30000000-0000-0000-0000-000000000001"
        func room(_ id: String, _ project: String, _ name: String, mapped: Bool, _ coordinate: String) -> String {
            let map = mapped ? ", \"map_path\": \"\(ScreenshotTour.mapPath(project, id))\"" : ""
            return """
                {"id": "\(id)", "project_id": "\(project)", "name": "\(name)", "spatial_version": 1,
                 "coordinate_id": "\(coordinate)", "reference_points": [], "reference_notes": ""\(map)}
                """
        }
        func task(_ n: Int, _ title: String, _ detail: String, _ status: String, _ priority: Int) -> String {
            """
            {"id": "40000000-0000-0000-0000-00000000000\(n)", "room_id": "\(kitchen)",
             "coordinate_id": "\(kitchenCoordinate)", "kind": "text", "pose": \(identity),
             "points": [], "title": "\(title)", "detail": "\(detail)", "status": "\(status)", "priority": \(priority)}
            """
        }
        return """
            {"projects": [
              {"id": "\(p1)", "owner_id": "\(owner)", "name": "Riverside Office"},
              {"id": "\(p2)", "owner_id": "\(owner)", "name": "Apartment Renovation Kastanienallee 12, 3rd floor"},
              {"id": "\(p3)", "owner_id": "\(owner)", "name": "Warehouse"}],
             "rooms": [
              \(room(kitchen, p1, "Kitchen", mapped: true, kitchenCoordinate)),
              \(room(bath, p1, "Bathroom", mapped: false, "30000000-0000-0000-0000-000000000002")),
              \(room(office, p1, "Open-plan office with meeting corner", mapped: true,
                "30000000-0000-0000-0000-000000000003"))],
             "annotations": [
              \(task(1, "Install upper cabinets", "Mount the rail 145 cm above the floor; check the wall for pipes first.", "todo", 2)),
              \(task(2, "Paint window frame", "", "in_progress", 1)),
              \(task(3, "Remove old tiles", "Done on Monday.", "completed", 0)),
              \(task(4, "Seal sink edge", "Use the white silicone from the van.", "todo", 1))]}
            """
    }()
}
