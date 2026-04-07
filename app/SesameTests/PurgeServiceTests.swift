import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct PurgeServiceTests {
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

    // MARK: - Grace period

    @Test("Accounts deleted < 48h ago are NOT purged")
    func recentlyDeletedAccountSurvives() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let account = makeAccount(
            issuer: "Recent",
            deletedAt: Date.now.addingTimeInterval(-47 * 3600)
        )
        context.insert(account)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(remaining[0].issuer == "Recent")
        #expect(keychain.deletedIds.isEmpty)
    }

    @Test("Accounts deleted >= 48h ago ARE purged")
    func expiredAccountIsPurged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let account = makeAccount(
            issuer: "Expired",
            deletedAt: Date.now.addingTimeInterval(-49 * 3600)
        )
        context.insert(account)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.isEmpty)
        #expect(keychain.deletedIds.contains(account.id))
    }

    @Test("Active accounts (deletedAt == nil) are NOT purged")
    func activeAccountSurvives() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let account = makeAccount(issuer: "Active")
        context.insert(account)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(remaining[0].issuer == "Active")
        #expect(keychain.deletedIds.isEmpty)
    }

    // MARK: - Purge behaviour

    @Test("Purged account's keychain secret is deleted")
    func purgeDeletesKeychainSecret() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let account = makeAccount(
            issuer: "Expired",
            deletedAt: Date.now.addingTimeInterval(-49 * 3600)
        )
        context.insert(account)
        try context.save()
        let accountId = account.id

        PurgeService.purgeExpired(context: context, keychain: keychain)

        #expect(keychain.deletedIds == [accountId])
    }

    @Test("Multiple expired accounts all purged in one pass")
    func multipleExpiredAccountsPurged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let a = makeAccount(
            issuer: "A",
            deletedAt: Date.now.addingTimeInterval(-50 * 3600)
        )
        let b = makeAccount(
            issuer: "B",
            deletedAt: Date.now.addingTimeInterval(-72 * 3600)
        )
        let active = makeAccount(issuer: "Active")

        context.insert(a)
        context.insert(b)
        context.insert(active)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(remaining[0].issuer == "Active")
        #expect(keychain.deletedIds.contains(a.id))
        #expect(keychain.deletedIds.contains(b.id))
    }

    // MARK: - Error handling

    @Test("Keychain delete failure: account NOT removed from SwiftData")
    func keychainFailurePreservesAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = FailingKeychain()

        let account = makeAccount(
            issuer: "Expired",
            deletedAt: Date.now.addingTimeInterval(-49 * 3600)
        )
        context.insert(account)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(remaining[0].issuer == "Expired")
    }

    @Test("No expired accounts: completes without error")
    func noExpiredAccountsCompletesCleanly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        let recent = makeAccount(
            issuer: "Recent",
            deletedAt: Date.now.addingTimeInterval(-1 * 3600)
        )
        context.insert(recent)
        try context.save()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.count == 1)
        #expect(keychain.deletedIds.isEmpty)
    }

    @Test("Empty database: completes without error")
    func emptyDatabaseCompletesCleanly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = SpyKeychain()

        PurgeService.purgeExpired(context: context, keychain: keychain)

        let remaining = try context.fetch(FetchDescriptor<Account>())
        #expect(remaining.isEmpty)
        #expect(keychain.deletedIds.isEmpty)
    }
}

// MARK: - Test doubles

private final class FailingKeychain: KeychainServiceProtocol {
    func save(secret _: String, for _: UUID) throws {}
    func read(for _: UUID) throws -> String {
        "JBSWY3DPEHPK3PXP"
    }

    func delete(for _: UUID) throws {
        throw KeychainError.deleteFailed(-1)
    }
}
