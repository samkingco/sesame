import Foundation
import SwiftData

@MainActor
enum AccountService {
    /// Insert a new account into SwiftData, save the secret to keychain,
    /// then schedule a backup and sync AutoFill.
    static func create(
        account: Account,
        secret: String,
        keychain: KeychainServiceProtocol,
        modelContext: ModelContext,
        backupStore: BackupStore
    ) throws {
        try keychain.save(secret: secret, for: account.id)
        modelContext.insert(account)
        afterMutation(backupStore: backupStore)
    }

    /// Persist in-place changes to an existing account,
    /// then schedule a backup and sync AutoFill.
    static func update(
        account _: Account,
        modelContext _: ModelContext,
        backupStore: BackupStore
    ) {
        // SwiftData tracks in-place mutations automatically;
        // callers mutate properties before calling this.
        afterMutation(backupStore: backupStore)
    }

    /// Soft-delete an account by setting `deletedAt`,
    /// then schedule a backup and sync AutoFill.
    static func softDelete(
        account: Account,
        modelContext _: ModelContext,
        backupStore: BackupStore
    ) {
        account.deletedAt = .now
        afterMutation(backupStore: backupStore)
    }

    /// Restore a soft-deleted account by clearing `deletedAt`,
    /// then schedule a backup and sync AutoFill.
    static func restore(
        account: Account,
        backupStore: BackupStore
    ) {
        account.deletedAt = nil
        afterMutation(backupStore: backupStore)
    }

    /// Permanently delete an account and its keychain secret,
    /// then schedule a backup and sync AutoFill.
    static func hardDelete(
        account: Account,
        keychain: KeychainServiceProtocol,
        modelContext: ModelContext,
        backupStore: BackupStore
    ) throws {
        try keychain.delete(for: account.id)
        modelContext.delete(account)
        afterMutation(backupStore: backupStore)
    }

    /// Shared fetch descriptor for active (non-deleted) accounts, sorted by creation date.
    static func fetchActive(modelContext: ModelContext) throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\Account.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Private

    private static func afterMutation(backupStore: BackupStore) {
        backupStore.scheduleAutoBackup()
        #if AUTOFILL_CAPABLE
            if AutoFillService.isEnabled {
                Task { await AutoFillService.syncIdentityStore() }
            }
        #endif
    }
}
