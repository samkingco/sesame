import ActivityKit
import Foundation

struct CopiedCodeAttributes: ActivityAttributes {
    let issuer: String
    let name: String

    struct ContentState: Codable, Hashable {
        let code: String
        let colorState: CodeColorState
        let expiresAt: Date
    }
}
