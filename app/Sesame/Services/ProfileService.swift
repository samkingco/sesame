import Foundation
import SwiftData

@MainActor
enum ProfileService {
    static func create(
        profile: Profile,
        modelContext: ModelContext,
        backupStore: BackupStore
    ) {
        modelContext.insert(profile)
        backupStore.scheduleAutoBackup()
    }

    static func update(backupStore: BackupStore) {
        // SwiftData tracks in-place mutations automatically;
        // callers mutate properties before calling this.
        backupStore.scheduleAutoBackup()
    }

    static func delete(
        profile: Profile,
        accounts: [Account],
        moveAccounts: Bool,
        keychain: KeychainServiceProtocol,
        modelContext: ModelContext,
        backupStore: BackupStore
    ) {
        if moveAccounts {
            for account in accounts {
                account.profileId = Profile.defaultID
            }
        } else {
            for account in accounts {
                do {
                    try AccountService.hardDelete(
                        account: account,
                        keychain: keychain,
                        modelContext: modelContext,
                        backupStore: backupStore
                    )
                } catch {
                    // Skip — orphaned record is recoverable, orphaned secret is not
                }
            }
        }

        modelContext.delete(profile)
        backupStore.scheduleAutoBackup()
    }
}
