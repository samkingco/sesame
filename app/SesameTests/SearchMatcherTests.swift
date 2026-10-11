import Foundation
@testable import Sesame
import Testing

@MainActor
struct SearchMatcherTests {
    private func makeAccount(_ issuer: String, name: String = "user@example.com") -> Account {
        Account(profileId: Profile.defaultID, issuer: issuer, name: name)
    }

    private func issuers(_ hits: [SearchHit]) -> [String] {
        hits.map(\.account.issuer)
    }

    // MARK: - Substring matches

    @Test("Substring matches rank issuer prefix first, then alphabetically")
    func substringRanking() {
        let accounts = [
            makeAccount("Slack", name: "github-bot"),
            makeAccount("GitLab"),
            makeAccount("Legit"),
            makeAccount("GitHub"),
        ]

        let hits = SearchMatcher.hits(for: "git", in: accounts)

        #expect(issuers(hits) == ["GitHub", "GitLab", "Legit", "Slack"])
    }

    @Test("Trailing whitespace from keyboard suggestions is ignored")
    func trimsWhitespace() {
        let hits = SearchMatcher.hits(for: "github ", in: [makeAccount("GitHub")])

        #expect(hits.count == 1)
        #expect(hits.first?.issuerHighlight?.ranges == [0 ..< 6])
    }

    @Test("Whitespace-only query matches nothing")
    func whitespaceOnlyQuery() {
        #expect(SearchMatcher.hits(for: "  ", in: [makeAccount("GitHub")]).isEmpty)
    }

    // MARK: - Fuzzy matches

    @Test("Fuzzy matches word starts across camelCase", arguments: [
        ("gh", "GitHub", [0 ..< 1, 3 ..< 4]),
        ("pp", "PayPal", [0 ..< 1, 3 ..< 4]),
        ("aws", "Amazon Web Services", [0 ..< 1, 7 ..< 8, 11 ..< 12]),
        ("pw", "1Password", [1 ..< 2, 5 ..< 6]),
    ])
    func fuzzyWordStarts(query: String, issuer: String, ranges: [Range<Int>]) {
        let hits = SearchMatcher.hits(for: query, in: [makeAccount(issuer)])

        #expect(hits.count == 1)
        #expect(hits.first?.issuerHighlight?.ranges == ranges)
    }

    @Test("Fuzzy matches abbreviations with consecutive runs merged")
    func fuzzyAbbreviation() {
        let hits = SearchMatcher.hits(for: "amzn", in: [makeAccount("Amazon")])

        #expect(hits.first?.issuerHighlight?.ranges == [0 ..< 2, 3 ..< 4, 5 ..< 6])
    }

    @Test("Fuzzy ignores spaces and punctuation in the query")
    func fuzzyIgnoresSpaces() {
        let hits = SearchMatcher.hits(for: "git hub", in: [makeAccount("GitHub")])

        #expect(hits.first?.issuerHighlight?.ranges == [0 ..< 6])
    }

    @Test("Fuzzy ignores case and diacritics")
    func fuzzyFoldsDiacritics() {
        let hits = SearchMatcher.hits(for: "uh", in: [makeAccount("Über Health")])

        #expect(hits.first?.issuerHighlight?.ranges == [0 ..< 1, 5 ..< 6])
    }

    @Test("Fuzzy requires the first character to start a word")
    func fuzzyRequiresWordStart() {
        #expect(SearchMatcher.hits(for: "tb", in: [makeAccount("GitHub")]).isEmpty)
    }

    @Test("Fuzzy matches the account name when the issuer doesn't match")
    func fuzzyMatchesName() {
        let hits = SearchMatcher.hits(for: "gml", in: [makeAccount("Google", name: "sam@gmail.com")])

        #expect(hits.first?.issuerHighlight == nil)
        #expect(hits.first?.nameHighlight?.ranges == [4 ..< 6, 8 ..< 9])
    }

    // MARK: - Fuzzy ranking

    @Test("Substring matches rank above fuzzy matches")
    func substringBeforeFuzzy() {
        let accounts = [makeAccount("GitHub"), makeAccount("Ghost")]

        #expect(issuers(SearchMatcher.hits(for: "gh", in: accounts)) == ["Ghost", "GitHub"])
    }

    @Test("Tighter word-start matches rank above looser ones")
    func fuzzyQualityRanking() {
        let accounts = [makeAccount("Gather"), makeAccount("GitHub")]

        #expect(issuers(SearchMatcher.hits(for: "gh", in: accounts)) == ["GitHub", "Gather"])
    }

    @Test("Fuzzy issuer matches rank above fuzzy name matches")
    func fuzzyIssuerBeforeName() {
        let accounts = [
            makeAccount("Zoom", name: "greg.hall@example.com"),
            makeAccount("Gather"),
        ]

        #expect(issuers(SearchMatcher.hits(for: "gh", in: accounts)) == ["Gather", "Zoom"])
    }
}
