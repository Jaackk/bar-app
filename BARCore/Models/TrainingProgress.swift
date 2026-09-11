import Foundation

public struct TrainingProgress: Codable, Hashable, Sendable {
    public var answered: Int
    public var correct: Int
    public var masteredCocktailIDs: Set<String>

    public init(answered: Int = 0, correct: Int = 0, masteredCocktailIDs: Set<String> = []) {
        self.answered = answered
        self.correct = correct
        self.masteredCocktailIDs = masteredCocktailIDs
    }

    enum CodingKeys: String, CodingKey { case answered, correct, masteredCocktailIDs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        answered = try c.value(Int.self, for: .answered, default: 0)
        correct = try c.value(Int.self, for: .correct, default: 0)
        masteredCocktailIDs = try c.value(Set<String>.self, for: .masteredCocktailIDs, default: [])
    }

    public var accuracy: Double { answered > 0 ? Double(correct) / Double(answered) : 0 }
    public mutating func record(correct isCorrect: Bool, cocktailID: String) {
        answered += 1
        if isCorrect { correct += 1; masteredCocktailIDs.insert(cocktailID) }
        else { masteredCocktailIDs.remove(cocktailID) }
    }
}
