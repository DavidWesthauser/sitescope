import XCTest

final class WorkflowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        if !app.launchArguments.contains("-disableAnimations") { app.launchArguments.append("-disableAnimations") }
        return app
    }

    /// Signed out, the app shows only the sign-in screen, and sign-in needs an email and 6 characters.
    func testAppRequiresSignIn() throws {
        let app = makeApp()
        app.launch()
        guard app.buttons["auth.submit"].waitForExistence(timeout: 5) else {
            throw XCTSkip("A saved login on this simulator opened the projects; sign out first.")
        }
        XCTAssertFalse(app.buttons["projects.new"].exists, "Nothing but sign-in is reachable while signed out")
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        app.textFields["auth.email"].tap()
        app.textFields["auth.email"].typeText("someone@example.test")
        app.secureTextFields["auth.password"].tap()
        app.secureTextFields["auth.password"].typeText("short")  // 5 characters.
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled, "Passwords under 6 characters are rejected")
    }

    /// Requires a configured backend and sitescope_TEST_EMAIL/PASSWORD in the test process environment.
    func testCreateProjectHouseRoomRenameAndDelete() throws {
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
        let title = "UITest-" + String(UUID().uuidString.prefix(8))
        create(in: app, button: "projects.new", name: title, confirm: "Create")
        app.staticTexts[title].tap()
        create(in: app, button: "houses.new", name: "Test house", confirm: "Add")
        app.staticTexts["Test house"].tap()
        create(in: app, button: "rooms.new", name: "Test room", confirm: "Add")
        app.staticTexts["Test room"].tap()
        replaceFieldText(app.textFields["room.name"], with: "Renamed room")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeDown()  // Pull to refresh: the list must show the name saved on the server.
        XCTAssertTrue(app.staticTexts["Renamed room"].waitForExistence(timeout: 20))
        app.staticTexts["Renamed room"].tap()
        delete(in: app, button: "room.delete", confirm: "room.delete.confirm")
        app.navigationBars.buttons.element(boundBy: 0).tap()  // House → project.
        delete(in: app, button: "project.delete", confirm: "project.delete.confirm")
        XCTAssertTrue(app.buttons["projects.new"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts[title].exists)
    }

    private func create(in app: XCUIApplication, button: String, name: String, confirm: String) {
        XCTAssertTrue(app.buttons[button].waitForExistence(timeout: 20))
        app.buttons[button].tap()
        XCTAssertFalse(app.alerts.buttons[confirm].isEnabled)  // Empty input is rejected visibly.
        app.alerts.textFields.firstMatch.typeText(name)
        let action = app.alerts.buttons[confirm]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true AND isHittable == true"), object: action)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        action.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 20))
    }
    /// Deletes through the confirmation dialog.
    private func delete(in app: XCUIApplication, button: String, confirm: String) {
        let delete = app.buttons[button]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        for _ in 0..<5 where !delete.isHittable { app.swipeUp() }
        delete.tap()
        let confirmation = app.buttons[confirm].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
    }
    /// Replaces an inline name field's text and commits it with Return. Taps near the trailing edge so the caret
    /// sits after the text and the deletes remove all of it.
    private func replaceFieldText(_ field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value + "\n")
    }
}
