import XCTest

/// Screenshot recipes — each test captures a specific screen in a specific state.
///
/// Run all: `./scripts/recipe.sh --all`
/// Run one: `./scripts/recipe.sh enlarged-code-fresh`
///
/// Uses `--video` mode with frozen clock for precise TOTP timer control.
/// See `RecipeHelper` for offset → remaining-seconds mapping.
@MainActor
final class RecipeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .dark
        app = XCUIApplication()
        app.launchArguments = ["--video"]
    }

    override func tearDownWithError() throws {
        RecipeHelper.cleanupClockControl()
    }

    private func launchApp() {
        RecipeHelper.setClockOffset(0)
        app.launch()
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
    }

    // MARK: - Enlarged code

    func testEnlargedCodeFresh() {
        launchApp()
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-fresh")
    }

    func testEnlargedCodeWarning() {
        launchApp()
        RecipeHelper.setClockOffset(22)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-warning")
    }

    func testEnlargedCodeCritical() {
        launchApp()
        RecipeHelper.setClockOffset(27)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-critical")
    }

    // MARK: - Account list

    func testAccountListPersonal() {
        launchApp()
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.saveScreenshot("account-list-personal")
    }

    func testAccountListStudio() {
        launchApp()
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.switchProfile("Studio", app: app)
        RecipeHelper.saveScreenshot("account-list-studio")
    }

    // MARK: - Restore: iCloud

    func testRestoreIcloudLoading() {
        app.launchEnvironment["SEED_ICLOUD_BACKUPS"] = "3"
        app.launchEnvironment["DEMO_ICLOUD_DELAY"] = "30"
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)
        sleep(1)
        RecipeHelper.saveScreenshot("restore-icloud-loading")
    }

    func testRestoreIcloudEmpty() {
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)
        sleep(1)
        RecipeHelper.saveScreenshot("restore-icloud-empty")
    }

    func testRestoreIcloudSingle() {
        app.launchEnvironment["SEED_ICLOUD_BACKUPS"] = "1"
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)

        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'sams-iphone'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(1)

        RecipeHelper.saveScreenshot("restore-icloud-single")
    }

    func testRestoreIcloudMultiple() {
        app.launchEnvironment["SEED_ICLOUD_BACKUPS"] = "3"
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)

        let firstRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'sams-iphone'")
        ).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.tap()
        sleep(1)

        RecipeHelper.saveScreenshot("restore-icloud-multiple")
    }

    // MARK: - Restore: file

    func testRestoreFileUnselected() {
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)
        RecipeHelper.saveScreenshot("restore-file-unselected")
    }

    func testRestoreFileSelected() {
        app.launchEnvironment["DEMO_RESTORE_FILE"] = "2026-04-01.backup.sesame"
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)
        sleep(1)
        RecipeHelper.saveScreenshot("restore-file-selected")
    }

    func testRestoreWrongPassword() {
        app.launchEnvironment["DEMO_RESTORE_FILE"] = "2026-04-01.backup.sesame"
        launchApp()
        RecipeHelper.openRestoreBackup(app: app)
        sleep(1)

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText("wrong-password")

        let unlockButton = app.buttons["Unlock"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 3))
        unlockButton.tap()
        sleep(2)

        RecipeHelper.saveScreenshot("restore-wrong-password")
    }
}
