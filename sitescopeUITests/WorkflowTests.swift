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
            XCTAssertTrue(app.alerts["AR Not Available"].waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.alerts.staticTexts["This device does not support AR world tracking. Use the task list instead."]
                    .exists)
            app.alerts.buttons["OK"].tap()
        #else
            if app.alerts["AR Not Available"].waitForExistence(timeout: 3) { app.alerts.buttons["OK"].tap() }
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
        deleteProject(app)
    }
    func testLocalProjectRenameSurvivesRelaunch() {
        let app = makeApp()
        app.launch()
        let title = "Project-" + String(UUID().uuidString.prefix(8))
        let renamed = "Renamed-" + String(UUID().uuidString.prefix(8))
        createProject(app, title: title)
        app.staticTexts[title].tap()
        replaceFieldText(app.textFields["project.name"], with: renamed)
        // The title follows the draft while typing, so check the saved name in the list instead.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[title].exists)
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
        replaceFieldText(app.textFields["room.name"], with: "Renamed room")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Renamed room"].waitForExistence(timeout: 5), "Saved name shows in the list")
        XCTAssertFalse(app.staticTexts["Original room"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.staticTexts[title].tap()
        XCTAssertTrue(app.staticTexts["Renamed room"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Original room"].exists)
        app.staticTexts["Renamed room"].tap()
        // An edit that was never committed with Return must not be saved onto the deleted room.
        let field = app.textFields["room.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        field.typeText(" draft")
        deleteRoom(app)
        XCTAssertTrue(app.buttons["rooms.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "No error after deleting")
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
    func testAppearanceSettingAppliesAndSurvivesRelaunch() {
        let app = makeApp()
        app.launch()
        chooseAppearance("Dark", in: app)
        app.terminate()
        app.launch()
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let picker = app.buttons["settings.appearance"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Dark") || (picker.value as? String) == "Dark", "\(picker.label)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        chooseAppearance("System", in: app)  // UserDefaults outlive the test; leave the default behind.
    }
    private func chooseAppearance(_ option: String, in app: XCUIApplication) {
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let picker = app.buttons["settings.appearance"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let choice = app.buttons[option]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 5))
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
    /// Deletes through the confirmation dialog; the project must stay until the destructive button is confirmed.
    private func deleteProject(_ app: XCUIApplication) {
        let delete = app.buttons["project.delete"]
        scrollTo(delete, in: app)
        delete.tap()
        let confirm = app.buttons["project.delete.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rooms.new"].exists, "Nothing is deleted before the user confirms")
        confirm.tap()
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "No error after deleting")
    }
    private func deleteRoom(_ app: XCUIApplication) {
        let delete = app.buttons["room.delete"]
        scrollTo(delete, in: app)
        delete.tap()
        let confirm = app.buttons["room.delete.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
    }
    /// Replaces an inline name field's text and commits it with Return. Taps near the trailing edge so the caret
    /// sits after the text and the deletes remove all of it.
    private func replaceFieldText(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value + "\n")
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
        replaceFieldText(app.textFields["room.name"], with: "Renamed room")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown()  // Pull to refresh: the list must show the name saved on the server.
        XCTAssertTrue(app.staticTexts["Renamed room"].waitForExistence(timeout: 20))
        app.staticTexts["Renamed room"].tap()
        deleteRoom(app)
        deleteProject(app)
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts[String(title)].exists)
    }
}
