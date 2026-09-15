import Foundation

public struct Product: Codable, Hashable, Sendable, Identifiable {
    public var imageData: Data? = nil
    public var id: String
    public var venueID: String
    public var name: String
    public var brand: String
    public var category: String
    public var unit: String
    public var defaultOrderUnit: String
    public var imageName: String
    public var isActive: Bool
    public var productType: String
    public var aliases: [String] = []
    public var sourceURL: String?
    public var sourcePage: Int?
    public var menuDetails: String
    public init(id: String = UUID().uuidString, venueID: String, name: String, brand: String = "", category: String = "Other", unit: String = "item", defaultOrderUnit: String = "item", imageName: String = "", isActive: Bool = true, productType: String = "", aliases: [String] = [], sourceURL: String? = nil, sourcePage: Int? = nil, menuDetails: String = "") {
        self.id = id; self.venueID = venueID; self.name = name; self.brand = brand; self.category = category
        self.unit = unit; self.defaultOrderUnit = defaultOrderUnit; self.imageName = imageName; self.isActive = isActive
        self.productType = productType; self.aliases = aliases; self.sourceURL = sourceURL; self.sourcePage = sourcePage; self.menuDetails = menuDetails
    }
    enum CodingKeys: String, CodingKey { case imageData, id, venueID, name, brand, category, unit, defaultOrderUnit, imageName, isActive, productType, aliases, sourceURL, sourcePage, menuDetails }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        venueID = try c.decode(String.self, forKey: .venueID)
        name = try c.decode(String.self, forKey: .name)
        brand = try c.value(String.self, for: .brand, default: "")
        category = try c.value(String.self, for: .category, default: "Other")
        unit = try c.value(String.self, for: .unit, default: "item")
        defaultOrderUnit = try c.value(String.self, for: .defaultOrderUnit, default: unit)
        imageName = try c.value(String.self, for: .imageName, default: "")
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        isActive = try c.value(Bool.self, for: .isActive, default: true)
        productType = try c.value(String.self, for: .productType, default: "")
        aliases = try c.value([String].self, for: .aliases, default: [])
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        sourcePage = try c.decodeIfPresent(Int.self, forKey: .sourcePage)
        menuDetails = try c.value(String.self, for: .menuDetails, default: "")
    }
}
public enum StockListKind: String, Codable, CaseIterable, Sendable {
    case restock, order
    public var title: String { self == .restock ? "Restock" : "Stock Order" }
    public var heading: String { self == .restock ? "Restock List" : "Order List" }
}
public struct StockListItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var venueID: String
    public var kind: StockListKind
    public var productID: String?
    public var name: String
    public var quantity: Int
    public var unit: String
    public init(id: String = UUID().uuidString, venueID: String, kind: StockListKind, productID: String? = nil, name: String, quantity: Int = 1, unit: String = "item") {
        self.id = id; self.venueID = venueID; self.kind = kind; self.productID = productID
        self.name = name; self.quantity = quantity; self.unit = unit
    }
}
public enum StockListService {
    public static let categories = ["Vodka", "Gin", "Rum", "Tequila / Mezcal", "Whisky / Whiskey", "Brandy / Cognac", "Liqueurs / Aperitifs", "Wine", "Sparkling / Champagne", "Beer / Cider", "Non-Alcoholic", "Soft Drinks", "Mixers", "Juices", "Syrups / Cordials", "Purees", "Bitters", "Garnishes", "Fresh Fruit", "Fresh Herbs", "Prep", "Other"]
    public static func search(_ products: [Product], venueID: String, query: String, category: String? = nil) -> [Product] {
        let terms = normalized(query).split(separator: " ")
        return products.filter { p in
            let haystack = normalized(([p.name, p.brand, p.category, p.productType] + p.aliases).joined(separator: " "))
            return p.isActive && p.venueID == venueID && (category == nil || category == p.category) && terms.allSatisfy { SearchService.matches(String($0), in: haystack) }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private static func normalized(_ text: String) -> String { text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_GB")) }
    public static func add(_ product: Product, kind: StockListKind, to items: inout [StockListItem]) {
        guard product.isActive else { return }
        if let i = items.firstIndex(where: { $0.venueID == product.venueID && $0.kind == kind && $0.productID == product.id }) {
            items[i].quantity = min(items[i].quantity + 1, 100_000)
        } else {
            items.append(StockListItem(venueID: product.venueID, kind: kind, productID: product.id, name: product.name, unit: kind == .order ? product.defaultOrderUnit : product.unit))
        }
    }
    public static func setQuantity(_ quantity: Int, id: String, venueID: String, in items: inout [StockListItem]) {
        guard let i = items.firstIndex(where: { $0.id == id && $0.venueID == venueID }) else { return }
        if quantity <= 0 { items.remove(at: i) } else { items[i].quantity = min(quantity, 100_000) }
    }
    public static func clear(_ kind: StockListKind, venueID: String, in items: inout [StockListItem]) { items.removeAll { $0.kind == kind && $0.venueID == venueID } }
    public static func text(_ items: [StockListItem], kind: StockListKind, venueID: String) -> String {
        let lines = items.filter { $0.kind == kind && $0.venueID == venueID }.map { "\($0.name) x\($0.quantity)" }
        return (kind == .restock ? "RESTOCK" : "STOCK ORDER") + "\n\n" + lines.joined(separator: "\n")
    }
}
