import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct BackupPayloadTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Round-trip

    @Test("BackupPayload round-trips through JSON")
    func payloadRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = BackupPayload(
            payloadVersion: 1,
            createdAt: now,
            profiles: [
                BackupProfile(id: UUID(), name: "Work", color: "#FF0000", sortOrder: 1),
            ],
            accounts: [
                BackupAccount(
                    id: UUID(),
                    profileId: UUID(),
                    issuer: "GitHub",
                    displayIssuer: nil,
                    name: "user@github.com",
                    displayName: nil,
                    type: .totp,
                    algorithm: .sha1,
                    digits: 6,
                    period: 30,
                    counter: 0,
                    createdAt: now,
                    secret: "JBSWY3DPEHPK3PXP",
                    website: nil
                ),
            ]
        )

        let data = try makeEncoder().encode(payload)
        let decoded = try makeDecoder().decode(BackupPayload.self, from: data)

        #expect(decoded.payloadVersion == 1)
        #expect(decoded.createdAt == now)
        #expect(decoded.profiles.count == 1)
        #expect(decoded.accounts.count == 1)
    }

    @Test("BackupAccount preserves all fields including secret")
    func accountFieldPreservation() throws {
        let id = UUID()
        let profileId = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let account = BackupAccount(
            id: id,
            profileId: profileId,
            issuer: "GitHub",
            displayIssuer: "GH Enterprise",
            name: "user@github.com",
            displayName: "Work Account",
            type: .hotp,
            algorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 42,
            createdAt: now,
            secret: "JBSWY3DPEHPK3PXP",
            website: "github.com"
        )

        let data = try makeEncoder().encode(account)
        let decoded = try makeDecoder().decode(BackupAccount.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.profileId == profileId)
        #expect(decoded.issuer == "GitHub")
        #expect(decoded.displayIssuer == "GH Enterprise")
        #expect(decoded.name == "user@github.com")
        #expect(decoded.displayName == "Work Account")
        #expect(decoded.type == .hotp)
        #expect(decoded.algorithm == .sha256)
        #expect(decoded.digits == 8)
        #expect(decoded.period == 60)
        #expect(decoded.counter == 42)
        #expect(decoded.createdAt == now)
        #expect(decoded.secret == "JBSWY3DPEHPK3PXP")
    }

    @Test("BackupProfile preserves all fields including sortOrder")
    func profileFieldPreservation() throws {
        let id = UUID()
        let profile = BackupProfile(id: id, name: "Work", color: "#3B82F6", sortOrder: 3)

        let data = try makeEncoder().encode(profile)
        let decoded = try makeDecoder().decode(BackupProfile.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.name == "Work")
        #expect(decoded.color == "#3B82F6")
        #expect(decoded.sortOrder == 3)
    }

    @Test("Date encoding uses ISO 8601")
    func dateEncodingIsISO8601() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = BackupPayload(
            payloadVersion: 1,
            createdAt: date,
            profiles: [],
            accounts: []
        )

        let data = try makeEncoder().encode(payload)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("2023-11-14T22:13:20Z"))
    }

    // MARK: - Builder

    @Test("Builder excludes soft-deleted accounts")
    func builderExcludesSoftDeleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain()

        let active = Account(profileId: Profile.defaultID, issuer: "Active", name: "a@a.com")
        let deleted = Account(
            profileId: Profile.defaultID,
            issuer: "Deleted",
            name: "d@d.com",
            deletedAt: .now
        )
        context.insert(active)
        context.insert(deleted)
        try context.save()

        let payload = try BackupPayloadBuilder.build(context: context, keychain: keychain)

        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "Active")
    }

    @Test("Builder skips accounts with missing Keychain secrets")
    func builderSkipsMissingSecrets() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain()

        let account1 = Account(profileId: Profile.defaultID, issuer: "HasSecret", name: "a@a.com")
        let account2 = Account(profileId: Profile.defaultID, issuer: "NoSecret", name: "b@b.com")
        context.insert(account1)
        context.insert(account2)
        try context.save()

        // Mark account2 as failing
        keychain.failingIds.insert(account2.id)

        let payload = try BackupPayloadBuilder.build(context: context, keychain: keychain)

        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "HasSecret")
    }

    @Test("Builder includes profiles")
    func builderIncludesProfiles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let keychain = StubKeychain()

        let profile = Profile(name: "Work", color: "#FF0000", sortOrder: 2)
        context.insert(profile)
        try context.save()

        let payload = try BackupPayloadBuilder.build(context: context, keychain: keychain)

        #expect(payload.profiles.count == 1)
        #expect(payload.profiles[0].name == "Work")
        #expect(payload.profiles[0].color == "#FF0000")
        #expect(payload.profiles[0].sortOrder == 2)
    }
}
