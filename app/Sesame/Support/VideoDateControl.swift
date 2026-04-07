import Foundation

#if DEMO_ENABLED

    /// Controls the display date during video recording via an external file.
    ///
    /// The XCUITest writes a JSON control file, the app reads it on each timer tick.
    /// This allows the test to freeze codes on one profile and tick them on another.
    ///
    /// Control file format:
    /// ```json
    /// {"offset": 19, "rate": 1}
    /// ```
    /// - `offset`: seconds to add to `LaunchMode.demoDate`
    /// - `rate`: 0 = frozen at offset, 1 = ticking forward from offset
    final class VideoDateControl {
        static let shared = VideoDateControl()

        private let controlFile: URL
        private var currentOffset: TimeInterval = 0
        private var currentRate: Double = 0
        private var tickStartDate: Date?
        private var lastModDate: Date?

        private init() {
            let projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Support/
                .deletingLastPathComponent() // Sesame/
                .deletingLastPathComponent() // project root
            controlFile = projectRoot.appendingPathComponent("videos/.video-date")
        }

        var currentDate: Date {
            reload()
            if currentRate > 0, let start = tickStartDate {
                let elapsed = Date.now.timeIntervalSince(start) * currentRate
                return LaunchMode.demoDate.addingTimeInterval(currentOffset + elapsed)
            }
            return LaunchMode.demoDate.addingTimeInterval(currentOffset)
        }

        private func reload() {
            // Only re-read the file if it has been modified
            let modDate = try? FileManager.default.attributesOfItem(
                atPath: controlFile.path
            )[.modificationDate] as? Date

            guard modDate != lastModDate else { return }

            guard let data = try? Data(contentsOf: controlFile),
                  let config = try? JSONDecoder().decode(Config.self, from: data) else { return }

            lastModDate = modDate

            let changed = config.offset != currentOffset || config.rate != currentRate
            if changed {
                currentOffset = config.offset
                currentRate = config.rate
                tickStartDate = config.rate > 0 ? Date.now : nil
            }
        }

        private struct Config: Codable {
            let offset: TimeInterval
            let rate: Double
        }
    }

#endif
