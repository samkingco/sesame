import Foundation
import XCTest

/// Shared helpers for screenshot recipes.
///
/// Recipes use `--video` mode with `rate: 0` (frozen clock) so the TOTP
/// timer can be set to any position in the 30-second window via `offset`.
///
/// `demoDate` (1_000_000_020) is at a TOTP window boundary, so:
/// - offset 0 → 30s remaining (fresh)
/// - offset 5 → 25s remaining (normal)
/// - offset 22 → 8s remaining (warning, orange)
/// - offset 27 → 3s remaining (critical, red)
@MainActor
enum RecipeHelper {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SesameScreenshots/
        .deletingLastPathComponent() // app/
        .deletingLastPathComponent() // repo root

    private static let controlFile = repoRoot
        .appendingPathComponent("media/.control/.video-date")

    // MARK: - Clock control

    /// Freeze the app clock at `demoDate + offset` seconds.
    static func setClockOffset(_ offset: Double) {
        writeDate(offset: offset, rate: 0)
    }

    static func cleanupClockControl() {
        try? FileManager.default.removeItem(at: controlFile)
    }

    private static func writeDate(offset: Double, rate: Double) {
        let json = "{\"offset\":\(offset),\"rate\":\(rate)}"
        let dir = controlFile.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try! json.data(using: .utf8)!.write(to: controlFile, options: .atomic)
    }

    // MARK: - Screenshot

    static func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let outputDir = repoRoot.appendingPathComponent("media/recipes")
        try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let path = outputDir.appendingPathComponent("\(name).png")
        try! screenshot.pngRepresentation.write(to: path, options: .atomic)
    }

    // MARK: - Navigation

    static func switchProfile(_ name: String, app: XCUIApplication) {
        let profileButton = app.buttons["Profiles"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()
        let target = app.buttons[name]
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        target.tap()
        usleep(500_000)
    }

    static func openEnlargedCode(issuer: String, app: XCUIApplication) {
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", issuer)
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.0)

        let viewLarger = app.buttons["View Larger"]
        XCTAssertTrue(viewLarger.waitForExistence(timeout: 3))
        viewLarger.tap()
        usleep(500_000)
    }

    static func dismissSheet(app: XCUIApplication) {
        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
            usleep(500_000)
        }
    }

    static func openSettings(app: XCUIApplication) {
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        usleep(500_000)
    }

    static func openRestoreBackup(app: XCUIApplication) {
        openSettings(app: app)
        let restoreButton = app.buttons["Restore Backup"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 3))
        restoreButton.tap()
        usleep(500_000)
    }

}
