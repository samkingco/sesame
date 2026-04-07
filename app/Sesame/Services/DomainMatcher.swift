import Foundation

enum DomainMatcher {
    /// Returns true when the requested domain exactly matches the stored
    /// website or is a subdomain of it. Both sides are compared
    /// case-insensitively.
    ///
    /// Examples:
    /// - `matches(domain: "github.com", website: "github.com")` → true
    /// - `matches(domain: "sub.github.com", website: "github.com")` → true
    /// - `matches(domain: "GitHub.com", website: "github.com")` → true
    /// - `matches(domain: "evil-github.com", website: "github.com")` → false
    static func matches(domain: String, website: String) -> Bool {
        let d = domain.lowercased()
        let w = website.lowercased()
        return d == w || d.hasSuffix(".\(w)")
    }

    /// Filters accounts that match any of the given domain identifiers.
    /// Only includes non-deleted accounts that have a website set.
    static func filterAccounts(
        _ accounts: [Account],
        forDomains domains: [String]
    ) -> [Account] {
        let requestedDomains = Set(domains.map { $0.lowercased() })
        guard !requestedDomains.isEmpty else { return accounts }

        return accounts.filter { account in
            guard account.deletedAt == nil else { return false }
            guard let website = account.website else { return false }
            return requestedDomains.contains { matches(domain: $0, website: website) }
        }
    }
}
