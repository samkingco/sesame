import Foundation
import os

@MainActor @Observable
final class BackupStore {
    let backupService: BackupService
    private(set) var isBackingUp = false
    private(set) var lastError: String?

    private var adapters: [BackupAdapter]
    private let defaults: UserDefaults
    private var debounceTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "BackupStore"
    )

    private static let configuredPrefix = UserDefaultsKey.backupConfiguredPrefix
    private static let autoBackupEnabledPrefix = UserDefaultsKey.backupAutoBackupEnabledPrefix
    private static let filenamePrefix = UserDefaultsKey.backupFilenamePrefix
    static let recoveryKeyWarningShownKey = UserDefaultsKey.backupRecoveryKeyWarningShown

    var recoveryKeyWarningShown: Bool {
        get { defaults.bool(forKey: Self.recoveryKeyWarningShownKey) }
        set { defaults.set(newValue, forKey: Self.recoveryKeyWarningShownKey) }
    }

    init(
        backupService: BackupService,
        adapters: [BackupAdapter] = [],
        defaults: UserDefaults = .standard
    ) {
        self.backupService = backupService
        self.adapters = adapters
        self.defaults = defaults
    }

    func adapter(for key: String) -> BackupAdapter? {
        adapters.first { $0.adapterKey == key }
    }

    #if ICLOUD_CAPABLE
        func resolveICloudAdapter() async {
            guard adapter(for: "icloud") == nil else { return }

            var containerURL = await ICloudBackupAdapter.resolveContainerURL()

            #if DEMO_ENABLED
                if containerURL == nil, LaunchMode.isDemoData {
                    containerURL = FileManager.default.temporaryDirectory
                        .appending(path: "icloud-demo")
                }
            #endif

            guard let containerURL else {
                logger.info("iCloud container unavailable")
                return
            }

            adapters.append(ICloudBackupAdapter(containerURL: containerURL))
            logger.info("iCloud adapter resolved")
        }
    #endif

    // MARK: - Per-adapter state

    func isConfigured(for adapter: BackupAdapter) -> Bool {
        defaults.bool(forKey: Self.configuredPrefix + adapter.adapterKey)
    }

    func isAutoBackupEnabled(for adapter: BackupAdapter) -> Bool {
        defaults.bool(forKey: Self.autoBackupEnabledPrefix + adapter.adapterKey)
            && backupService.storedBackupPassword(for: adapter.adapterKey) != nil
    }

    func lastDeviceBackupDate(for adapter: BackupAdapter) -> Date? {
        backupService.lastDeviceBackupDate(for: adapter.adapterKey)
    }

    func backupFilename(for adapter: BackupAdapter) -> String? {
        defaults.string(forKey: Self.filenamePrefix + adapter.adapterKey)
    }

    func setAutoBackupEnabled(_ enabled: Bool, for adapter: BackupAdapter) {
        let enabledKey = Self.autoBackupEnabledPrefix + adapter.adapterKey
        let configuredKey = Self.configuredPrefix + adapter.adapterKey

        defaults.set(enabled, forKey: enabledKey)
        if enabled {
            defaults.set(true, forKey: configuredKey)
            ensureBackupFilename(for: adapter)
        } else {
            debounceTask?.cancel()
            debounceTask = nil
        }
    }

    #if ICLOUD_CAPABLE
        private func ensureBackupFilename(for adapter: BackupAdapter) {
            let key = Self.filenamePrefix + adapter.adapterKey
            guard defaults.string(forKey: key) == nil else { return }
            let filename = ICloudBackupAdapter.generateBackupFilename()
            defaults.set(filename, forKey: key)
        }
    #else
        private func ensureBackupFilename(for _: BackupAdapter) {}
    #endif

    // MARK: - Backup

    func backup(using adapter: BackupAdapter) async {
        guard let password = backupService.storedBackupPassword(for: adapter.adapterKey) else {
            lastError = "No backup password set."
            return
        }

        isBackingUp = true
        lastError = nil

        do {
            try await backupService.backup(using: adapter, password: password)
            logger.info("Backup completed for \(adapter.adapterKey)")
        } catch {
            lastError = error.localizedDescription
            logger.error("Backup failed for \(adapter.adapterKey): \(error.localizedDescription)")
        }

        isBackingUp = false
    }

    // MARK: - Removal

    func removeBackup(for adapter: BackupAdapter) async {
        debounceTask?.cancel()
        debounceTask = nil

        do {
            try await adapter.deleteBackup()
            logger.info("Backup file deleted for \(adapter.adapterKey)")
        } catch {
            logger.error("Failed to delete backup for \(adapter.adapterKey): \(error.localizedDescription)")
        }

        try? backupService.clearBackupPassword(for: adapter.adapterKey)

        let enabledKey = Self.autoBackupEnabledPrefix + adapter.adapterKey
        let configuredKey = Self.configuredPrefix + adapter.adapterKey
        let filenameKey = Self.filenamePrefix + adapter.adapterKey
        defaults.set(false, forKey: enabledKey)
        defaults.set(false, forKey: configuredKey)
        defaults.removeObject(forKey: filenameKey)
    }

    // MARK: - Auto-backup

    func scheduleAutoBackup() {
        let enabledAdapters = adapters.filter { isAutoBackupEnabled(for: $0) }
        guard !enabledAdapters.isEmpty else { return }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            for adapter in enabledAdapters {
                await backup(using: adapter)
            }
        }
    }
}
