import Foundation

public struct TrainingProgress: Codable, Hashable, Sendable {
    public var masteredRevisions: [String: String] = [:]
    public var answered: Int
    public var correct: Int
    public var masteredCocktailIDs: Set<String>

    public init(answered: Int = 0, correct: Int = 0, masteredCocktailIDs: Set<String> = []) {
        self.answered = answered
        self.correct = correct
        self.masteredCocktailIDs = masteredCocktailIDs
    }

    enum CodingKeys: String, CodingKey { case masteredRevisions, answered, correct, masteredCocktailIDs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        masteredRevisions = try c.value([String: String].self, for: .masteredRevisions, default: [:])
        answered = try c.value(Int.self, for: .answered, default: 0)
        correct = try c.value(Int.self, for: .correct, default: 0)
        masteredCocktailIDs = try c.value(Set<String>.self, for: .masteredCocktailIDs, default: [])
    }

    public static func revision(for drink: Cocktail) -> String {
        // Stable content fingerprint, not a security hash. User history remains
        // intact while mastery needs revisiting after a changed spec or recipe.
        let fields = [drink.id, drink.displaySpecification?.rawValue ?? "custom", String(drink.referenceVersion ?? 0), drink.method, drink.glass, drink.ice, drink.garnish, drink.serviceNotes] + drink.prepInstructions + drink.ingredients.map { "\($0.name)|\($0.amount)|\($0.unit.rawValue)|\($0.quantityDisplay ?? "")" }
        let hash = fields.joined(separator: "\n").utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
    public func isMastered(_ drink: Cocktail) -> Bool { masteredCocktailIDs.contains(drink.id) && masteredRevisions[drink.id] == Self.revision(for: drink) }
    public var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
    public mutating func record(correct isCorrect: Bool, cocktailID: String) {
        answered += 1
        if isCorrect { correct += 1; masteredCocktailIDs.insert(cocktailID) }
        else { masteredCocktailIDs.remove(cocktailID) }
    }
}
