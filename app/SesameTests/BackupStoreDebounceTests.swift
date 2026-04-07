#if ICLOUD_CAPABLE
    import Foundation
    @testable import Sesame
    import SwiftData
    import Testing

    @MainActor
    struct BackupStoreDebounceTests {
        private func makeContainer() throws -> ModelContainer {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: Account.self, Profile.self, configurations: config)
        }

        @Test("rapid changes result in a single backup call")
        func debounce() async throws {
            let container = try makeContainer()
            let suiteName = "studio.samking.Sesame.DebounceTests-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.removePersistentDomain(forName: suiteName)

            let adapter = SpyAdapter()
            let backupService = BackupService(
                keychain: StubKeychain(),
                modelContext: container.mainContext,
                defaults: defaults
            )
            let manager = BackupStore(
                backupService: backupService,
                adapters: [adapter],
                defaults: defaults
            )

            // Store a password so backup can proceed
            try backupService.saveBackupPassword("test-password-1234", for: "spy")
            defer { try? backupService.clearBackupPassword(for: "spy") }

            // Enable iCloud backup
            manager.setAutoBackupEnabled(true, for: adapter)

            // Fire 5 rapid changes
            for _ in 0 ..< 5 {
                manager.scheduleAutoBackup()
            }

            // Wait for debounce (5s) + processing time
            try await Task.sleep(for: .seconds(7))

            // Only the last debounced backup should have run
            #expect(adapter.storeCallCount == 1)
        }
    }

    private final class SpyAdapter: BackupAdapter {
        let adapterKey = "spy"
        var storeCallCount = 0

        func store(blob _: Data) async throws {
            storeCallCount += 1
        }

        func retrieve() async throws -> Data {
            Data()
        }

        func lastDestinationBackupDate() async throws -> Date? {
            nil
        }

        func deleteBackup() async throws {}
    }

#endif
