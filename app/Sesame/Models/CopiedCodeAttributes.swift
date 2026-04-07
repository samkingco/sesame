import ActivityKit
import Foundation

struct CopiedCodeAttributes: ActivityAttributes {
    let issuer: String

    struct ContentState: Codable, Hashable {
        let code: String
        let nextCode: String?
        let expiresAt: Date
    }
}
