import Foundation

public enum DataValidationError: LocalizedError, Equatable {
    case invalid(String)
    case unsupportedSchema(Int)
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return reason
        case .unsupportedSchema(let version): return "Data version \(version) is not supported by this app. Update BAR before opening this data."
        }
    }
}
public struct SeedLoadReport {
    public let snapshot: AppSnapshot
    public let warnings: [String]
}
public enum SeedLoader {
    public static func load(bundle: Bundle? = nil) throws -> AppSnapshot { try loadWithReport(bundle: bundle).snapshot }

    public static func loadWithReport(bundle: Bundle? = nil) throws -> SeedLoadReport {
        let bundle = bundle ?? .module
        return try loadWithReport(directory: nil, bundle: bundle)
    }
    /// Supports manager-approved, structured seed replacements and command-line validation.
    public static func load(directory: URL) throws -> AppSnapshot { try loadWithReport(directory: directory, bundle: .module).snapshot }

    private static func loadWithReport(directory: URL?, bundle: Bundle) throws -> SeedLoadReport {
        var warnings: [String] = []
        func records<T: Decodable>(_ file: String, as type: T.Type, validate: (T) throws -> Void) throws -> [T] {
            let url = directory?.appendingPathComponent(file + ".json") ?? bundle.url(forResource: file, withExtension: "json")
            guard let url else { throw DataValidationError.invalid("Missing bundled data file: \(file).json") }
            let data = try Data(contentsOf: url)
            guard let raw = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                throw DataValidationError.invalid("\(file).json must contain an array of records.")
            }
            let decoder = makeDecoder()
            return raw.enumerated().compactMap { index, object in
                do {
                    let record = try decoder.decode(T.self, from: JSONSerialization.data(withJSONObject: object))
                    try validate(record)
                    return record
                } catch { warnings.append("\(file).json record \(index + 1) skipped: \(error.localizedDescription)"); return nil }
            }
        }
        let venues = try records("venues", as: Venue.self, validate: validateVenue)
        guard let venue = venues.first else { throw DataValidationError.invalid("No valid venues found. Add a valid venue record to venues.json.") }
        let cocktails = try records("cocktails", as: Cocktail.self, validate: validateCocktail) + records("classics", as: Cocktail.self, validate: validateCocktail)
        let wines = try records("wines", as: Wine.self, validate: validateWine)
        let prep = try records("prep", as: PrepItem.self, validate: validatePrep)
        let stock = try records("stock", as: StockItem.self, validate: validateStock)
        var snapshot = AppSnapshot(venues: venues, cocktails: cocktails, wines: wines, prep: prep, stock: stock,
                                   preferences: UserPreferences(venueID: venue.id), user: User(venueID: venue.id))
        if directory == nil { snapshot = try MenuMigration.apply(to: snapshot) }
        try validate(snapshot: snapshot)
        return SeedLoadReport(snapshot: snapshot, warnings: warnings)
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func validate(snapshot: AppSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw DataValidationError.unsupportedSchema(snapshot.schemaVersion) }
        guard !snapshot.venues.isEmpty else { throw DataValidationError.invalid("At least one venue is required.") }
        try unique(snapshot.venues.map(\.id), label: "venue")
        try unique(snapshot.cocktails.map(\.id), label: "cocktail")
        try unique(snapshot.wines.map(\.id), label: "wine")
        try unique(snapshot.prep.map(\.id), label: "prep")
        try unique(snapshot.stock.map(\.id), label: "stock")
        try unique(snapshot.batches.map(\.id), label: "saved batch")
        let venueIDs = Set(snapshot.venues.map(\.id))
        func venue(_ id: String) throws {
            guard venueIDs.contains(id) else { throw DataValidationError.invalid("Record references unknown venue: \(id)") }
        }
        try snapshot.venues.forEach(validateVenue)
        for cocktail in snapshot.cocktails {
            try validateCocktail(cocktail)
            if let id = cocktail.venueID { try venue(id) }
            else if cocktail.venueSpecific { throw DataValidationError.invalid("Venue cocktail \(cocktail.name) is missing venueID.") }
            if let override = cocktail.overridesCocktailID {
                guard snapshot.cocktails.contains(where: { $0.id == override && $0.venueID == nil }) else {
                    throw DataValidationError.invalid("\(cocktail.name) overrides an unknown global cocktail: \(override)")
                }
            }
        }
        for wine in snapshot.wines {
            try validateWine(wine)
            if let id = wine.venueID { try venue(id) }
            else if wine.venueSpecific { throw DataValidationError.invalid("Venue wine \(wine.name) is missing venueID.") }
        }
        for item in snapshot.prep { try validatePrep(item); try venue(item.venueID) }
        for item in snapshot.stock { try validateStock(item); try venue(item.venueID) }
        try unique(snapshot.products.map(\.id), label: "product")
        try unique(snapshot.stockLists.map(\.id), label: "list item")
        for product in snapshot.products { try identity(product.id, product.name); try venue(product.venueID) }
        for item in snapshot.stockLists {
            try identity(item.id, item.name); try venue(item.venueID)
            guard (1...100_000).contains(item.quantity) else { throw DataValidationError.invalid("List quantity must be between 1 and 100,000.") }
        }
        try venue(snapshot.preferences.venueID)
        try venue(snapshot.user.venueID)
        try number(snapshot.preferences.defaultWastage, label: "Wastage", upper: 100)
        guard ["ml", "cl"].contains(snapshot.preferences.units) else { throw DataValidationError.invalid("Units must be ml or cl.") }
        guard snapshot.training.answered >= 0 && snapshot.training.correct >= 0 && snapshot.training.correct <= snapshot.training.answered else {
            throw DataValidationError.invalid("Training progress is inconsistent.")
        }
        guard snapshot.preferences.recentItems.count <= 20 else { throw DataValidationError.invalid("Recent history must contain no more than 20 items.") }
        for batch in snapshot.batches {
            try identity(batch.id, batch.name)
            guard (0...100_000).contains(batch.serves) else { throw DataValidationError.invalid("Saved batch serves must be between 0 and 100,000.") }
            try number(batch.wastagePercent, label: "Batch wastage", upper: 100)
        }
    }
    static func unique(_ values: [String], label: String) throws {
        guard Set(values).count == values.count else { throw DataValidationError.invalid("Duplicate \(label) IDs.") }
    }
    static func identity(_ id: String, _ name: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DataValidationError.invalid("Every record requires a non-empty id and name.")
        }
    }
    static func number(_ number: Double, label: String, upper: Double = 1_000_000_000) throws {
        guard number.isFinite, number >= 0, number <= upper else { throw DataValidationError.invalid("\(label) must be a finite non-negative value no greater than \(MeasurementFormatter.number(upper)).") }
    }
    static func bottle(_ value: Double?) throws {
        if let value { try number(value, label: "Bottle size"); guard value > 0 else { throw DataValidationError.invalid("Bottle size must be greater than zero.") } }
    }
    static func validateVenue(_ venue: Venue) throws { try identity(venue.id, venue.name) }
    static func validateIngredient(_ ingredient: Ingredient) throws {
        try identity(ingredient.id, ingredient.name)
        try number(ingredient.amount, label: "Ingredient amount")
        try bottle(ingredient.bottleSize)
    }
    static func validateCocktail(_ cocktail: Cocktail) throws {
        try identity(cocktail.id, cocktail.name)
        try unique(cocktail.ingredients.map(\.id), label: "ingredient in \(cocktail.name)")
        try cocktail.ingredients.forEach(validateIngredient)
    }
    static func validateWine(_ wine: Wine) throws {
        try identity(wine.id, wine.name)
        guard [wine.body, wine.sweetness, wine.acidity, wine.tannin].allSatisfy({ (1...5).contains($0) }) else {
            throw DataValidationError.invalid("Wine body, sweetness, acidity and tannin must be between 1 and 5.")
        }
    }
    static func validatePrep(_ item: PrepItem) throws {
        try identity(item.id, item.name)
        try number(item.currentAmount, label: "Current prep amount")
        try number(item.targetAmount, label: "Target prep amount")
        try number(item.recipeYieldAmount, label: "Prep recipe yield")
        guard item.recipeYieldAmount > 0 else { throw DataValidationError.invalid("Prep recipe yield must be greater than zero.") }
        try item.recipe.forEach(validateIngredient)
    }
    static func validateStock(_ item: StockItem) throws {
        try identity(item.id, item.name)
        try number(item.currentStock, label: "Current stock")
        try number(item.parLevel, label: "Par level")
        try bottle(item.bottleSize)
    }
}
