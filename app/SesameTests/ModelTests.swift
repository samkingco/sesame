import Foundation
@testable import Sesame
import Testing

struct ModelTests {
    @Test func accountRoundTrip() throws {
        let profileId = UUID()
        let account = Account(
            profileId: profileId,
            issuer: "GitHub",
            displayIssuer: "GH",
            name: "user@example.com",
            displayName: "Work",
            type: .totp,
            algorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 0
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        #expect(decoded.id == account.id)
        #expect(decoded.profileId == profileId)
        #expect(decoded.issuer == "GitHub")
        #expect(decoded.displayIssuer == "GH")
        #expect(decoded.name == "user@example.com")
        #expect(decoded.displayName == "Work")
        #expect(decoded.type == .totp)
        #expect(decoded.algorithm == .sha256)
        #expect(decoded.digits == 8)
        #expect(decoded.period == 60)
        #expect(decoded.counter == 0)
    }

    @Test func accountNilOptionals() throws {
        let account = Account(
            profileId: UUID(),
            issuer: "Test",
            name: "test"
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        #expect(decoded.displayIssuer == nil)
        #expect(decoded.displayName == nil)
        #expect(decoded.deletedAt == nil)
    }

    @Test func accountDeletedAtRoundTrip() throws {
        let deletedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let account = Account(
            profileId: UUID(),
            issuer: "Test",
            name: "test",
            deletedAt: deletedDate
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(Account.self, from: data)

        #expect(decoded.deletedAt == deletedDate)
    }

    @Test func accountDefaults() {
        let account = Account(profileId: UUID(), issuer: "Test", name: "test")
        #expect(account.type == .totp)
        #expect(account.algorithm == .sha1)
        #expect(account.digits == 6)
        #expect(account.period == 30)
        #expect(account.counter == 0)
    }

    @Test func profileRoundTrip() throws {
        let profile = Profile(name: "Work", color: "#FF0000")

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        #expect(decoded.id == profile.id)
        #expect(decoded.name == "Work")
        #expect(decoded.color == "#FF0000")
    }

    @Test func profileDefaultIsDefault() {
        let profile = Profile.makeDefault()
        #expect(profile.isDefault)
        #expect(profile.name == "Personal")
        #expect(profile.id == Profile.defaultID)
    }

    @Test func profileNonDefaultIsNotDefault() {
        let profile = Profile(name: "Work")
        #expect(!profile.isDefault)
    }

    @Test func otpTypeRawValues() {
        #expect(OTPType.totp.rawValue == "totp")
        #expect(OTPType.hotp.rawValue == "hotp")
    }

    @Test func otpAlgorithmRawValues() {
        #expect(OTPAlgorithm.sha1.rawValue == "sha1")
        #expect(OTPAlgorithm.sha256.rawValue == "sha256")
        #expect(OTPAlgorithm.sha512.rawValue == "sha512")
    }
}
