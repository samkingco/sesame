import Foundation

struct SearchSection: Identifiable {
    let id: UUID
    let profileName: String
    let hits: [SearchHit]
}
