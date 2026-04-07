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
            accounts.scoredByRelevance(for: searchText)
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

extension [Account] {
    func sortedAlphabetically() -> [Account] {
        sorted { a, b in
            let issuerCmp = a.effectiveIssuer
                .localizedCaseInsensitiveCompare(b.effectiveIssuer)
            if issuerCmp != .orderedSame { return issuerCmp == .orderedAscending }
            return a.effectiveName
                .localizedCaseInsensitiveCompare(b.effectiveName) == .orderedAscending
        }
    }

    func scoredByRelevance(for query: String) -> [SearchHit] {
        compactMap { account -> (SearchHit, Int)? in
            let issuer = account.effectiveIssuer
            let name = account.effectiveName

            let issuerRange = issuer.localizedStandardRange(of: query)
            let nameRange = name.localizedStandardRange(of: query)

            guard issuerRange != nil || nameRange != nil else { return nil }

            // Issuer prefix > issuer contains > name prefix > name contains
            let score = if issuerRange?.lowerBound == issuer.startIndex { 4 }
            else if issuerRange != nil { 3 }
            else if nameRange?.lowerBound == name.startIndex { 2 }
            else { 1 }

            let hit = SearchHit(
                account: account,
                issuerHighlight: issuerRange.map { .init(from: $0, in: issuer) },
                nameHighlight: nameRange.map { .init(from: $0, in: name) }
            )
            return (hit, score)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }
}
