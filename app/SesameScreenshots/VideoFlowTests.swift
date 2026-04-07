import XCTest

@MainActor
final class VideoFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var recordStart: TimeInterval = 0

    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SesameScreenshots/
        .deletingLastPathComponent() // app/
        .deletingLastPathComponent() // repo root
    private static let controlDir = projectRoot.appendingPathComponent("media/.control")
    private static let controlFile = controlDir.appendingPathComponent(".video-date")
    private static let timingFile = controlDir.appendingPathComponent(".timing")
    private static let recordStartFile = controlDir.appendingPathComponent(".record-start")

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .dark
        app = XCUIApplication()
        app.launchArguments = ["--video"]

        // Read the shell's recording start timestamp so all timing is relative to it
        recordStart = readRecordStart()

        writeDate(offset: 0, rate: 0.001)
        app.launch()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: Self.controlFile)
    }

    func testMainFlow() {
        let github = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'GitHub'")
        ).firstMatch
        XCTAssertTrue(github.waitForExistence(timeout: 10))

        // Mark the start of useful content (after app launch is complete)
        let startOffset = Date().timeIntervalSince1970 - recordStart

        // Small buffer so the first frame isn't mid-transition
        sleep(1)

        // 1. Personal (frozen) — hold 2s, tap GitHub, hold 2.5s
        sleep(2)
        github.tap()
        usleep(2_500_000)

        // 2. Switch to Work, start ticking
        tapProfileMenu("Work")
        writeDate(offset: 19, rate: 1)

        // 3. Hold 2s on Work
        sleep(2)

        // 4. Manage Profiles -> change color
        tapProfileMenu("Manage Profiles")
        usleep(400_000)
        app.collectionViews.buttons["Work"].tap()
        usleep(500_000)
        app.buttons["Teal"].tap()
        usleep(500_000)
        app.navigationBars.buttons["Save"].tap()

        // 5. Close Manage Profiles
        usleep(500_000)
        app.navigationBars.buttons["Close"].tap()

        // 6. Hold to see updated codes
        sleep(1)

        // 7. Settings -> clipboard 30s -> 1 minute
        app.buttons["Settings"].tap()
        usleep(400_000)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Clear Clipboard'")).firstMatch.tap()
        app.buttons["1 minute"].tap()
        app.navigationBars.buttons["Close"].tap()

        // 8. Switch to Personal (frozen) — hold briefly for loop point
        tapProfileMenu("Personal")
        writeDate(offset: 0, rate: 0.001)
        sleep(2)

        // Mark end of useful content, add buffer for trim safety
        let endOffset = Date().timeIntervalSince1970 - recordStart
        writeTiming(start: startOffset, end: endOffset)
        sleep(3)
    }

    // MARK: - Helpers

    private func tapProfileMenu(_ label: String) {
        app.buttons["Profiles"].tap()
        app.buttons[label].tap()
    }

    private func readRecordStart() -> TimeInterval {
        // Poll briefly — the shell writes this file right after recording starts
        for _ in 0 ..< 100 {
            if let data = try? Data(contentsOf: Self.recordStartFile),
               let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let ts = Double(str)
            {
                return ts
            }
            usleep(50000)
        }
        // Fallback: use current time (offsets will be ~0-based)
        return Date().timeIntervalSince1970
    }

    private func writeDate(offset: Double, rate: Double) {
        let json = "{\"offset\":\(offset),\"rate\":\(rate)}"
        let dir = Self.controlFile.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try! json.data(using: .utf8)!.write(to: Self.controlFile, options: .atomic)
    }

    private func writeTiming(start: Double, end: Double) {
        let dir = Self.timingFile.deletingLastPathComponent()
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = "{\"start\":\(start),\"end\":\(end)}"
        try! json.data(using: .utf8)!.write(to: Self.timingFile, options: .atomic)
    }
}
