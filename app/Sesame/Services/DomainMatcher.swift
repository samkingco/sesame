import Foundation

enum DomainMatcher {
    /// "https://www.GitHub.com/login" → "github.com"
    static func normalizedDomain(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        let url = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var host = URLComponents(string: url)?.host, !host.isEmpty else { return nil }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    /// Returns true when the requested domain exactly matches the stored
    /// website or is a subdomain of it.
    ///
    /// Examples:
    /// - `matches(domain: "github.com", website: "github.com")` → true
    /// - `matches(domain: "sub.github.com", website: "github.com")` → true
    /// - `matches(domain: "GitHub.com", website: "github.com")` → true
    /// - `matches(domain: "https://github.com/login", website: "www.github.com")` → true
    /// - `matches(domain: "evil-github.com", website: "github.com")` → false
    static func matches(domain: String, website: String) -> Bool {
        guard let d = normalizedDomain(domain), let w = normalizedDomain(website) else { return false }
        return d == w || d.hasSuffix(".\(w)")
    }

    /// Filters accounts that match any of the given domain identifiers.
    /// Only includes non-deleted accounts that have a website set.
    static func filterAccounts(
        _ accounts: [Account],
        forDomains domains: [String]
    ) -> [Account] {
        let active = accounts.filter { $0.deletedAt == nil }
        guard !domains.isEmpty else { return active }

        return active.filter { account in
            guard let website = account.website else { return false }
            return domains.contains { matches(domain: $0, website: website) }
        }
    }
}
