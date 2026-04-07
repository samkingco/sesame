import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct RestoreServiceTests {
    private let restoreService = RestoreService()

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    private func makePayload(
        accounts: [BackupAccount] = [],
        profiles: [BackupProfile] = []
    ) -> BackupPayload {
        BackupPayload(
            payloadVersion: 1,
            createdAt: .now,
            profiles: profiles,
            accounts: accounts
        )
    }

    private func backupAccount(
        issuer: String,
        name: String,
        profileId: UUID = Profile.defaultID,
        secret: String = "JBSWY3DPEHPK3PXP"
    ) -> BackupAccount {
        BackupAccount(
            id: UUID(),
            profileId: profileId,
            issuer: issuer,
            displayIssuer: nil,
            name: name,
            displayName: nil,
            type: .totp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            counter: 0,
            createdAt: .now,
            secret: secret,
            website: nil
        )
    }

    private func fetchAccounts(_ context: ModelContext) throws -> [Account] {
        try context.fetch(FetchDescriptor<Account>())
    }

    private func fetchProfiles(_ context: ModelContext) throws -> [Profile] {
        try context.fetch(FetchDescriptor<Profile>())
    }

    // MARK: - Removes existing data

    @Test("Removes all existing accounts and inserts payload accounts")
    func replacesAccounts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain(defaultSecret: nil)

        let existing = Account(profileId: Profile.defaultID, issuer: "Old", name: "old@test.com")
        context.insert(existing)
        try keychain.save(secret: "OLDSECRET", for: existing.id)
        try context.save()

        let payload = makePayload(
            accounts: [backupAccount(issuer: "GitHub", name: "user@gh.com")],
            profiles: [BackupProfile(id: Profile.defaultID, name: "Personal", color: "#3B82F6", sortOrder: 0)]
        )

        try restoreService.restore(
            payload: payload,
            modelContext: context,
            keychain: keychain
        )

        let accounts = try fetchAccounts(context)
        #expect(accounts.count == 1)
        #expect(accounts[0].issuer == "GitHub")
        #expect(accounts[0].name == "user@gh.com")
    }

    // MARK: - Keychain secrets

    @Test("Writes keychain secrets for all imported accounts")
    func writesSecrets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain(defaultSecret: nil)

        let ba = backupAccount(issuer: "GitHub", name: "user@gh.com", secret: "NEWSECRET")
        let payload = makePayload(
            accounts: [ba],
            profiles: [BackupProfile(id: Profile.defaultID, name: "Personal", color: nil, sortOrder: 0)]
        )

        try restoreService.restore(
            payload: payload,
            modelContext: context,
            keychain: keychain
        )

        let accounts = try fetchAccounts(context)
        let secret = try keychain.read(for: accounts[0].id)
        #expect(secret == "NEWSECRET")
    }

    @Test("Deletes keychain secrets for removed accounts")
    func deletesOldSecrets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain(defaultSecret: nil)

        let existing = Account(profileId: Profile.defaultID, issuer: "Old", name: "old@test.com")
        context.insert(existing)
        try keychain.save(secret: "OLDSECRET", for: existing.id)
        try context.save()

        let oldId = existing.id
        let payload = makePayload(
            accounts: [],
            profiles: [BackupProfile(id: Profile.defaultID, name: "Personal", color: nil, sortOrder: 0)]
        )

        try restoreService.restore(
            payload: payload,
            modelContext: context,
            keychain: keychain
        )

        #expect(keychain.storage[oldId] == nil)
    }

    // MARK: - Profiles

    @Test("Replaces all profiles with payload profiles")
    func replacesProfiles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain(defaultSecret: nil)

        context.insert(Profile(name: "Old Profile", color: "#FF0000"))
        try context.save()

        let newProfileId = UUID()
        let payload = makePayload(
            profiles: [
                BackupProfile(id: Profile.defaultID, name: "Personal", color: "#3B82F6", sortOrder: 0),
                BackupProfile(id: newProfileId, name: "Work", color: "#FF0000", sortOrder: 1),
            ]
        )

        try restoreService.restore(
            payload: payload,
            modelContext: context,
            keychain: keychain
        )

        let profiles = try fetchProfiles(context)
        let names = Set(profiles.map(\.name))
        #expect(profiles.count == 2)
        #expect(names == ["Personal", "Work"])
    }

    @Test("Ensures default profile exists even if not in payload")
    func ensuresDefaultProfile() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain(defaultSecret: nil)

        let payload = makePayload(
            profiles: [BackupProfile(id: UUID(), name: "Work", color: "#FF0000", sortOrder: 1)]
        )

        try restoreService.restore(
            payload: payload,
            modelContext: context,
            keychain: keychain
        )

        let profiles = try fetchProfiles(context)
        let hasDefault = profiles.contains { $0.id == Profile.defaultID }
        #expect(hasDefault)
        #expect(profiles.count == 2)
    }
}
