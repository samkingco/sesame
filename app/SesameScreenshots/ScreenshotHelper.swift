import Foundation
import XCTest

@MainActor
func saveScreenshot(_ name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let image = screenshot.image
    let pixelHeight = Int(image.size.height * image.scale)

    // Map pixel height to Apple's marketing screen size
    let screenSize: String
    switch pixelHeight {
    case 2868: screenSize = "6.9"
    case 2622: screenSize = "6.3"
    case 2532: screenSize = "6.1"
    default: screenSize = "\(pixelHeight)"
    }

    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SesameScreenshots/
        .deletingLastPathComponent() // app/
        .deletingLastPathComponent() // repo root
    let outputDir = repoRoot.appendingPathComponent("media/appstore")

    try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    let path = outputDir.appendingPathComponent("\(screenSize)-\(name).png")
    try! screenshot.pngRepresentation.write(to: path, options: .atomic)
}
