import XCTest

final class TrueCallerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
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

    private func tapResultAction(_ identifier: String, in app: XCUIApplication) {
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        for _ in 0..<4 where !action.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(action.isHittable)
        action.tap()
    }

    private func assertContactEditor(
        in app: XCUIApplication,
        name: String,
        phoneFragment: String
    ) -> XCUIElement {
        let editor = app.navigationBars["New Contact"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertEqual(app.alerts.count, 0, "Presenting ContactsUI must not request Contacts permission")

        let nameField = app.textFields.matching(
            NSPredicate(format: "value == %@", name)
        ).firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        let phoneFields = app.textFields.matching(
            NSPredicate(format: "value CONTAINS %@", phoneFragment)
        )
        XCTAssertTrue(phoneFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(phoneFields.count, 1)

        let save = editor.buttons.matching(
            NSPredicate(format: "label == 'Add' OR label == 'Done'")
        ).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        return editor
    }

    private func cancelContactEditor(_ editor: XCUIElement, in app: XCUIApplication) {
        editor.buttons["Cancel"].tap()
        let discardChanges = app.buttons["Discard Changes"]
        if discardChanges.waitForExistence(timeout: 2) {
            discardChanges.tap()
        }
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
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

    func testAddToContactsPresentsPrefilledNativeEditor() throws {
        let app = launchApp(arguments: ["--ui-testing-contact-export-fixture"])

        tapResultAction("add-to-contacts-fixture-api-phones", in: app)
        let entryPhoneEditor = assertContactEditor(
            in: app,
            name: "Ada Fixture",
            phoneFragment: "416"
        )
        cancelContactEditor(entryPhoneEditor, in: app)

        tapResultAction("add-to-contacts-fixture-query-fallback", in: app)
        let fallbackEditor = assertContactEditor(
            in: app,
            name: "Fallback Fixture",
            phoneFragment: "7946"
        )
        cancelContactEditor(fallbackEditor, in: app)
    }
}
