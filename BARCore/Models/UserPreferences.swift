import Foundation

public struct UserPreferences: Codable, Hashable, Sendable {
    public var employeeName: String
    public var venueID: String
    public var units: String
    public var defaultWastage: Double
    public var favouriteCocktailIDs: Set<String>
    public var favouriteWineIDs: Set<String>
    public var recentItems: [RecentItem]
    /// Lightweight, on-device signals used to surface fast restock shortcuts.
    public var productUsage: [String: Int]
    public var recentProductIDs: [String]

    public init(employeeName: String = "Bartender", venueID: String = "", units: String = "ml", defaultWastage: Double = 3, favouriteCocktailIDs: Set<String> = [], favouriteWineIDs: Set<String> = [], recentItems: [RecentItem] = [], productUsage: [String: Int] = [:], recentProductIDs: [String] = []) {
        self.employeeName = employeeName
        self.venueID = venueID
        self.units = units
        self.defaultWastage = defaultWastage
        self.favouriteCocktailIDs = favouriteCocktailIDs
        self.favouriteWineIDs = favouriteWineIDs
        self.recentItems = recentItems
        self.productUsage = productUsage
        self.recentProductIDs = recentProductIDs
    }

    enum CodingKeys: String, CodingKey { case employeeName, venueID, units, defaultWastage, favouriteCocktailIDs, favouriteWineIDs, recentItems, productUsage, recentProductIDs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        employeeName = try c.value(String.self, for: .employeeName, default: "Bartender")
        venueID = try c.value(String.self, for: .venueID, default: "")
        units = try c.value(String.self, for: .units, default: "ml")
        defaultWastage = try c.value(Double.self, for: .defaultWastage, default: 3)
        favouriteCocktailIDs = try c.value(Set<String>.self, for: .favouriteCocktailIDs, default: [])
        favouriteWineIDs = try c.value(Set<String>.self, for: .favouriteWineIDs, default: [])
        recentItems = try c.value([RecentItem].self, for: .recentItems, default: [])
        productUsage = try c.value([String: Int].self, for: .productUsage, default: [:])
        recentProductIDs = try c.value([String].self, for: .recentProductIDs, default: [])
    }

    public mutating func recordRecent(id: String, kind: RecentKind, at date: Date = Date()) {
        recentItems.removeAll { $0.id == id && $0.kind == kind }
        recentItems.insert(RecentItem(id: id, kind: kind, viewedAt: date), at: 0)
        recentItems = Array(recentItems.prefix(20))
    }

    public mutating func recordProductUse(_ id: String) {
        productUsage[id, default: 0] = min(productUsage[id, default: 0] + 1, 100_000)
        recentProductIDs.removeAll { $0 == id }
        recentProductIDs.insert(id, at: 0)
        recentProductIDs = Array(recentProductIDs.prefix(20))
    }
}
