import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct SoftDeleteTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    private func makeAccount(
        issuer: String = "GitHub",
        name: String = "user@github.com",
        deletedAt: Date? = nil
    ) -> Account {
        Account(
            profileId: Profile.defaultID,
            issuer: issuer,
            name: name,
            deletedAt: deletedAt
        )
    }

    // MARK: - Soft delete

    @Test("Soft delete sets deletedAt without removing from SwiftData")
    func softDeleteKeepsInStore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount()
        context.insert(account)
        try context.save()

        account.deletedAt = .now
        try context.save()

        let all = try context.fetch(FetchDescriptor<Account>())
        #expect(all.count == 1)
        #expect(all[0].deletedAt != nil)
    }

    @Test("Soft-deleted accounts excluded from active query")
    func softDeletedExcludedFromActiveQuery() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let active = makeAccount(issuer: "Active")
        let deleted = makeAccount(issuer: "Deleted", deletedAt: .now)
        context.insert(active)
        context.insert(deleted)
        try context.save()

        let activePredicate = #Predicate<Account> { $0.deletedAt == nil }
        let descriptor = FetchDescriptor<Account>(predicate: activePredicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].issuer == "Active")
    }

    @Test("Soft-deleted accounts appear in deleted query")
    func softDeletedInDeletedQuery() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let active = makeAccount(issuer: "Active")
        let deleted = makeAccount(issuer: "Deleted", deletedAt: .now)
        context.insert(active)
        context.insert(deleted)
        try context.save()

        let deletedPredicate = #Predicate<Account> { $0.deletedAt != nil }
        let descriptor = FetchDescriptor<Account>(predicate: deletedPredicate)
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        #expect(results[0].issuer == "Deleted")
    }

    // MARK: - Restore

    @Test("Restore clears deletedAt")
    func restoreClearsDeletedAt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(deletedAt: .now)
        context.insert(account)
        try context.save()

        account.deletedAt = nil
        try context.save()

        let all = try context.fetch(FetchDescriptor<Account>())
        #expect(all.count == 1)
        #expect(all[0].deletedAt == nil)
    }

    // MARK: - Purge

    @Test("Purge deletes only accounts past 48h")
    func purgeDeletesExpired() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let expired = makeAccount(
            issuer: "Expired",
            deletedAt: Date.now.addingTimeInterval(-49 * 3600)
        )
        let recent = makeAccount(
            issuer: "Recent",
            deletedAt: Date.now.addingTimeInterval(-1 * 3600)
        )
        let active = makeAccount(issuer: "Active")

        context.insert(expired)
        context.insert(recent)
        context.insert(active)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 2)
        #expect(remaining.contains(where: { $0.issuer == "Recent" }))
        #expect(remaining.contains(where: { $0.issuer == "Active" }))
        #expect(keychain.deletedIds.contains(expired.id))
        #expect(!keychain.deletedIds.contains(recent.id))
    }

    @Test("Purge leaves accounts under 48h untouched")
    func purgeLeavesRecentUntouched() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let recent = makeAccount(
            issuer: "Recent",
            deletedAt: Date.now.addingTimeInterval(-12 * 3600)
        )
        context.insert(recent)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(keychain.deletedIds.isEmpty)
    }

    @Test("Permanent delete removes from both SwiftData and Keychain")
    func permanentDeleteRemovesBoth() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let account = makeAccount(deletedAt: .now)
        context.insert(account)
        try context.save()

        try keychain.delete(for: account.id)
        context.delete(account)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.isEmpty)
        #expect(keychain.deletedIds.contains(account.id))
    }

    @Test("Newly added accounts have deletedAt == nil")
    func newAccountHasNilDeletedAt() {
        let account = makeAccount()
        #expect(account.deletedAt == nil)
    }
}
