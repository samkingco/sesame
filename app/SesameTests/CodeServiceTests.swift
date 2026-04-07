import Foundation
@testable import Sesame
import Testing

@MainActor
struct CodeServiceTests {
    let testSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    private func makeAccount(
        id: UUID = UUID(),
        type: OTPType = .totp,
        counter: Int = 0
    ) -> Account {
        Account(
            id: id,
            profileId: Profile.defaultID,
            issuer: "Test",
            name: "test@example.com",
            type: type,
            counter: counter
        )
    }

    // MARK: - Secret Caching

    @Test("Secret is read from keychain on first access and cached")
    func secretCaching() {
        let spy = SpyKeychain()
        let accountId = UUID()
        spy.storage[accountId] = testSecret
        let service = CodeService(keychain: spy)

        let first = service.secret(for: accountId)
        let second = service.secret(for: accountId)

        #expect(first == testSecret)
        #expect(second == testSecret)
    }

    @Test("Secret returns nil for missing keychain entry")
    func secretMissing() {
        let keychain = StubKeychain(defaultSecret: nil)
        let service = CodeService(keychain: keychain)

        let result = service.secret(for: UUID())
        #expect(result == nil)
    }

    @Test("evictSecret removes cached secret and code")
    func evictSecret() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 59))
        #expect(service.code(for: accountId) != nil)

        service.evictSecret(for: accountId)
        #expect(service.code(for: accountId) == nil)
    }

    @Test("clearSecretCache removes all cached secrets")
    func clearSecretCache() {
        let id1 = UUID()
        let id2 = UUID()
        let keychain = StubKeychain(secrets: [id1: testSecret, id2: testSecret], defaultSecret: nil)
        let service = CodeService(keychain: keychain)

        _ = service.secret(for: id1)
        _ = service.secret(for: id2)

        service.clearSecretCache()

        // After clearing, secrets are re-read from keychain on next access
        // Remove from keychain to prove cache was cleared
        keychain.storage.removeAll()
        #expect(service.secret(for: id1) == nil)
        #expect(service.secret(for: id2) == nil)
    }

    // MARK: - Code Refresh

    @Test("refreshCodes generates TOTP code with window metadata")
    func refreshCodesTOTP() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)
        let date = Date(timeIntervalSince1970: 59)

        service.refreshCodes(for: [account], at: date)

        let code = service.code(for: accountId)
        #expect(code != nil)
        #expect(code?.code.count == 6)
        #expect(code?.type == .totp)
        #expect(code?.windowStart != nil)
        #expect(code?.windowEnd != nil)
        #expect(code?.remainingSeconds != nil)
        #expect(code?.progress != nil)
    }

    @Test("refreshCodes generates HOTP code with known value")
    func refreshCodesHOTP() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId, type: .hotp, counter: 0)

        service.refreshCodes(for: [account], at: .now)

        let code = service.code(for: accountId)
        #expect(code?.code == "755224")
        #expect(code?.type == .hotp)
        #expect(code?.windowStart == nil)
        #expect(code?.windowEnd == nil)
    }

    @Test("TOTP respects account algorithm and digits")
    func totpRespectsAlgorithm() {
        let sha256Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA===="
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: sha256Secret], defaultSecret: nil)
        let service = CodeService(keychain: keychain)
        let account = Account(
            id: accountId,
            profileId: Profile.defaultID,
            issuer: "Test",
            name: "test@example.com",
            algorithm: .sha256,
            digits: 8
        )

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 59))

        #expect(service.code(for: accountId)?.code == "46119246")
    }

    @Test("refreshCodes skips TOTP within same window")
    func refreshCodesSkipsSameWindow() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)

        let date1 = Date(timeIntervalSince1970: 31)
        let date2 = Date(timeIntervalSince1970: 35)

        service.refreshCodes(for: [account], at: date1)
        let code1 = service.code(for: accountId)

        service.refreshCodes(for: [account], at: date2)
        let code2 = service.code(for: accountId)

        #expect(code1?.code == code2?.code)
    }

    @Test("refreshCodes regenerates on new TOTP window")
    func refreshCodesNewWindow() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 29))
        let code1 = service.code(for: accountId)

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 31))
        let code2 = service.code(for: accountId)

        #expect(code1?.code != code2?.code)
    }

    @Test("refreshCodes skips accounts with missing secrets")
    func refreshCodesSkipsMissing() {
        let keychain = StubKeychain(defaultSecret: nil)
        let service = CodeService(keychain: keychain)
        let account = makeAccount()

        service.refreshCodes(for: [account], at: .now)
        #expect(service.code(for: account.id) == nil)
    }

    // MARK: - Copied State

    @Test("copyCode sets copiedAccountId")
    func copyCodeSetsCopied() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 59))
        service.copyCode(for: accountId)

        #expect(service.copiedAccountId == accountId)
    }

    @Test("copyCode with explicit code sets copiedAccountId")
    func copyCodeWithExplicitCode() {
        let keychain = StubKeychain(defaultSecret: nil)
        let service = CodeService(keychain: keychain)
        let accountId = UUID()

        service.copyCode(for: accountId, code: "123456")

        #expect(service.copiedAccountId == accountId)
    }

    @Test("Copied state clears on code rotation")
    func copiedClearsOnRotation() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId)

        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 29))
        service.copyCode(for: accountId)
        #expect(service.copiedAccountId == accountId)

        // New window produces a different code — copied state should clear
        service.refreshCodes(for: [account], at: Date(timeIntervalSince1970: 31))
        #expect(service.copiedAccountId == nil)
    }

    // MARK: - HOTP

    @Test("HOTP code stable without counter increment")
    func hotpStableWithoutIncrement() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId, type: .hotp, counter: 3)

        service.refreshCodes(for: [account], at: .now)
        let first = service.code(for: accountId)

        service.refreshCodes(for: [account], at: .now)
        let second = service.code(for: accountId)

        #expect(first?.code == second?.code)
        #expect(account.counter == 3)
    }

    @Test("incrementCounter generates new code")
    func incrementCounter() {
        let accountId = UUID()
        let keychain = StubKeychain(secrets: [accountId: testSecret])
        let service = CodeService(keychain: keychain)
        let account = makeAccount(id: accountId, type: .hotp, counter: 0)

        service.refreshCodes(for: [account], at: .now)
        let before = service.code(for: accountId)?.code

        service.incrementCounter(for: account)
        let after = service.code(for: accountId)?.code

        #expect(account.counter == 1)
        #expect(before != after)
    }

    @Test("incrementCounter rolls back on failure")
    func incrementCounterRollback() {
        let keychain = StubKeychain(defaultSecret: nil)
        let service = CodeService(keychain: keychain)
        let account = makeAccount(type: .hotp, counter: 5)

        service.incrementCounter(for: account)

        #expect(account.counter == 5)
    }
}
