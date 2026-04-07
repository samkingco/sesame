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
        let offset: Int
        let length: Int

        init(offset: Int, length: Int) {
            self.offset = offset
            self.length = length
        }

        init(from range: Range<String.Index>, in text: String) {
            offset = text.distance(from: text.startIndex, to: range.lowerBound)
            length = text.distance(from: range.lowerBound, to: range.upperBound)
        }
    }
}
