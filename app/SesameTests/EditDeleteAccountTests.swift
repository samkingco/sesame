import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct EditDeleteAccountTests {
    private func makeAccount(
        issuer: String = "GitHub",
        name: String = "user@github.com",
        displayIssuer: String? = nil,
        displayName: String? = nil
    ) -> Account {
        Account(
            profileId: Profile.defaultID,
            issuer: issuer,
            displayIssuer: displayIssuer,
            name: name,
            displayName: displayName
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    // MARK: - Edit

    @Test("Edit sets displayIssuer on account")
    func editSetsDisplayIssuer() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount()
        context.insert(account)
        try context.save()

        account.displayIssuer = "GH Enterprise"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Account>())
        #expect(fetched.count == 1)
        #expect(fetched[0].displayIssuer == "GH Enterprise")
        #expect(fetched[0].issuer == "GitHub")
    }

    @Test("Edit sets displayName on account")
    func editSetsDisplayName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount()
        context.insert(account)
        try context.save()

        account.displayName = "work@github.com"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Account>())
        #expect(fetched.count == 1)
        #expect(fetched[0].displayName == "work@github.com")
        #expect(fetched[0].name == "user@github.com")
    }

    @Test("Edit with empty fields clears display overrides")
    func editClearsOverrides() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(displayIssuer: "Custom", displayName: "Custom Name")
        context.insert(account)
        try context.save()

        // Simulates what EditAccountSheet does when fields match original or are empty
        account.displayIssuer = nil
        account.displayName = nil
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Account>())
        #expect(fetched[0].displayIssuer == nil)
        #expect(fetched[0].displayName == nil)
    }

    // MARK: - Delete

    @Test("Delete removes account from SwiftData")
    func deleteRemovesFromSwiftData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount()
        context.insert(account)
        try context.save()

        context.delete(account)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Account>())
        #expect(fetched.isEmpty)
    }

    @Test("Delete removes secret from Keychain")
    func deleteRemovesFromKeychain() throws {
        let keychain = SpyKeychain()
        let account = makeAccount()

        try keychain.delete(for: account.id)

        #expect(keychain.deletedIds.contains(account.id))
    }
}
