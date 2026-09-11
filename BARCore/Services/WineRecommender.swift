import Foundation

public struct WineRecommendation: Identifiable, Hashable, Sendable {
    public var id: String { wine.id }
    public let wine: Wine
    public let score: Double
    public let reasons: [String]
}

public enum WineRecommender {
    public static func attributes(_ wine: Wine) -> [String] {
        var result: [String] = []
        if wine.sweetness <= 2 { result.append("dry") }
        if wine.sweetness >= 4 { result.append("sweet dessert") }
        if wine.acidity >= 4 { result.append("crisp fresh refreshing") }
        if wine.body <= 2 { result.append("light bodied delicate") }
        if wine.body >= 4 { result.append("full bodied rich") }
        if wine.tannin >= 4 { result.append("structured tannic") }
        result += wine.flavourNotes
        return result
    }

    public static func recommend(wines: [Wine], query: String = "", tastes: Set<String> = [], colour: WineColour? = nil) -> [WineRecommendation] {
        let parsed = ParsedQuery(query)
        let tasteTokens = Set(tastes.flatMap { SearchNormalizer.tokens($0) })
        return wines.filter { $0.isActive && (colour == nil || $0.colour == colour) }.compactMap { wine -> WineRecommendation? in
            let name = SearchService.canonical(wine.name)
            let grapes = SearchService.canonical(wine.grape)
            let style = SearchService.canonical(([wine.colour.label, wine.style] + attributes(wine)).joined(separator: " "))
            let pairings = SearchService.canonical(wine.foodPairings.joined(separator: " "))
            let similar = SearchService.canonical(wine.similarTo.joined(separator: " "))
            let metadata = SearchService.canonical([wine.region, wine.country, wine.producer, wine.description, wine.guestDescription].joined(separator: " "))
            let combined = [name, grapes, style, pairings, similar, metadata].joined(separator: " ")
            guard !parsed.negative.contains(where: { combined.contains($0) }) else { return nil }
            // Selected taste chips are intentional constraints; free text ranks broader matches.
            guard tasteTokens.allSatisfy({ style.contains($0) || metadata.contains($0) }) else { return nil }
            var score = Double(tasteTokens.count) * 30
            var reasons = tastes.sorted().map { "\($0.capitalized) style" }
            var matched = 0
            for token in parsed.positive {
                if pairings.contains(token) {
                    score += 65; matched += 1
                    if let pairing = wine.foodPairings.first(where: { SearchService.canonical($0).contains(token) }) { reasons.append("Pairs with \(pairing.lowercased())") }
                } else if name.contains(token) || grapes.contains(token) {
                    score += 60; matched += 1; reasons.append("\(wine.grape) grape profile")
                } else if similar.contains(token) {
                    score += 50; matched += 1; reasons.append("A similar style to \(wine.similarTo.joined(separator: ", "))")
                } else if style.contains(token) {
                    score += 40; matched += 1; reasons.append("\(token.capitalized) profile")
                } else if metadata.contains(token) { score += 12; matched += 1 }
            }
            guard parsed.positive.isEmpty || matched > 0 else { return nil }
            if !parsed.positive.isEmpty { score += 50 * Double(matched) / Double(parsed.positive.count) }
            if reasons.isEmpty { reasons = [wine.guestDescription.isEmpty ? "\(wine.colour.label) · \(wine.grape)" : wine.guestDescription] }
            var seen = Set<String>()
            reasons = reasons.filter { seen.insert($0).inserted }
            return WineRecommendation(wine: wine, score: score, reasons: Array(reasons.prefix(3)))
        }.sorted { $0.score == $1.score ? $0.wine.name < $1.wine.name : $0.score > $1.score }
    }
}
