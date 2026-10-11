import Foundation

/// Ranks accounts against a search query. Shared by the account list and Siri.
///
/// Substring matches always rank first: issuer prefix > issuer contains >
/// name prefix > name contains. When the query isn't a substring of either,
/// it falls back to fuzzy subsequence matching, so "gh" finds GitHub and
/// "aws" finds Amazon Web Services.
enum SearchMatcher {
    static func hits(for query: String, in accounts: [Account]) -> [SearchHit] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        // Fuzzy matching ignores spaces and punctuation, so "git hub" finds GitHub.
        let fuzzyQuery = query.filter { $0.isLetter || $0.isNumber }.map(fold)

        return accounts
            .compactMap { rank($0, query: query, fuzzyQuery: fuzzyQuery) }
            .sorted { a, b in
                if a.tier != b.tier { return a.tier > b.tier }
                if a.quality != b.quality { return a.quality > b.quality }
                // Equal ranks stay alphabetical, like the main list.
                return a.hit.account.precedesAlphabetically(b.hit.account)
            }
            .map(\.hit)
    }

    // MARK: - Ranking

    private struct Ranked {
        let hit: SearchHit
        let tier: Int
        let quality: Int
    }

    private static func rank(_ account: Account, query: String, fuzzyQuery: [String]) -> Ranked? {
        let issuer = account.effectiveIssuer
        let name = account.effectiveName

        let issuerRange = substringRange(of: query, in: issuer)
        let nameRange = substringRange(of: query, in: name)

        if issuerRange != nil || nameRange != nil {
            let tier = if issuerRange?.lowerBound == 0 { 6 }
            else if issuerRange != nil { 5 }
            else if nameRange?.lowerBound == 0 { 4 }
            else { 3 }

            let hit = SearchHit(
                account: account,
                issuerHighlight: issuerRange.map { .init(ranges: [$0]) },
                nameHighlight: nameRange.map { .init(ranges: [$0]) }
            )
            return Ranked(hit: hit, tier: tier, quality: 0)
        }

        if let match = fuzzyMatch(fuzzyQuery, in: issuer) {
            let hit = SearchHit(account: account, issuerHighlight: .init(ranges: match.ranges))
            return Ranked(hit: hit, tier: 2, quality: match.quality)
        }

        if let match = fuzzyMatch(fuzzyQuery, in: name) {
            let hit = SearchHit(account: account, nameHighlight: .init(ranges: match.ranges))
            return Ranked(hit: hit, tier: 1, quality: match.quality)
        }

        return nil
    }

    private static func substringRange(of query: String, in text: String) -> Range<Int>? {
        guard let range = text.localizedStandardRange(of: query) else { return nil }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        return lower ..< lower + text.distance(from: range.lowerBound, to: range.upperBound)
    }

    // MARK: - Fuzzy matching

    private struct FuzzyMatch {
        let ranges: [Range<Int>]
        let quality: Int
    }

    /// Matches when every query character appears in `text` in order and the
    /// first one starts a word. Higher quality for word starts and runs of
    /// consecutive characters, lower for gaps between them.
    private static func fuzzyMatch(_ query: [String], in text: String) -> FuzzyMatch? {
        guard query.count >= 2 else { return nil }
        let chars = Array(text)
        let folded = chars.map(fold)
        guard isSubsequence(query[...], of: folded[...]) else { return nil }

        var positions: [Int] = []
        var from = 0
        for (i, q) in query.enumerated() {
            let rest = query[(i + 1)...]
            let candidates = (from ..< folded.count).filter {
                folded[$0] == q && isSubsequence(rest, of: folded[($0 + 1)...])
            }

            // Prefer continuing a run, then the start of a word, then the earliest occurrence.
            let pick: Int? = if i > 0, candidates.first == from { from }
            else if let start = candidates.first(where: { isWordStart($0, in: chars) }) { start }
            else if i > 0 { candidates.first }
            else { nil }

            guard let pick else { return nil }
            positions.append(pick)
            from = pick + 1
        }

        var quality = 0
        for (n, position) in positions.enumerated() {
            if isWordStart(position, in: chars) { quality += 3 }
            if n > 0 {
                let gap = position - positions[n - 1] - 1
                quality += gap == 0 ? 2 : -gap
            }
        }

        return FuzzyMatch(ranges: runs(of: positions), quality: quality)
    }

    private static func isSubsequence(_ query: ArraySlice<String>, of text: ArraySlice<String>) -> Bool {
        var remaining = query
        for char in text where remaining.first == char {
            remaining.removeFirst()
        }
        return remaining.isEmpty
    }

    /// After a space or punctuation, a lowercase-to-uppercase change ("GitHub"),
    /// or a digit-to-letter change ("1Password").
    private static func isWordStart(_ index: Int, in chars: [Character]) -> Bool {
        guard index > 0 else { return true }
        let prev = chars[index - 1]
        let char = chars[index]
        if !prev.isLetter, !prev.isNumber { return true }
        if prev.isLowercase, char.isUppercase { return true }
        return prev.isNumber != char.isNumber
    }

    /// Collapses adjacent positions into ranges: [0, 1, 2, 5] → [0..<3, 5..<6].
    private static func runs(of positions: [Int]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        for position in positions {
            if let last = runs.last, last.upperBound == position {
                runs[runs.count - 1] = last.lowerBound ..< position + 1
            } else {
                runs.append(position ..< position + 1)
            }
        }
        return runs
    }

    /// Folds one character at a time so positions line up with the original text.
    private static func fold(_ char: Character) -> String {
        String(char).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
