import Foundation

enum UserDefaultsKey {
    static let appLockEnabled = "appLockEnabled"
    static let appLockDelay = "appLockDelay"
    static let clipboardClearDuration = "clipboardClearDuration"
    static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
    static let siriIntentsEnabled = "siriIntentsEnabled"
    static let autoFillEnabled = "autoFillEnabled"
    static let backupConfiguredPrefix = "backupConfigured."
    static let backupAutoBackupEnabledPrefix = "backupAutoBackupEnabled."
    static let backupRecoveryKeyWarningShown = "backupRecoveryKeyWarningShown"
    static let lastBackupPrefix = "lastBackup."
    static let backupFilenamePrefix = "backupFilename."
    static let liveActivityEnabled = "liveActivityEnabled"
}

enum KeychainIdentifier {
    private static let bundleId = Bundle.main.bundleIdentifier!
    static let secretsService = "\(bundleId).secrets"
    static let backupService = "\(bundleId).backup"
    static let backupPasswordAccountPrefix = "backupPassword."
}
