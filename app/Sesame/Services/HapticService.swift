import Foundation

enum HapticService {
    static let enabledKey = UserDefaultsKey.hapticFeedbackEnabled

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) == nil
            || UserDefaults.standard.bool(forKey: enabledKey)
    }
}
