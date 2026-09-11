import Foundation

public struct UserPreferences: Codable, Hashable, Sendable {
    public var employeeName: String
    public var venueID: String
    public var units: String
    public var defaultWastage: Double
    public var favouriteCocktailIDs: Set<String>
    public var favouriteWineIDs: Set<String>
    public var recentItems: [RecentItem]

    public init(employeeName: String = "Bartender", venueID: String = "", units: String = "ml", defaultWastage: Double = 3, favouriteCocktailIDs: Set<String> = [], favouriteWineIDs: Set<String> = [], recentItems: [RecentItem] = []) {
        self.employeeName = employeeName
        self.venueID = venueID
        self.units = units
        self.defaultWastage = defaultWastage
        self.favouriteCocktailIDs = favouriteCocktailIDs
        self.favouriteWineIDs = favouriteWineIDs
        self.recentItems = recentItems
    }

    enum CodingKeys: String, CodingKey { case employeeName, venueID, units, defaultWastage, favouriteCocktailIDs, favouriteWineIDs, recentItems }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        employeeName = try c.value(String.self, for: .employeeName, default: "Bartender")
        venueID = try c.value(String.self, for: .venueID, default: "")
        units = try c.value(String.self, for: .units, default: "ml")
        defaultWastage = try c.value(Double.self, for: .defaultWastage, default: 3)
        favouriteCocktailIDs = try c.value(Set<String>.self, for: .favouriteCocktailIDs, default: [])
        favouriteWineIDs = try c.value(Set<String>.self, for: .favouriteWineIDs, default: [])
        recentItems = try c.value([RecentItem].self, for: .recentItems, default: [])
    }

    public mutating func recordRecent(id: String, kind: RecentKind, at date: Date = Date()) {
        recentItems.removeAll { $0.id == id && $0.kind == kind }
        recentItems.insert(RecentItem(id: id, kind: kind, viewedAt: date), at: 0)
        recentItems = Array(recentItems.prefix(20))
    }
}
