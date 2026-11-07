import Foundation
import XCTest

@MainActor
func saveScreenshot(_ name: String) {
    let window = XCUIApplication().windows.firstMatch.frame.size
    guard window.width > 0, window.height > 0 else {
        XCTFail("No app window to size the screenshot \(name)")
        return
    }
    let image = appScreenImage(window: window)
    let scale = (image.size.width * image.scale / window.width).rounded()
    let pixelSize = CGSize(width: window.width * scale, height: window.height * scale)
    let pixelHeight = Int(pixelSize.height)

    // Map pixel height to Apple's marketing screen size
    let screenSize = switch pixelHeight {
    case 2868: "6.9"
    case 2622: "6.3"
    case 2532: "6.1"
    case 2007, 2853: "duo-inner"
    case 1398, 2034: "duo-outer"
    default: "\(pixelHeight)"
    }

    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SesameScreenshots/
        .deletingLastPathComponent() // app/
        .deletingLastPathComponent() // repo root
    let outputDir = repoRoot.appendingPathComponent("media/appstore")

    try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    let path = outputDir.appendingPathComponent("\(screenSize)-\(name).png")
    try! opaquePNG(image, pixelSize: pixelSize).write(to: path, options: .atomic)
}

/// iPhone Duo has two screens, and `XCUIScreen.main` is the outer one, which is
/// off when the device is open. Capture the screen that shows the app: its pixels
/// match the app window at a whole-number scale. On devices with one screen, this
/// is the same as `XCUIScreen.main`.
@MainActor
private func appScreenImage(window: CGSize) -> UIImage {
    XCUIScreen.screens
        .map { $0.screenshot().image }
        .min { scaleMismatch($0, window: window) < scaleMismatch($1, window: window) }
        ?? XCUIScreen.main.screenshot().image
}

private func scaleMismatch(_ image: UIImage, window: CGSize) -> CGFloat {
    let scaleX = image.size.width * image.scale / window.width
    let scaleY = image.size.height * image.scale / window.height
    return abs(scaleX - scaleY) + abs(scaleX - scaleX.rounded())
}

/// Draws the capture at the exact pixel size App Store Connect expects, with the
/// orientation in the pixels and no alpha. The Duo inner capture is 1 px short on
/// each side and stores portrait pixels with an orientation tag.
private func opaquePNG(_ image: UIImage, pixelSize: CGSize) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    return UIGraphicsImageRenderer(size: pixelSize, format: format).pngData { _ in
        image.draw(in: CGRect(origin: .zero, size: pixelSize))
    }
}
