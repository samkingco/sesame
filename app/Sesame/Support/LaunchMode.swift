import Foundation

/// Controls how the app behaves in non-production contexts.
///
/// **Demo mode** (`--screenshots` / `--video` launch arguments): seeds fake
/// accounts and profiles for App Store screenshots and marketing video recording.
/// Codes are either frozen (screenshots) or driven by an external date file (video).
///
/// Demo mode is fully isolated from real user data: SwiftData uses an in-memory
/// store (`SharedModelContainer`), secrets go to an `InMemoryKeychainService`
/// stub (`DemoData.swift`), and nothing touches the real keychain or persistent
/// database. These launch arguments are only passed by automation scripts —
/// normal app launches and App Store builds never hit these paths.
///
/// You'll see `LaunchMode.isDemoData` and `LaunchMode.demo` checks in production
/// views — they're safe no-ops during normal usage because `demo` is always nil.
///
/// **Simulator**: the iOS Simulator cannot access iCloud containers or perform
/// real biometric authentication. These are stubbed so the full UI is testable
/// during development. None of this code ships in release builds on device.
enum LaunchMode {
    #if DEMO_ENABLED
        /// Demo modes for marketing assets and UI testing.
        enum Demo {
            /// App Store screenshots — all codes frozen at a fixed date.
            case screenshots
            /// Marketing video — codes driven by an external date file.
            case video
            /// UI tests — virtual clock from demoDate, no app lock.
            case uiTests
        }

        /// Which demo mode is active, if any. Nil during normal app usage.
        static let demo: Demo? = {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--uitests") { return .uiTests }
            if args.contains("--screenshots") { return .screenshots }
            if args.contains("--video") { return .video }
            return nil
        }()

        /// True when running in either demo mode.
        static var isDemoData: Bool {
            demo != nil
        }

        /// Fixed date at the start of a TOTP window so codes always appear fresh.
        static let demoDate = Date(timeIntervalSince1970: 1_000_000_020)
    #endif

    /// True when running in the iOS Simulator (compile-time check).
    /// Used to stub iCloud availability and biometric auth for development.
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
}
