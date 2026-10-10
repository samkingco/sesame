import UIKit
import UniformTypeIdentifiers

enum ClipboardService {
    static let clearDurationKey = UserDefaultsKey.clipboardClearDuration

    enum ClearDuration: Int, CaseIterable, Identifiable {
        case never = 0
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300

        static let `default`: ClearDuration = .thirtySeconds

        var id: Int {
            rawValue
        }

        var label: String {
            switch self {
            case .never: "Never"
            case .thirtySeconds: "30 seconds"
            case .oneMinute: "1 minute"
            case .fiveMinutes: "5 minutes"
            }
        }
    }

    static var clearDuration: Int {
        UserDefaults.standard.object(forKey: clearDurationKey) == nil
            ? ClearDuration.default.rawValue
            : UserDefaults.standard.integer(forKey: clearDurationKey)
    }

    /// Returns when the clipboard will be cleared, or nil if it won't be.
    @discardableResult
    static func copy(_ string: String) -> Date? {
        let duration = clearDuration
        guard duration > 0 else {
            UIPasteboard.general.string = string
            return nil
        }
        let clearsAt = Date.now.addingTimeInterval(Double(duration))
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: string]],
            options: [.expirationDate: clearsAt]
        )
        return clearsAt
    }
}
