import Foundation

struct BackupPayload: Codable, Hashable {
    let payloadVersion: Int
    let createdAt: Date
    let profiles: [BackupProfile]
    let accounts: [BackupAccount]
}

struct BackupAccount: Codable, Hashable {
    let id: UUID
    let profileId: UUID
    let issuer: String
    let displayIssuer: String?
    let name: String
    let displayName: String?
    let type: OTPType
    let algorithm: OTPAlgorithm
    let digits: Int
    let period: Int
    let counter: Int
    let createdAt: Date
    let secret: String
    let website: String?

    var effectiveIssuer: String {
        displayIssuer ?? issuer
    }

    var effectiveName: String {
        displayName ?? name
    }
}

struct BackupProfile: Codable, Hashable {
    let id: UUID
    let name: String
    let color: String?
    let sortOrder: Int
}
