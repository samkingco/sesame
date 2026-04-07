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

        // Freeze clock at demoDate (window boundary, 30s remaining)
        RecipeHelper.setClockOffset(0)
        app.launch()

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
    }

    override func tearDownWithError() throws {
        RecipeHelper.cleanupClockControl()
    }

    // MARK: - Enlarged code: timer states

    func testEnlargedCodeFresh() {
        // 5s into window → 25s remaining (normal/white)
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-fresh")
    }

    func testEnlargedCodeWarning() {
        // 22s into window → 8s remaining (orange)
        RecipeHelper.setClockOffset(22)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-warning")
    }

    func testEnlargedCodeCritical() {
        // 27s into window → 3s remaining (red)
        RecipeHelper.setClockOffset(27)
        sleep(2)
        RecipeHelper.openEnlargedCode(issuer: "GitHub", app: app)
        RecipeHelper.saveScreenshot("enlarged-code-critical")
    }

    // MARK: - Account list

    func testAccountListPersonal() {
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.saveScreenshot("account-list-personal")
    }

    func testAccountListStudio() {
        RecipeHelper.setClockOffset(5)
        sleep(2)
        RecipeHelper.switchProfile("Studio", app: app)
        RecipeHelper.saveScreenshot("account-list-studio")
    }
}
