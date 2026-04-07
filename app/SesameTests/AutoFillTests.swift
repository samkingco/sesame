import Foundation
@testable import Sesame
import Testing

// MARK: - Domain Matching

struct DomainMatchingTests {
    @Test func exactDomainMatches() {
        #expect(DomainMatcher.matches(domain: "github.com", website: "github.com"))
    }

    @Test func subdomainMatches() {
        #expect(DomainMatcher.matches(domain: "sub.github.com", website: "github.com"))
    }

    @Test func deepSubdomainMatches() {
        #expect(DomainMatcher.matches(domain: "a.b.github.com", website: "github.com"))
    }

    @Test func caseInsensitiveMatching() {
        #expect(DomainMatcher.matches(domain: "GitHub.com", website: "github.com"))
        #expect(DomainMatcher.matches(domain: "github.com", website: "GitHub.com"))
        #expect(DomainMatcher.matches(domain: "SUB.GITHUB.COM", website: "github.com"))
    }

    @Test func differentDomainDoesNotMatch() {
        #expect(!DomainMatcher.matches(domain: "gitlab.com", website: "github.com"))
    }

    @Test func suffixThatIsNotSubdomainDoesNotMatch() {
        // "evil-github.com" ends with "github.com" but is not a subdomain
        #expect(!DomainMatcher.matches(domain: "evil-github.com", website: "github.com"))
    }

    @Test func emptyDomainsDoNotMatch() {
        #expect(!DomainMatcher.matches(domain: "", website: "github.com"))
        #expect(!DomainMatcher.matches(domain: "github.com", website: ""))
    }
}

// MARK: - Account Filtering

struct AccountFilteringTests {
    private static let profileId = Profile.defaultID

    private func makeAccount(
        issuer: String,
        name: String = "user",
        website: String? = nil,
        deletedAt: Date? = nil,
        type: OTPType = .totp
    ) -> Account {
        Account(
            profileId: Self.profileId,
            issuer: issuer,
            name: name,
            type: type,
            deletedAt: deletedAt,
            website: website
        )
    }

    @Test func filtersToMatchingDomain() {
        let github = makeAccount(issuer: "GitHub", website: "github.com")
        let google = makeAccount(issuer: "Google", website: "google.com")
        let result = DomainMatcher.filterAccounts([github, google], forDomains: ["github.com"])
        #expect(result.count == 1)
        #expect(result.first?.issuer == "GitHub")
    }

    @Test func excludesDeletedAccounts() {
        let active = makeAccount(issuer: "GitHub", website: "github.com")
        let deleted = makeAccount(issuer: "GitHub", website: "github.com", deletedAt: .now)
        let result = DomainMatcher.filterAccounts([active, deleted], forDomains: ["github.com"])
        #expect(result.count == 1)
        #expect(result.first?.deletedAt == nil)
    }

    @Test func excludesAccountsWithNoWebsite() {
        let withWebsite = makeAccount(issuer: "GitHub", website: "github.com")
        let noWebsite = makeAccount(issuer: "MyApp")
        let result = DomainMatcher.filterAccounts([withWebsite, noWebsite], forDomains: ["github.com"])
        #expect(result.count == 1)
        #expect(result.first?.issuer == "GitHub")
    }

    @Test func multipleAccountsMatchSameDomain() {
        let a = makeAccount(issuer: "GitHub", name: "personal", website: "github.com")
        let b = makeAccount(issuer: "GitHub", name: "work", website: "github.com")
        let result = DomainMatcher.filterAccounts([a, b], forDomains: ["github.com"])
        #expect(result.count == 2)
    }

    @Test func subdomainMatchesStoredDomain() {
        let account = makeAccount(issuer: "GitHub", website: "github.com")
        let result = DomainMatcher.filterAccounts([account], forDomains: ["sub.github.com"])
        #expect(result.count == 1)
    }

    @Test func emptyDomainsReturnsAllNonDeletedAccounts() {
        let a = makeAccount(issuer: "GitHub", website: "github.com")
        let b = makeAccount(issuer: "Google", website: "google.com")
        let result = DomainMatcher.filterAccounts([a, b], forDomains: [])
        #expect(result.count == 2)
    }

    @Test func noMatchReturnsEmpty() {
        let account = makeAccount(issuer: "GitHub", website: "github.com")
        let result = DomainMatcher.filterAccounts([account], forDomains: ["gitlab.com"])
        #expect(result.isEmpty)
    }
}

// MARK: - Code Generation

@MainActor
struct AutoFillCodeGenerationTests {
    // JBSWY3DPEHPK3PXP is the base32 encoding of "Hello!"
    private let testSecret = "JBSWY3DPEHPK3PXP"
    private static let profileId = Profile.defaultID

    @Test func totpCodeGeneratedForMatchedAccount() {
        let accountId = UUID()
        let account = Account(
            id: accountId,
            profileId: Self.profileId,
            issuer: "GitHub",
            name: "user",
            type: .totp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            website: "github.com"
        )

        let service = CodeService(keychain: StubKeychain(secrets: [accountId: testSecret]))
        service.refreshCodes(for: [account], at: .now)

        let code = service.code(for: accountId)
        #expect(code?.code.count == 6)
        #expect(code?.type == .totp)
    }

    @Test func hotpCodeGeneratedForMatchedAccount() {
        let accountId = UUID()
        let account = Account(
            id: accountId,
            profileId: Self.profileId,
            issuer: "AWS",
            name: "user",
            type: .hotp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            counter: 0,
            website: "aws.amazon.com"
        )

        let service = CodeService(keychain: StubKeychain(secrets: [accountId: testSecret]))
        service.refreshCodes(for: [account], at: .now)

        let code = service.code(for: accountId)
        #expect(code?.code.count == 6)
        #expect(code?.type == .hotp)
        #expect(code?.counter == 0)
    }

    @Test func totpCodeIsDeterministicForFixedTimestamp() {
        let accountId = UUID()
        let account = Account(
            id: accountId,
            profileId: Self.profileId,
            issuer: "GitHub",
            name: "user",
            type: .totp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            website: "github.com"
        )

        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let service = CodeService(keychain: StubKeychain(secrets: [accountId: testSecret]))

        service.refreshCodes(for: [account], at: timestamp)
        let first = service.code(for: accountId)

        service.evictSecret(for: accountId)
        service.refreshCodes(for: [account], at: timestamp)
        let second = service.code(for: accountId)

        #expect(first?.code == second?.code)
    }
}
