import Foundation

struct SearchHit: Identifiable {
    var id: UUID {
        account.id
    }

    let account: Account
    let issuerHighlight: Highlight?
    let nameHighlight: Highlight?

    init(account: Account, issuerHighlight: Highlight? = nil, nameHighlight: Highlight? = nil) {
        self.account = account
        self.issuerHighlight = issuerHighlight
        self.nameHighlight = nameHighlight
    }

    struct Highlight {
        /// Character offsets into the matched text. Fuzzy matches can have several.
        let ranges: [Range<Int>]
    }
}
