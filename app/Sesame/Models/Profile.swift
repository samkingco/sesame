import Foundation
import SwiftData

@Model
final class Profile: Codable {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String?
    var createdAt: Date
    var sortOrder: Int = 0

    static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    static let defaultColor = "#3B82F6"

    static let colorPalette: [String] = [
        "#3B82F6", "#6366F1", "#8B5CF6", "#D946EF",
        "#EC4899", "#EF4444", "#F97316", "#EAB308",
        "#84CC16", "#22C55E", "#14B8A6", "#06B6D4",
    ]

    var isDefault: Bool {
        id == Self.defaultID
    }

    init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    static func makeDefault() -> Profile {
        Profile(id: defaultID, name: "Personal", color: defaultColor, sortOrder: 0)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, color, createdAt, sortOrder
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(sortOrder, forKey: .sortOrder)
    }
}
