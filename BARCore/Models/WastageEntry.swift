import Foundation

/// A quick, venue-scoped service record. Wastage is deliberately separate from
/// stock counts: it records what happened without silently changing a count.
public struct WastageEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var venueID: String
    public var itemName: String
    public var quantity: Double
    public var unit: String
    public var reason: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, venueID: String, itemName: String, quantity: Double, unit: String, reason: String = "Spillage", createdAt: Date = Date()) {
        self.id = id
        self.venueID = venueID
        self.itemName = itemName
        self.quantity = quantity
        self.unit = unit
        self.reason = reason
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey { case id, venueID, itemName, quantity, unit, reason, createdAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(String.self, for: .id, default: UUID().uuidString)
        venueID = try c.decode(String.self, forKey: .venueID)
        itemName = try c.decode(String.self, forKey: .itemName)
        quantity = try c.decode(Double.self, forKey: .quantity)
        unit = try c.value(String.self, for: .unit, default: "items")
        reason = try c.value(String.self, for: .reason, default: "Spillage")
        createdAt = try c.value(Date.self, for: .createdAt, default: Date())
    }
}
