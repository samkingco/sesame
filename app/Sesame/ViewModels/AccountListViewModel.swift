import Foundation

@MainActor @Observable
final class AccountListViewModel {
    var selectedProfileId: UUID = Profile.defaultID

    // MARK: - Filtering

    func accountsForCurrentProfile(from accounts: [Account]) -> [Account] {
        accounts
            .filter { $0.profileId == selectedProfileId }
            .sortedAlphabetically()
    }

    func searchSections(
        from accounts: [Account],
        profiles: [Profile],
        searchText: String
    ) -> [SearchSection] {
        let hits: [SearchHit] = if searchText.isEmpty {
            accounts.sortedAlphabetically().map { SearchHit(account: $0) }
        } else {
            SearchMatcher.hits(for: searchText, in: accounts)
        }

        let current = hits.filter { $0.account.profileId == selectedProfileId }
        let otherByProfile = Dictionary(
            grouping: hits.filter { $0.account.profileId != selectedProfileId }
        ) { $0.account.profileId }

        var sections: [SearchSection] = []

        if !current.isEmpty {
            sections.append(SearchSection(
                id: selectedProfileId,
                profileName: profileName(for: selectedProfileId, in: profiles),
                hits: current
            ))
        }

        for (profileId, sectionHits) in otherByProfile.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            sections.append(SearchSection(
                id: profileId,
                profileName: profileName(for: profileId, in: profiles),
                hits: sectionHits
            ))
        }

        return sections
    }

    func profileName(for id: UUID, in profiles: [Profile]) -> String {
        profiles.first { $0.id == id }?.name ?? "Personal"
    }
}

extension Account {
    /// Issuer, then name, case-insensitively.
    func precedesAlphabetically(_ other: Account) -> Bool {
        let issuerCmp = effectiveIssuer.localizedCaseInsensitiveCompare(other.effectiveIssuer)
        if issuerCmp != .orderedSame { return issuerCmp == .orderedAscending }
        return effectiveName.localizedCaseInsensitiveCompare(other.effectiveName) == .orderedAscending
    }
}

extension [Account] {
    func sortedAlphabetically() -> [Account] {
        sorted { $0.precedesAlphabetically($1) }
    }
}
