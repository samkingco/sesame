import Foundation
import SwiftData

@Model
final class Account: Codable {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var issuer: String
    var displayIssuer: String?
    var name: String
    var displayName: String?
    var type: OTPType
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int
    var counter: Int
    var createdAt: Date
    var deletedAt: Date?
    var website: String?

    var effectiveIssuer: String {
        displayIssuer ?? issuer
    }

    var effectiveName: String {
        displayName ?? name
    }

    init(
        id: UUID = UUID(),
        profileId: UUID,
        issuer: String,
        displayIssuer: String? = nil,
        name: String,
        displayName: String? = nil,
        type: OTPType = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: Int = 0,
        createdAt: Date = .now,
        deletedAt: Date? = nil,
        website: String? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.issuer = issuer
        self.displayIssuer = displayIssuer
        self.name = name
        self.displayName = displayName
        self.type = type
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.website = website
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, profileId, issuer, displayIssuer, name, displayName
        case type, algorithm, digits, period, counter, createdAt, deletedAt, website
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        profileId = try c.decode(UUID.self, forKey: .profileId)
        issuer = try c.decode(String.self, forKey: .issuer)
        displayIssuer = try c.decodeIfPresent(String.self, forKey: .displayIssuer)
        name = try c.decode(String.self, forKey: .name)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        type = try c.decode(OTPType.self, forKey: .type)
        algorithm = try c.decode(OTPAlgorithm.self, forKey: .algorithm)
        digits = try c.decode(Int.self, forKey: .digits)
        period = try c.decode(Int.self, forKey: .period)
        counter = try c.decode(Int.self, forKey: .counter)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        website = try c.decodeIfPresent(String.self, forKey: .website)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(profileId, forKey: .profileId)
        try c.encode(issuer, forKey: .issuer)
        try c.encodeIfPresent(displayIssuer, forKey: .displayIssuer)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(displayName, forKey: .displayName)
        try c.encode(type, forKey: .type)
        try c.encode(algorithm, forKey: .algorithm)
        try c.encode(digits, forKey: .digits)
        try c.encode(period, forKey: .period)
        try c.encode(counter, forKey: .counter)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try c.encodeIfPresent(website, forKey: .website)
    }
}
