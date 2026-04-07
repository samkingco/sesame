import XCTest

@MainActor
final class SesameUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitests"]
        app.launch()
    }

    // MARK: - Add account via manual entry

    func testAddAccountViaManualEntry() {
        let addButton = app.buttons["Add Account"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Expand the sheet so "Enter Manually" is visible
        sleep(1)
        app.swipeUp()

        let manualEntryButton = app.buttons["Enter Manually"]
        XCTAssertTrue(manualEntryButton.waitForExistence(timeout: 5))
        manualEntryButton.tap()

        let secretField = app.textFields["otpauth:// URI or base32 secret"]
        XCTAssertTrue(secretField.waitForExistence(timeout: 3))
        secretField.tap()
        secretField.typeText("JBSWY3DPEHPK3PXP")

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()

        let issuerField = app.textFields["Issuer"]
        XCTAssertTrue(issuerField.waitForExistence(timeout: 3))
        issuerField.tap()
        issuerField.typeText("TestIssuer")

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        // Verify a formatted code appears on the code detail screen
        let codeText = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "^[0-9]{3} [0-9]{3}$")
        ).firstMatch
        XCTAssertTrue(codeText.waitForExistence(timeout: 5))
    }

    // MARK: - Tap to copy

    func testTapToCopy() {
        let githubRow = firstAccountRow(containing: "GitHub")
        XCTAssertTrue(githubRow.waitForExistence(timeout: 5))
        githubRow.tap()
    }

    // MARK: - Profile switching

    func testProfileSwitching() {
        app.buttons["Profiles"].tap()

        let workButton = app.buttons["Work"]
        XCTAssertTrue(workButton.waitForExistence(timeout: 5))
        workButton.tap()

        let slackRow = firstAccountRow(containing: "Slack")
        XCTAssertTrue(slackRow.waitForExistence(timeout: 5))

        let githubRow = firstAccountRow(containing: "GitHub")
        XCTAssertFalse(githubRow.exists)
    }

    // MARK: - Code detail view

    func testCodeDetailView() {
        let githubRow = firstAccountRow(containing: "GitHub")
        XCTAssertTrue(githubRow.waitForExistence(timeout: 5))
        githubRow.press(forDuration: 1.0)

        let viewLargerButton = app.buttons["View Larger"]
        XCTAssertTrue(viewLargerButton.waitForExistence(timeout: 3))
        viewLargerButton.tap()

        // Verify the code detail sheet shows the account name
        let nameInSheet = app.staticTexts["simhull"]
        XCTAssertTrue(nameInSheet.waitForExistence(timeout: 5))

        // Verify the close button is present (confirms the sheet is showing)
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
    }

    // MARK: - Delete account

    func testDeleteAccount() {
        let discordRow = firstAccountRow(containing: "Discord")
        XCTAssertTrue(discordRow.waitForExistence(timeout: 5))
        discordRow.press(forDuration: 1.0)

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let confirmDelete = app.alerts["Delete Account?"].buttons["Delete"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 3))
        confirmDelete.tap()

        let discordAfter = firstAccountRow(containing: "Discord")
        XCTAssertTrue(discordAfter.waitForNonExistence(timeout: 3))
    }

    // MARK: - Helpers

    private func firstAccountRow(containing issuer: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", issuer)
        ).firstMatch
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
