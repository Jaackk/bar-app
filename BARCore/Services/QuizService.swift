import Foundation

public struct QuizQuestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let cocktailID: String
    public let prompt: String
    public let options: [String]
    public let correctAnswer: String
    public func isCorrect(_ answer: String) -> Bool { answer == correctAnswer }
}
public enum QuizService {
    /// Questions and plausible distractors come from the loaded recipe database.
    public static func questions(cocktails: [Cocktail], kind: QuizKind = .recipe, limit: Int = 10) -> [QuizQuestion] {
        let drinks = cocktails.filter { $0.isActive && !$0.ingredients.isEmpty }
        let allIngredients = Array(Set(drinks.flatMap { $0.ingredients.map(\.name) })).sorted()
        return Array(drinks.compactMap { drink -> QuizQuestion? in
            let answer: String
            let wrong: [String]
            let prompt: String
            switch kind {
            case .recipe:
                answer = drink.ingredients.map(\.name).joined(separator: ", ")
                wrong = Array(Set(drinks.filter { $0.id != drink.id }.map { $0.ingredients.map(\.name).joined(separator: ", ") })).filter { $0 != answer }.sorted()
                prompt = "Which ingredients make a \(drink.name)?"
            case .ingredient:
                guard let first = drink.ingredients.first else { return nil }
                answer = first.name
                let used = Set(drink.ingredients.map { SearchNormalizer.normalize($0.name) })
                wrong = allIngredients.filter { !used.contains(SearchNormalizer.normalize($0)) }
                prompt = "Which ingredient belongs in a \(drink.name)?"
            }
            guard !wrong.isEmpty else { return nil }
            // Stable ordering makes persisted training and automated regression checks reproducible.
            var options = Array(wrong.prefix(3))
            let index = drink.id.utf8.reduce(0) { ($0 + Int($1)) % (options.count + 1) }
            options.insert(answer, at: index)
            return QuizQuestion(id: "\(kind.rawValue)-\(drink.id)", cocktailID: drink.id, prompt: prompt, options: options, correctAnswer: answer)
        }.prefix(max(limit, 0)))
    }
}
