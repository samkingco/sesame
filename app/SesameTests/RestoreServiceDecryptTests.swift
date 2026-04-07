import Foundation
@testable import Sesame
import Testing

struct RestoreServiceDecryptTests {
    private let testPassword = "correct-horse-battery-staple"

    // MARK: - Helpers

    private func makeEncryptedBlob(
        accounts: [BackupAccount] = [],
        profiles: [BackupProfile] = []
    ) throws -> Data {
        let payload = BackupPayload(
            payloadVersion: 1,
            createdAt: .now,
            profiles: profiles,
            accounts: accounts
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(payload)
        return try BackupCrypto.encrypt(payload: json, password: testPassword)
    }

    // MARK: - Success

    @Test("Decrypts a valid blob and returns a BackupPayload")
    func decryptsValidBlob() async throws {
        let account = BackupAccount(
            id: UUID(),
            profileId: Profile.defaultID,
            issuer: "GitHub",
            displayIssuer: nil,
            name: "user@gh.com",
            displayName: nil,
            type: .totp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            counter: 0,
            createdAt: .now,
            secret: "JBSWY3DPEHPK3PXP",
            website: nil
        )
        let blob = try makeEncryptedBlob(accounts: [account])

        let payload = try await RestoreService.decryptPayload(data: blob, password: testPassword)

        #expect(payload.payloadVersion == 1)
        #expect(payload.accounts.count == 1)
        #expect(payload.accounts[0].issuer == "GitHub")
        #expect(payload.accounts[0].name == "user@gh.com")
        #expect(payload.accounts[0].secret == "JBSWY3DPEHPK3PXP")
    }

    // MARK: - Password Required

    @Test("Throws passwordRequired when password is nil")
    func throwsWhenPasswordNil() async {
        let blob = Data("dummy".utf8)

        await #expect(throws: RestoreError.passwordRequired) {
            try await RestoreService.decryptPayload(data: blob, password: nil)
        }
    }

    // MARK: - Wrong Password

    @Test("Throws when password is wrong")
    func throwsWhenPasswordWrong() async throws {
        let blob = try makeEncryptedBlob()

        await #expect(throws: BackupCryptoError.decryptionFailed) {
            try await RestoreService.decryptPayload(data: blob, password: "wrong-password")
        }
    }

    // MARK: - Invalid Data

    @Test("Throws invalidBlob for non-sesame data")
    func throwsForInvalidData() async {
        let garbage = Data("not a sesame backup".utf8)

        await #expect(throws: BackupCryptoError.invalidBlob) {
            try await RestoreService.decryptPayload(data: garbage, password: testPassword)
        }
    }
}
