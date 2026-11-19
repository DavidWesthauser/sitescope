import XCTest

final class WorkflowTests: XCTestCase {
    /// Per-test local data folder name, resolved by the app inside its own temporary directory.
    private var dataFolder = ""
    override func setUpWithError() throws {
        continueAfterFailure = false
        dataFolder = "uitest-" + UUID().uuidString
    }
    /// Creates an app whose local data lives in a fresh folder. Relaunch the returned app to keep its data.
    private func makeApp(resetData: Bool = true) -> XCUIApplication {
        if resetData { dataFolder = "uitest-" + UUID().uuidString }
        let app = XCUIApplication()
        app.launchEnvironment["SITESCOPE_LOCAL_DATA_DIR"] = dataFolder
        if !app.launchArguments.contains("-disableAnimations") { app.launchArguments.append("-disableAnimations") }
        return app
    }
    func testProjectFileImportCanBeCancelled() {
        let app = makeApp()
        app.launch()
        let importButton = app.buttons["projects.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10))
        let importReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: importButton)
        XCTAssertEqual(XCTWaiter.wait(for: [importReady], timeout: 10), .completed)
        importButton.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 20))
        cancel.tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["sitescope"].exists)
    }
    func testProjectExportOpensNativeShareSheet() {
        let app = makeApp()
        app.launch()
        let title = "Export-" + String(UUID().uuidString.prefix(8))
        createProject(app, title: title)
        app.staticTexts[title].tap()
        let export = app.buttons["project.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        let sheet = app.collectionViews["activityCollectionView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.cells["Save to Files"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native project file sharing"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if app.otherElements["PopoverDismissRegion"].exists {
            app.otherElements["PopoverDismissRegion"].tap()
        } else {
            app.buttons["header.closeButton"].tap()
        }
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertTrue(export.isEnabled)
        deleteProject(app)
    }
    func testAuthenticationValidation() throws {
        let app = makeApp()
        app.launch()
        guard app.buttons["auth.submit"].waitForExistence(timeout: 3) else {
            throw XCTSkip(
                "Authentication is disabled in the unconfigured local Debug build; this is not an Auth acceptance pass."
            )
        }
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        XCTAssertTrue(app.textFields["auth.email"].exists)
        XCTAssertTrue(app.secureTextFields["auth.password"].exists)
    }

    func testLocalUseSkipsLoginAndCreatesOwnRoom() {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.submit"].exists)
        XCTAssertFalse(app.staticTexts["Apartment Renovation"].exists)
        let title = "UITest-" + UUID().uuidString.prefix(8)
        app.buttons["projects.new"].tap()
        app.alerts.textFields.firstMatch.typeText(String(title))
        submitAlert(app, button: "Create")
        XCTAssertTrue(app.staticTexts[String(title)].waitForExistence(timeout: 5))
        app.staticTexts[String(title)].tap()
        app.buttons["rooms.new"].tap()
        app.alerts.textFields.firstMatch.typeText("My room")
        submitAlert(app, button: "Add")
        XCTAssertTrue(app.staticTexts["My room"].waitForExistence(timeout: 5))
        app.staticTexts["My room"].tap()
        XCTAssertTrue(app.buttons["Map room"].waitForExistence(timeout: 5))
        app.buttons["Map room"].tap()
        #if targetEnvironment(simulator)
            XCTAssertTrue(app.alerts["AR guidance"].waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.alerts.staticTexts["This device does not support AR world tracking. Use the task list instead."]
                    .exists)
            app.alerts.buttons["OK"].tap()
        #else
            if app.alerts["AR guidance"].waitForExistence(timeout: 3) { app.alerts.buttons["OK"].tap() }
        #endif
        XCTAssertTrue(app.staticTexts["Live scan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scan.finish"].exists)
        XCTAssertFalse(app.buttons["scan.finish"].isEnabled)  // Simulator cannot collect a real map.
        XCTAssertFalse(app.buttons["Register detected marker"].exists)
        XCTAssertFalse(app.buttons["Capture at crosshair"].exists)
        app.buttons["Scan options and progress"].tap()
        XCTAssertTrue(app.staticTexts["Directions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Positions"].exists)
        let guideOption = app.switches["Save a viewpoint photo"]
        XCTAssertTrue(guideOption.waitForExistence(timeout: 5))
        XCTAssertTrue(guideOption.isEnabled)
        XCTAssertFalse(app.buttons["Generate print"].exists)
        XCTAssertFalse(app.buttons["Register detected marker"].exists)
        app.buttons["Done"].tap()
        let closeReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["Close"])
        XCTAssertEqual(XCTWaiter.wait(for: [closeReady], timeout: 5), .completed)
        app.buttons["Close"].tap()
        app.buttons["Close AR"].tap()
        let back = app.navigationBars.buttons[String(title)]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: back)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed)
        back.tap()
        app.buttons["Delete project and all rooms"].tap()
        app.buttons["Delete project"].tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 5))
    }
    func testLocalProjectRenameSurvivesRelaunch() {
        let app = makeApp()
        app.launch()
        let title = "Project-" + String(UUID().uuidString.prefix(8))
        let renamed = "Renamed-" + String(UUID().uuidString.prefix(8))
        createProject(app, title: title)
        app.staticTexts[title].tap()
        app.buttons["Rename project"].tap()
        replaceAlertText(app, with: renamed)
        submitAlert(app, button: "Save")
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[title].exists)
        app.staticTexts[renamed].tap()
        deleteProject(app)
    }
    func testLocalRoomRenameAndDeleteSurviveRelaunch() {
        let app = makeApp()
        app.launch()
        let title = "Rooms-" + String(UUID().uuidString.prefix(8))
        createProject(app, title: title)
        app.staticTexts[title].tap()
        app.buttons["rooms.new"].tap()
        app.alerts.textFields.firstMatch.typeText("Original room")
        submitAlert(app, button: "Add")
        XCTAssertTrue(app.staticTexts["Original room"].waitForExistence(timeout: 5))
        app.staticTexts["Original room"].tap()
        app.buttons["Rename room"].tap()
        replaceAlertText(app, with: "Renamed room")
        submitAlert(app, button: "Save")
        XCTAssertTrue(app.navigationBars["Renamed room"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.staticTexts[title].tap()
        XCTAssertTrue(app.staticTexts["Renamed room"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Original room"].exists)
        app.staticTexts["Renamed room"].tap()
        app.buttons["Delete room"].tap()
        app.buttons.matching(identifier: "Delete room").allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(app.buttons["rooms.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Renamed room"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.staticTexts[title].tap()
        XCTAssertTrue(app.buttons["rooms.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Renamed room"].exists)
        deleteProject(app)
    }
    private func submitAlert(_ app: XCUIApplication, button: String) {
        let action = app.alerts.buttons[button]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true AND isHittable == true"), object: action)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        action.tap()
        XCTAssertTrue(
            app.alerts.firstMatch.waitForNonExistence(timeout: 5), "Submission should dismiss the native alert")
    }
    private func createProject(_ app: XCUIApplication, title: String) {
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        app.buttons["projects.new"].tap()
        XCTAssertFalse(app.alerts.buttons["Create"].isEnabled)  // Empty input is rejected visibly.
        app.alerts.textFields.firstMatch.typeText(title)
        submitAlert(app, button: "Create")
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }
    /// Clears the alert's text field whatever it holds (prefilled text or placeholder), then types the value.
    /// Taps near the trailing edge so the caret sits at the end; the edit menu's "Select All" is not used because
    /// it disappears before it can be tapped.
    private func replaceAlertText(_ app: XCUIApplication, with value: String) {
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        // One batched delete per pass: each typeText call costs a UI snapshot, so per-character calls are slow.
        for _ in 0...3 {
            guard let current = field.value as? String, !current.isEmpty, current != field.placeholderValue else {
                break
            }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
    }
    private func deleteProject(_ app: XCUIApplication) {
        app.buttons["Delete project and all rooms"].tap()
        app.buttons["Delete project"].tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 5))
    }
    /// Requires a configured backend and sitescope_TEST_EMAIL/PASSWORD in the test process environment.
    func testCreateProjectRoomRenameAndDelete() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["sitescope_TEST_EMAIL"], let password = env["sitescope_TEST_PASSWORD"] else {
            throw XCTSkip(
                "Configure a dedicated backend test account using sitescope_TEST_EMAIL and sitescope_TEST_PASSWORD.")
        }
        let app = makeApp()
        app.launch()
        if app.textFields["auth.email"].waitForExistence(timeout: 5) {
            app.textFields["auth.email"].tap()
            app.textFields["auth.email"].typeText(email)
            app.secureTextFields["auth.password"].tap()
            app.secureTextFields["auth.password"].typeText(password)
            app.buttons["auth.submit"].tap()
        }
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 20))
        let title = "UITest-" + UUID().uuidString.prefix(8)
        app.buttons["projects.new"].tap()
        app.alerts.textFields.firstMatch.typeText(String(title))
        submitAlert(app, button: "Create")
        XCTAssertTrue(app.staticTexts[String(title)].waitForExistence(timeout: 20))
        app.staticTexts[String(title)].tap()
        app.buttons["rooms.new"].tap()
        app.alerts.textFields.firstMatch.typeText("Test room")
        submitAlert(app, button: "Add")
        XCTAssertTrue(app.staticTexts["Test room"].waitForExistence(timeout: 20))
        app.staticTexts["Test room"].tap()
        app.buttons["Rename room"].tap()
        let field = app.alerts.textFields.firstMatch
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Test room".count) + "Renamed room")
        app.alerts.buttons["Save"].tap()
        app.buttons["Delete room"].tap()
        app.buttons.matching(identifier: "Delete room").allElementsBoundByIndex.last!.tap()
        app.buttons["Delete project and all rooms"].tap()
        app.buttons["Delete project"].tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts[String(title)].exists)
    }
}
