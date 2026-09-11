import Foundation

public struct PrepItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var venueID: String
    public var category: String
    public var currentAmount: Double
    public var targetAmount: Double
    public var recipeYieldAmount: Double
    public var unit: MeasurementUnit
    public var recipe: [Ingredient]
    public var method: [String]
    public var storageInstructions: String
    public var shelfLife: String
    public var lastPreparedDate: Date?
    public var completed: Bool
    public var notes: String
    public var isSample: Bool

    public init(id: String, name: String, venueID: String = "", category: String = "Prep", currentAmount: Double = 0, targetAmount: Double = 0, recipeYieldAmount: Double = 1, unit: MeasurementUnit = .litre, recipe: [Ingredient] = [], method: [String] = [], storageInstructions: String = "", shelfLife: String = "", lastPreparedDate: Date? = nil, completed: Bool = false, notes: String = "", isSample: Bool = false) {
        self.id = id
        self.name = name
        self.venueID = venueID
        self.category = category
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.recipeYieldAmount = recipeYieldAmount
        self.unit = unit
        self.recipe = recipe
        self.method = method
        self.storageInstructions = storageInstructions
        self.shelfLife = shelfLife
        self.lastPreparedDate = lastPreparedDate
        self.completed = completed
        self.notes = notes
        self.isSample = isSample
    }

    enum CodingKeys: String, CodingKey { case id, name, venueID, category, currentAmount, targetAmount, recipeYieldAmount, unit, recipe, method, storageInstructions, shelfLife, lastPreparedDate, completed, notes, isSample }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        venueID = try c.value(String.self, for: .venueID, default: "")
        category = try c.value(String.self, for: .category, default: "Prep")
        currentAmount = try c.value(Double.self, for: .currentAmount, default: 0)
        targetAmount = try c.value(Double.self, for: .targetAmount, default: 0)
        recipeYieldAmount = try c.value(Double.self, for: .recipeYieldAmount, default: max(targetAmount, 1))
        unit = try c.value(MeasurementUnit.self, for: .unit, default: .litre)
        recipe = try c.value([Ingredient].self, for: .recipe, default: [])
        method = try c.value([String].self, for: .method, default: [])
        storageInstructions = try c.value(String.self, for: .storageInstructions, default: "")
        shelfLife = try c.value(String.self, for: .shelfLife, default: "")
        lastPreparedDate = try c.decodeIfPresent(Date.self, forKey: .lastPreparedDate)
        completed = try c.value(Bool.self, for: .completed, default: false)
        notes = try c.value(String.self, for: .notes, default: "")
        isSample = try c.value(Bool.self, for: .isSample, default: false)
    }

    public var requiredAmount: Double { max(targetAmount - currentAmount, 0) }
    public var progress: Double { targetAmount > 0 ? min(max(currentAmount / targetAmount, 0), 1) : 1 }
    public mutating func markComplete(at date: Date = Date()) { currentAmount = max(currentAmount, targetAmount); completed = true; lastPreparedDate = date }
}
