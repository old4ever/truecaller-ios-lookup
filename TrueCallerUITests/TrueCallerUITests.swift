import XCTest

final class TrueCallerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    private func openSettings(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
    }

    private func secureField(in app: XCUIApplication) -> XCUIElement {
        let field = app.secureTextFields["Truecaller installationId"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        return field
    }

    private func clearState(_ app: XCUIApplication) {
        openSettings(app)
        let clear = app.buttons["Clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.staticTexts["Token is not set"].waitForExistence(timeout: 5))
    }

    func testInitialStateShowsTokenNotSet() throws {
        let app = launchApp()
        clearState(app)
    }

    func testUnsavedTokenAndSaveContract() throws {
        let token = "uitest-token-" + UUID().uuidString.prefix(8).lowercased()
        let app = launchApp()
        clearState(app)
        let field = secureField(in: app)
        field.tap()
        field.typeText(String(token))
        XCTAssertTrue(app.staticTexts["Token has unsaved changes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Token is saved"].exists)
        XCTAssertFalse(app.staticTexts["Stored in Keychain"].exists)
        let save = app.buttons["Save Token"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Token is saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stored in Keychain"].waitForExistence(timeout: 5))
        app.buttons["Clear"].tap()
        XCTAssertTrue(app.staticTexts["Token is not set"].waitForExistence(timeout: 5))
    }

    func testSavePersistsRevealAndClear() throws {
        let token = "uitest-token-" + UUID().uuidString.prefix(8).lowercased()
        let app = launchApp()
        clearState(app)
        let field = secureField(in: app)
        field.tap()
        field.typeText(String(token))
        app.buttons["Save Token"].tap()
        XCTAssertTrue(app.staticTexts["Token is saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stored in Keychain"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openSettings(app)
        XCTAssertTrue(app.staticTexts["Token is saved"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Stored in Keychain"].waitForExistence(timeout: 5))
        app.buttons["Reveal Token"].tap()
        let plain = app.textFields["Truecaller installationId"]
        XCTAssertTrue(plain.waitForExistence(timeout: 5))
        XCTAssertEqual(plain.value as? String, String(token))
        app.buttons["Clear"].tap()
        XCTAssertTrue(app.staticTexts["Token is not set"].waitForExistence(timeout: 5))
        XCTAssertTrue((plain.value as? String ?? "").isEmpty || (plain.value as? String) == "Truecaller installationId")
    }
}
