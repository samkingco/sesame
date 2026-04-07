import Foundation
@testable import Sesame
import SwiftData
import Testing
import UniformTypeIdentifiers

@MainActor
struct FileExportTests {
    private let testPassword = "correct-horse-battery-staple"

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Account.self, Profile.self, configurations: config)
    }

    private func makeService(
        context: ModelContext,
        keychain: KeychainServiceProtocol = StubKeychain()
    ) -> BackupService {
        let suiteName = "studio.samking.Sesame.FileExportTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return BackupService(keychain: keychain, modelContext: context, defaults: defaults)
    }

    // MARK: - Encrypted Blob

    @Test("buildEncryptedBlob produces a valid .sesame blob")
    func blobHasCorrectHeader() async throws {
        let container = try makeContainer()
        let context = container.mainContext

        let account = Account(profileId: Profile.defaultID, issuer: "GitHub", name: "user@gh.com")
        context.insert(account)
        try context.save()

        let service = makeService(context: context)
        let blob = try await service.buildEncryptedBlob(password: testPassword)

        let magic = String(data: blob[0 ..< 6], encoding: .utf8)
        #expect(magic == "SESAME")
        #expect(blob[6] == 0x01)
    }

    @Test("buildEncryptedBlob round-trips through decrypt")
    func blobRoundTrip() async throws {
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

        let service = makeService(context: context)
        let blob = try await service.buildEncryptedBlob(password: testPassword)

        let decrypted = try BackupCrypto.decrypt(blob: blob, password: testPassword)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: decrypted)

        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "GitHub")
        #expect(payload.accounts[0].algorithm == .sha256)
        #expect(payload.accounts[0].digits == 8)
        #expect(payload.profiles.count == 1)
        #expect(payload.profiles[0].name == "Work")
    }

    // MARK: - Temp File

    @Test("Temp file uses correct naming format")
    func tempFileNaming() throws {
        let blob = Data("test-blob".utf8)
        let url = try ExportBackupView.writeTempFile(blob: blob)
        defer { try? FileManager.default.removeItem(at: url) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = formatter.string(from: .now)
        let expectedFilename = "sesame-backup-\(expectedDate).sesame"

        #expect(url.lastPathComponent == expectedFilename)
        #expect(url.pathExtension == "sesame")
    }

    @Test("Temp file contains the written data")
    func tempFileContents() throws {
        let blob = Data("test-blob-content".utf8)
        let url = try ExportBackupView.writeTempFile(blob: blob)
        defer { try? FileManager.default.removeItem(at: url) }

        let readBack = try Data(contentsOf: url)
        #expect(readBack == blob)
    }

    @Test("Temp file can be deleted")
    func tempFileCleanup() throws {
        let blob = Data("temporary".utf8)
        let url = try ExportBackupView.writeTempFile(blob: blob)

        #expect(FileManager.default.fileExists(atPath: url.path))
        try FileManager.default.removeItem(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - UTType

    @Test("UTType.sesameBackup has correct identifier")
    func utTypeIdentifier() {
        #expect(UTType.sesameBackup.identifier == "studio.samking.sesame-backup")
    }
}
