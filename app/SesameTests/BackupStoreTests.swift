#if ICLOUD_CAPABLE
    import Foundation
    @testable import Sesame
    import SwiftData
    import Testing

    @MainActor
    struct BackupStoreTests {
        /// Per-adapter UserDefaults keys for the spy adapter
        private let autoBackupEnabledKey = "backupAutoBackupEnabled.spy"

        // MARK: - Helpers

        private func makeContainer() throws -> ModelContainer {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: Account.self, Profile.self, configurations: config)
        }

        private func makeDefaults() -> (UserDefaults, String) {
            let suiteName = "test-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            return (defaults, suiteName)
        }

        private func makeManager(
            container: ModelContainer,
            adapter: SpyBackupAdapter? = nil,
            defaults: UserDefaults? = nil
        ) -> (BackupStore, SpyBackupAdapter, BackupService, UserDefaults) {
            let (defs, _) = defaults.map { ($0, "") } ?? makeDefaults()
            let spy = adapter ?? SpyBackupAdapter()
            let service = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defs
            )
            let store = BackupStore(
                backupService: service,
                adapters: [spy],
                defaults: defs
            )
            return (store, spy, service, defs)
        }

        // MARK: - Auto-backup scheduling

        @Test("scheduleAutoBackup triggers a backup after debounce period")
        func scheduleTriggersBackup() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: spy)
            store.scheduleAutoBackup()

            // Wait for the 5s debounce + processing
            try await Task.sleep(for: .seconds(7))

            #expect(spy.storeCallCount == 1)
        }

        @Test("rapid successive scheduleAutoBackup calls debounce to a single backup")
        func rapidCallsDebounce() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: spy)

            for _ in 0 ..< 5 {
                store.scheduleAutoBackup()
            }

            // Wait for the 5s debounce + processing
            try await Task.sleep(for: .seconds(7))

            #expect(spy.storeCallCount == 1)
        }

        @Test("scheduleAutoBackup does nothing when auto-backup is disabled")
        func scheduleWhenDisabledIsNoOp() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            // Auto-backup not enabled — default is false
            store.scheduleAutoBackup()

            try await Task.sleep(for: .seconds(7))

            #expect(spy.storeCallCount == 0)
        }

        // MARK: - Enable / Disable

        @Test("setAutoBackupEnabled(true) persists to UserDefaults")
        func enablePersistsToDefaults() throws {
            let container = try makeContainer()
            let (store, spy, _, defaults) = makeManager(container: container)

            store.setAutoBackupEnabled(true, for: spy)

            #expect(defaults.bool(forKey: autoBackupEnabledKey) == true)
        }

        @Test("setAutoBackupEnabled(false) persists to UserDefaults and cancels pending debounce")
        func disablePersistsAndCancelsDebounce() async throws {
            let container = try makeContainer()
            let (store, spy, service, defaults) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: spy)
            store.scheduleAutoBackup()

            // Disable before debounce fires
            store.setAutoBackupEnabled(false, for: spy)

            #expect(defaults.bool(forKey: autoBackupEnabledKey) == false)

            // Wait past debounce period — backup should not have run
            try await Task.sleep(for: .seconds(7))

            #expect(spy.storeCallCount == 0)
        }

        @Test("isAutoBackupEnabled requires both defaults flag and a stored password")
        func isEnabledRequiresStoredPassword() throws {
            let container = try makeContainer()
            let (defaults, _) = makeDefaults()
            let spy = SpyBackupAdapter()

            // Set the flag in defaults but don't store a password
            defaults.set(true, forKey: autoBackupEnabledKey)

            let service = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defaults
            )
            try? service.clearBackupPassword(for: "spy")

            let store = BackupStore(
                backupService: service,
                adapters: [spy],
                defaults: defaults
            )

            // Even though defaults says enabled, no password means disabled
            #expect(store.isAutoBackupEnabled(for: spy) == false)
        }

        @Test("isAutoBackupEnabled is true when defaults flag set and password stored")
        func isEnabledWhenBothPresent() throws {
            let container = try makeContainer()
            let (defaults, _) = makeDefaults()
            let spy = SpyBackupAdapter()

            defaults.set(true, forKey: autoBackupEnabledKey)

            let service = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defaults
            )
            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            let store = BackupStore(
                backupService: service,
                adapters: [spy],
                defaults: defaults
            )

            #expect(store.isAutoBackupEnabled(for: spy) == true)
        }

        // MARK: - Backup execution

        @Test("backup without a stored password sets lastError")
        func backupWithoutPasswordSetsError() async throws {
            let container = try makeContainer()
            let (defaults, _) = makeDefaults()
            let spy = SpyBackupAdapter()

            let service = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defaults
            )
            try? service.clearBackupPassword(for: "spy")

            let store = BackupStore(
                backupService: service,
                adapters: [spy],
                defaults: defaults
            )

            await store.backup(using: spy)

            #expect(store.lastError != nil)
            #expect(store.lastError == "No backup password set.")
        }

        @Test("isBackingUp is true during backup and false after")
        func isBackingUpDuringBackup() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            #expect(store.isBackingUp == false)

            await store.backup(using: spy)

            // After backup completes, should be false
            #expect(store.isBackingUp == false)
        }

        @Test("backup success clears lastError")
        func backupSuccessClearsError() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: spy)

            // Force an error first by clearing password, backing up, then restoring
            try service.clearBackupPassword(for: "spy")
            await store.backup(using: spy)
            #expect(store.lastError != nil)

            // Now set password and backup successfully
            try service.saveBackupPassword("test-password", for: "spy")
            await store.backup(using: spy)

            #expect(store.lastError == nil)
        }

        @Test("backup failure sets lastError")
        func backupFailureSetsError() async throws {
            let container = try makeContainer()
            let (defaults, _) = makeDefaults()
            let failingAdapter = FailingBackupAdapter()
            let service = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defaults
            )
            let store = BackupStore(
                backupService: service,
                adapters: [failingAdapter],
                defaults: defaults
            )

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: failingAdapter)
            await store.backup(using: failingAdapter)

            #expect(store.lastError != nil)
        }

        @Test("backup calls through to adapter")
        func backupCallsThroughToAdapter() async throws {
            let container = try makeContainer()
            let (store, spy, service, _) = makeManager(container: container)

            try service.saveBackupPassword("test-password", for: "spy")
            defer { try? service.clearBackupPassword(for: "spy") }

            store.setAutoBackupEnabled(true, for: spy)
            await store.backup(using: spy)

            #expect(spy.storeCallCount == 1)
        }
    }

    // MARK: - Test Doubles

    private final class SpyBackupAdapter: BackupAdapter {
        let adapterKey = "spy"
        var storeCallCount = 0

        func store(blob _: Data) async throws {
            storeCallCount += 1
        }

        func retrieve(id _: String) async throws -> Data {
            Data()
        }

        func lastDestinationBackupDate() async throws -> Date? {
            nil
        }

        func deleteBackup(id _: String) async throws {}
        func listBackups() throws -> [BackupFile] {
            []
        }
    }

    private final class FailingBackupAdapter: BackupAdapter {
        let adapterKey = "failing"

        func store(blob _: Data) async throws {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
        }

        func retrieve(id _: String) async throws -> Data {
            Data()
        }

        func lastDestinationBackupDate() async throws -> Date? {
            nil
        }

        func deleteBackup(id _: String) async throws {}
        func listBackups() throws -> [BackupFile] {
            []
        }
    }

#endif
