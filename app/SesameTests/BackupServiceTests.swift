import Foundation
@testable import Sesame
import SwiftData
import Testing

@MainActor
struct BackupServiceTests {
    private let testPassword = "correct-horse-battery-staple"

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    private func makeService(
        context: ModelContext,
        keychain: KeychainServiceProtocol = StubKeychain()
    ) -> BackupService {
        let suiteName = "studio.samking.Sesame.BackupServiceTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return BackupService(keychain: keychain, modelContext: context, defaults: defaults)
    }

    // MARK: - Backup

    @Test("backup() calls adapter store with a valid .sesame blob")
    func backupStoresBlob() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let account = Account(profileId: Profile.defaultID, issuer: "GitHub", name: "user@gh.com")
        context.insert(account)
        try context.save()

        let adapter = MockAdapter()
        let service = makeService(context: context)

        try await service.backup(using: adapter, password: testPassword)

        #expect(adapter.storedBlob != nil)

        let blob = try #require(adapter.storedBlob)
        let magic = String(data: blob[0 ..< 6], encoding: .utf8)
        #expect(magic == "SESAME")
        #expect(blob[6] == 0x01)
    }

    // MARK: - Retrieve

    @Test("retrieve() returns a BackupPayload matching what was backed up")
    func retrieveReturnsPayload() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let account = Account(profileId: Profile.defaultID, issuer: "GitHub", name: "user@gh.com")
        context.insert(account)
        try context.save()

        let adapter = MockAdapter()
        let service = makeService(context: context)

        try await service.backup(using: adapter, password: testPassword)
        let payload = try await service.retrieve(using: adapter, password: testPassword)

        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "GitHub")
        #expect(payload.accounts[0].name == "user@gh.com")
    }

    // MARK: - Round-trip

    @Test("Round-trip: backup then retrieve returns same accounts and profiles")
    func roundTrip() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let profile = Profile(name: "Work", color: "#FF0000", sortOrder: 1)
        let account = Account(
            profileId: profile.id,
            issuer: "GitHub",
            name: "user@gh.com",
            type: .totp,
            algorithm: .sha256,
            digits: 8,
            period: 60
        )
        context.insert(profile)
        context.insert(account)
        try context.save()

        let adapter = MockAdapter()
        let service = makeService(context: context)

        try await service.backup(using: adapter, password: testPassword)
        let payload = try await service.retrieve(using: adapter, password: testPassword)

        #expect(payload.payloadVersion == 1)
        #expect(payload.profiles.count == 1)
        #expect(payload.profiles[0].name == "Work")
        #expect(payload.profiles[0].color == "#FF0000")
        #expect(payload.profiles[0].sortOrder == 1)
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "GitHub")
        #expect(payload.accounts[0].algorithm == .sha256)
        #expect(payload.accounts[0].digits == 8)
        #expect(payload.accounts[0].period == 60)
        #expect(payload.accounts[0].secret == "JBSWY3DPEHPK3PXP")
    }

    // MARK: - Backup Password

    @Test("saveBackupPassword and storedBackupPassword round-trip through Keychain")
    func passwordRoundTrip() throws {
        let container = try makeContainer()
        let service = makeService(context: container.mainContext)

        try? service.clearBackupPassword(for: "test")

        try service.saveBackupPassword("my-backup-password", for: "test")
        let stored = service.storedBackupPassword(for: "test")
        #expect(stored == "my-backup-password")

        try service.clearBackupPassword(for: "test")
    }

    @Test("clearBackupPassword removes stored password")
    func clearPassword() throws {
        let container = try makeContainer()
        let service = makeService(context: container.mainContext)

        try service.saveBackupPassword("temporary", for: "test")
        try service.clearBackupPassword(for: "test")

        #expect(service.storedBackupPassword(for: "test") == nil)
    }

    @Test("storedBackupPassword returns nil when nothing is stored")
    func noStoredPassword() throws {
        let container = try makeContainer()
        let service = makeService(context: container.mainContext)

        try? service.clearBackupPassword(for: "test")

        #expect(service.storedBackupPassword(for: "test") == nil)
    }

    // MARK: - Last Device Backup Date

    @Test("lastDeviceBackupDate returns nil before any backup")
    func lastBackupDateNilInitially() throws {
        let container = try makeContainer()
        let service = makeService(context: container.mainContext)

        #expect(service.lastDeviceBackupDate(for: "icloud") == nil)
    }

    @Test("lastDeviceBackupDate returns correct date after successful backup")
    func lastBackupDateAfterBackup() async throws {
        let container = try makeContainer()
        let adapter = MockAdapter(key: "icloud")
        let service = makeService(context: container.mainContext)

        let before = Date.now
        try await service.backup(using: adapter, password: testPassword)
        let after = Date.now

        let date = try #require(service.lastDeviceBackupDate(for: "icloud"))
        #expect(date >= before)
        #expect(date <= after)
    }

    @Test("lastDeviceBackupDate is per-adapter")
    func lastBackupDatePerAdapter() async throws {
        let container = try makeContainer()
        let icloudAdapter = MockAdapter(key: "icloud")
        let fileAdapter = MockAdapter(key: "file")
        let service = makeService(context: container.mainContext)

        try await service.backup(using: icloudAdapter, password: testPassword)

        #expect(service.lastDeviceBackupDate(for: "icloud") != nil)
        #expect(service.lastDeviceBackupDate(for: "file") == nil)

        try await service.backup(using: fileAdapter, password: testPassword)

        #expect(service.lastDeviceBackupDate(for: "file") != nil)
    }

    // MARK: - Mock Adapter Contract

    @Test("Mock adapter verifies protocol contract")
    func mockAdapterContract() async throws {
        let adapter = MockAdapter()

        let date = try await adapter.lastDestinationBackupDate()
        #expect(date == nil)

        let testData = Data("test".utf8)
        try await adapter.store(blob: testData)

        let retrieved = try await adapter.retrieve()
        #expect(retrieved == testData)

        let afterDate = try await adapter.lastDestinationBackupDate()
        #expect(afterDate != nil)
    }
}

// MARK: - Test Helpers

private final class MockAdapter: BackupAdapter {
    let adapterKey: String
    var storedBlob: Data?
    private var storedDate: Date?

    init(key: String = "mock") {
        adapterKey = key
    }

    func store(blob: Data) async throws {
        storedBlob = blob
        storedDate = .now
    }

    func retrieve() async throws -> Data {
        guard let blob = storedBlob else {
            throw MockAdapterError.noBackup
        }
        return blob
    }

    func lastDestinationBackupDate() async throws -> Date? {
        storedDate
    }

    func deleteBackup() async throws {
        storedBlob = nil
        storedDate = nil
    }
}

private enum MockAdapterError: Error {
    case noBackup
}
