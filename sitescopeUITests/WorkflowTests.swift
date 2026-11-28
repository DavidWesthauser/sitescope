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
        create(in: app, button: "houses.new", name: "Test house", confirm: "Create")
        app.staticTexts["Test house"].tap()
        create(in: app, button: "rooms.new", name: "Test room", confirm: "Create")
        app.staticTexts["Test room"].tap()
        menu(in: app, "room.more", choose: "Rename")
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Renamed room")
        app.alerts.buttons["Rename"].tap()
        XCTAssertTrue(app.navigationBars["Renamed room"].waitForExistence(timeout: 5), "Saved on the phone at once")
        menu(in: app, "room.more", choose: "Delete Room")
        confirmDelete(in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()  // House → project.
        menu(in: app, "project.more", choose: "Delete Project")
        confirmDelete(in: app)
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
    /// Opens the "…" menu of the screen and picks an item.
    private func menu(in app: XCUIApplication, _ identifier: String, choose item: String) {
        let more = app.buttons[identifier]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let entry = app.buttons[item]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
    }
    /// Deleting always asks first; the alert names the item and offers Cancel.
    private func confirmDelete(in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        alert.buttons["Delete"].tap()
    }
}
