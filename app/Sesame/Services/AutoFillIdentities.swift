import AuthenticationServices
import Foundation

/// Main actor because it reads SwiftData models.
@MainActor
enum AutoFillIdentities {
    /// HOTP is excluded: the extension can't advance the counter.
    static func make(for accounts: [Account]) -> [ASOneTimeCodeCredentialIdentity] {
        accounts.compactMap { account in
            guard account.deletedAt == nil,
                  account.type == .totp,
                  let domain = account.website.flatMap(DomainMatcher.normalizedDomain)
            else { return nil }

            return ASOneTimeCodeCredentialIdentity(
                serviceIdentifier: ASCredentialServiceIdentifier(identifier: domain, type: .domain),
                label: "\(account.effectiveIssuer) (\(account.effectiveName))",
                recordIdentifier: account.id.uuidString
            )
        }
    }

    /// No-op unless Sesame is turned on in Settings › General › AutoFill & Passwords.
    static func replace(with accounts: [Account]) async throws {
        let store = ASCredentialIdentityStore.shared
        guard await store.state().isEnabled else { return }
        try await store.replaceCredentialIdentities(make(for: accounts))
    }
}
