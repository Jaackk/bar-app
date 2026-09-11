import Foundation

public struct StockItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var venueID: String
    public var category: String
    public var bottleSize: Double?
    public var currentStock: Double
    public var parLevel: Double
    public var unit: String
    public var notes: String
    public var isSample: Bool

    public init(id: String, name: String, venueID: String = "", category: String = "Spirits", bottleSize: Double? = nil, currentStock: Double = 0, parLevel: Double = 0, unit: String = "bottles", notes: String = "", isSample: Bool = false) {
        self.id = id
        self.name = name
        self.venueID = venueID
        self.category = category
        self.bottleSize = bottleSize
        self.currentStock = currentStock
        self.parLevel = parLevel
        self.unit = unit
        self.notes = notes
        self.isSample = isSample
    }

    enum CodingKeys: String, CodingKey { case id, name, venueID, category, bottleSize, currentStock, parLevel, unit, notes, isSample }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        venueID = try c.value(String.self, for: .venueID, default: "")
        category = try c.value(String.self, for: .category, default: "Spirits")
        bottleSize = try c.decodeIfPresent(Double.self, forKey: .bottleSize)
        currentStock = try c.value(Double.self, for: .currentStock, default: 0)
        parLevel = try c.value(Double.self, for: .parLevel, default: 0)
        unit = try c.value(String.self, for: .unit, default: "bottles")
        notes = try c.value(String.self, for: .notes, default: "")
        isSample = try c.value(Bool.self, for: .isSample, default: false)
    }

    public var requiredStock: Double { StockCalculator.required(current: currentStock, par: parLevel) }
    public var orderQuantity: Int { StockCalculator.wholeQuantity(requiredStock) }
}
