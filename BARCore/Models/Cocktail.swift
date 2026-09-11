import Foundation

public struct Cocktail: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var venueID: String?
    public var subtitle: String
    public var description: String
    public var venueSpecific: Bool
    public var category: String
    public var baseSpirit: String
    public var flavourTags: [String]
    public var ingredients: [Ingredient]
    public var method: String
    public var glass: String
    public var ice: String
    public var garnish: String
    public var prepInstructions: [String]
    public var serviceNotes: String
    public var allergens: [String]
    public var imageName: String
    public var isPopular: Bool
    public var isActive: Bool
    public var isSample: Bool
    public var variations: [String]
    public var overridesCocktailID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, name: String, venueID: String? = nil, subtitle: String = "", description: String = "", venueSpecific: Bool = false, category: String = "Cocktail", baseSpirit: String = "", flavourTags: [String] = [], ingredients: [Ingredient] = [], method: String = "", glass: String = "", ice: String = "", garnish: String = "", prepInstructions: [String] = [], serviceNotes: String = "", allergens: [String] = [], imageName: String = "", isPopular: Bool = false, isActive: Bool = true, isSample: Bool = false, variations: [String] = [], overridesCocktailID: String? = nil, createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.name = name
        self.venueID = venueID
        self.subtitle = subtitle
        self.description = description
        self.venueSpecific = venueSpecific
        self.category = category
        self.baseSpirit = baseSpirit
        self.flavourTags = flavourTags
        self.ingredients = ingredients
        self.method = method
        self.glass = glass
        self.ice = ice
        self.garnish = garnish
        self.prepInstructions = prepInstructions
        self.serviceNotes = serviceNotes
        self.allergens = allergens
        self.imageName = imageName
        self.isPopular = isPopular
        self.isActive = isActive
        self.isSample = isSample
        self.variations = variations
        self.overridesCocktailID = overridesCocktailID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case id, name, venueID, subtitle, description, venueSpecific, category, baseSpirit, flavourTags, ingredients, method, glass, ice, garnish, prepInstructions, serviceNotes, allergens, imageName, isPopular, isActive, isSample, variations, overridesCocktailID, createdAt, updatedAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        venueID = try c.decodeIfPresent(String.self, forKey: .venueID)
        subtitle = try c.value(String.self, for: .subtitle, default: "")
        description = try c.value(String.self, for: .description, default: "")
        venueSpecific = try c.value(Bool.self, for: .venueSpecific, default: false)
        category = try c.value(String.self, for: .category, default: "Cocktail")
        baseSpirit = try c.value(String.self, for: .baseSpirit, default: "")
        flavourTags = try c.value([String].self, for: .flavourTags, default: [])
        ingredients = try c.value([Ingredient].self, for: .ingredients, default: [])
        method = try c.value(String.self, for: .method, default: "")
        glass = try c.value(String.self, for: .glass, default: "")
        ice = try c.value(String.self, for: .ice, default: "")
        garnish = try c.value(String.self, for: .garnish, default: "")
        prepInstructions = try c.value([String].self, for: .prepInstructions, default: [])
        serviceNotes = try c.value(String.self, for: .serviceNotes, default: "")
        allergens = try c.value([String].self, for: .allergens, default: [])
        imageName = try c.value(String.self, for: .imageName, default: "")
        isPopular = try c.value(Bool.self, for: .isPopular, default: false)
        isActive = try c.value(Bool.self, for: .isActive, default: true)
        isSample = try c.value(Bool.self, for: .isSample, default: false)
        variations = try c.value([String].self, for: .variations, default: [])
        overridesCocktailID = try c.decodeIfPresent(String.self, forKey: .overridesCocktailID)
        createdAt = try c.value(Date.self, for: .createdAt, default: Date(timeIntervalSince1970: 0))
        updatedAt = try c.value(Date.self, for: .updatedAt, default: Date(timeIntervalSince1970: 0))
    }
}
