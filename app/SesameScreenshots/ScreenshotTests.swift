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
        let usesSidebar = hasProfileSidebar()
        saveScreenshot("01-PersonalList")

        // 02 — Profile switcher. With a sidebar, 01 already shows the profiles.
        if !usesSidebar {
            let profileButton = app.buttons["Profiles"]
            XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
            profileButton.tap()
            saveScreenshot("02-ProfileSwitcher")

            // Dismiss profile menu by re-selecting Personal
            let personalButton = app.buttons["Personal"]
            XCTAssertTrue(personalButton.waitForExistence(timeout: 3))
            personalButton.tap()
            sleep(1)
        }

        // 03 — Copy toast on account list
        let githubText = app.staticTexts["GitHub"]
        XCTAssertTrue(githubText.waitForExistence(timeout: 3))
        githubText.tap()
        usleep(500_000)
        saveScreenshot("03-CopyToast")

        // 04 — Add account (switch to Studio first)
        sleep(1)
        selectProfile("Studio", usesSidebar: usesSidebar)
        sleep(1)

        let addButton = app.buttons["Add Account"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()
        sleep(1)
        saveScreenshot("04-AddAccount")

        // Dismiss add account sheet
        closeSheet()

        // 05 — Manage profiles
        if !usesSidebar {
            let profileButton = app.buttons["Profiles"]
            XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
            profileButton.tap()
        }
        let manageButton = app.buttons["Manage Profiles"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()
        sleep(1)
        saveScreenshot("05-ManageProfiles")

        // Dismiss manage profiles
        closeSheet()

        // Settings runs before search to avoid search cancel issues,
        // but numbered to match the intended display order.

        // 07 — Settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        sleep(1)
        saveScreenshot("07-Settings")

        // Dismiss settings
        closeSheet()

        // 06 — Search (cross-profile, still on Studio)
        // iPad shows the search field in the toolbar. iPhone Duo has a Search
        // button in its side toolbar. Other iPhones hide the field above the list.
        let searchField = app.searchFields["Search accounts"]
        if !(searchField.exists && searchField.isHittable) {
            let searchButton = app.buttons["Search"]
            if searchButton.exists {
                searchButton.tap()
            } else {
                list.swipeDown()
            }
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("re")
        sleep(1)
        saveScreenshot("06-Search")
    }

    // MARK: - Sheets

    /// On the closed iPhone Duo, the sheet's Close button is not inside its
    /// navigation bar element, so find it from the app.
    private func closeSheet() {
        let closeButton = app.buttons["Close"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()
        sleep(1)
    }

    // MARK: - Profiles

    /// Regular width (open iPhone Duo, iPad) lists profiles in a sidebar.
    /// Compact width puts them in the Profiles menu in the toolbar.
    private func hasProfileSidebar() -> Bool {
        app.buttons["Manage Profiles"].waitForExistence(timeout: 2)
    }

    private func selectProfile(_ name: String, usesSidebar: Bool) {
        if usesSidebar {
            let row = app.staticTexts[name]
            XCTAssertTrue(row.waitForExistence(timeout: 3))
            row.tap()
        } else {
            let profileButton = app.buttons["Profiles"]
            XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
            profileButton.tap()
            let target = app.buttons[name]
            XCTAssertTrue(target.waitForExistence(timeout: 3))
            target.tap()
        }
    }
}
