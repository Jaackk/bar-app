import Foundation

public struct SavedBatch: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var cocktailID: String
    public var name: String
    public var serves: Int
    public var wastagePercent: Double
    public var createdAt: Date

    public init(id: String = UUID().uuidString, cocktailID: String, name: String, serves: Int, wastagePercent: Double = 3, createdAt: Date = Date()) {
        self.id = id
        self.cocktailID = cocktailID
        self.name = name
        self.serves = serves
        self.wastagePercent = wastagePercent
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey { case id, cocktailID, name, serves, wastagePercent, createdAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(String.self, for: .id, default: UUID().uuidString)
        cocktailID = try c.decode(String.self, forKey: .cocktailID)
        name = try c.decode(String.self, forKey: .name)
        serves = try c.decode(Int.self, forKey: .serves)
        wastagePercent = try c.value(Double.self, for: .wastagePercent, default: 3)
        createdAt = try c.value(Date.self, for: .createdAt, default: Date())
    }
}
