import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .dark
        app = XCUIApplication()
        app.launchArguments = ["--screenshots"]
        app.launch()
    }

    func testScreenshots() {
        // 01 — Personal account list (lands here on launch)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        saveScreenshot("01-PersonalList")

        // 02 — Profile switcher
        let profileButton = app.buttons["Profiles"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()
        saveScreenshot("02-ProfileSwitcher")

        // Dismiss profile menu by re-selecting Personal
        let personalButton = app.buttons["Personal"]
        XCTAssertTrue(personalButton.waitForExistence(timeout: 3))
        personalButton.tap()
        sleep(1)

        // 03 — Copy toast on account list
        let githubText = app.staticTexts["GitHub"]
        XCTAssertTrue(githubText.waitForExistence(timeout: 3))
        githubText.tap()
        usleep(500_000)
        saveScreenshot("03-CopyToast")

        // 04 — Add account (switch to Studio first)
        sleep(1)
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()
        let studioButton = app.buttons["Studio"]
        XCTAssertTrue(studioButton.waitForExistence(timeout: 3))
        studioButton.tap()
        sleep(1)

        let addButton = app.buttons["Add Account"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        sleep(1)
        saveScreenshot("04-AddAccount")

        // Dismiss add account sheet
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)

        // 05 — Manage profiles
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()
        let manageButton = app.buttons["Manage Profiles"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()
        sleep(1)
        saveScreenshot("05-ManageProfiles")

        // Dismiss manage profiles
        app.navigationBars["Manage Profiles"].buttons["Close"].tap()
        sleep(1)

        // Settings runs before search to avoid search cancel issues,
        // but numbered to match the intended display order.

        // 07 — Settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        sleep(1)
        saveScreenshot("07-Settings")

        // Dismiss settings
        app.navigationBars["Settings"].buttons["Close"].tap()
        sleep(1)

        // 06 — Search (cross-profile, still on Studio)
        list.swipeDown()
        let searchField = app.searchFields["Search accounts"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("re")
        sleep(1)
        saveScreenshot("06-Search")
    }
}
