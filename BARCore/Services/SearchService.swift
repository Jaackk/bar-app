import Foundation

public struct SearchResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: SearchKind
    public let title: String
    public let subtitle: String
    public let score: Double
}

struct ParsedQuery {
    let positive: [String]
    let negative: [String]
    init(_ query: String) {
        let words = SearchNormalizer.tokens(query)
        let stopWords: Set<String> = ["i", "a", "an", "the", "want", "something", "normally", "drink", "like", "similar", "to", "what", "goes", "with", "and", "please", "some", "wine", "cocktail", "for", "recommend", "recommendation", "pair", "pairing", "best", "would", "you", "me", "can", "have", "having", "good", "bottle", "glass"]
        var positives: [String] = [], negatives: [String] = []
        var negateNext = false
        for word in words {
            if ["no", "without", "exclude"].contains(word) { negateNext = true; continue }
            let canonical = word == "whiskey" ? "whisky" : word
            if negateNext { negatives.append(canonical); negateNext = false }
            else if !stopWords.contains(word) { positives.append(canonical) }
        }
        positive = positives
        negative = negatives
    }
}

public enum SearchService {
    public static func search(query: String, cocktails: [Cocktail], wines: [Wine], prep: [PrepItem] = [], products: [Product] = [], venueID: String) -> [SearchResult] {
        let parsed = ParsedQuery(query)
        let resolved = VenueResolver.cocktails(cocktails, venueID: venueID)
        var result: [SearchResult] = resolved.compactMap { cocktail in
            let primary = ([cocktail.baseSpirit, cocktail.category, cocktail.garnish, cocktail.glass, cocktail.method] + cocktail.flavourTags + cocktail.ingredients.map(\.name)).joined(separator: " ")
            let secondary = ([cocktail.description, cocktail.subtitle, cocktail.serviceNotes] + cocktail.prepInstructions).joined(separator: " ")
            // Negations use factual ingredient / allergen metadata rather than prose such as "no egg".
            let exclusions = (cocktail.ingredients.map(\.name) + cocktail.allergens).joined(separator: " ")
            guard let score = rank(name: cocktail.name, primary: primary, secondary: secondary, exclusions: exclusions, query: parsed) else { return nil }
            return SearchResult(id: cocktail.id, kind: .cocktail, title: cocktail.name, subtitle: cocktail.venueID == nil ? "Classic · \(cocktail.baseSpirit)" : "Venue · \(cocktail.baseSpirit)", score: score + (cocktail.venueID == venueID ? 6 : 0))
        }
        result += wines.filter { $0.isActive && ($0.venueID == nil || $0.venueID == venueID) }.compactMap { wine in
            let primary = ([wine.grape, wine.region, wine.country, wine.colour.label, wine.style] + wine.flavourNotes + [WinePairingGuide.expand(WinePairingGuide.pairings(wine).joined(separator: " "))] + wine.similarTo + WineRecommender.attributes(wine)).joined(separator: " ")
            let secondary = [wine.producer, wine.description, wine.guestDescription, wine.servingNotes].joined(separator: " ")
            guard let score = rank(name: wine.name, primary: primary, secondary: secondary, exclusions: primary, query: parsed) else { return nil }
            return SearchResult(id: wine.id, kind: .wine, title: wine.name, subtitle: "\(wine.colour.label) · \(wine.grape)", score: score)
        }
        result += prep.filter { $0.venueID == venueID }.compactMap { item in
            let primary = ([item.category] + item.recipe.map(\.name)).joined(separator: " ")
            let secondary = ([item.notes, item.storageInstructions] + item.method).joined(separator: " ")
            guard let score = rank(name: item.name, primary: primary, secondary: secondary, exclusions: primary, query: parsed) else { return nil }
            return SearchResult(id: item.id, kind: .prep, title: item.name, subtitle: "Prep · \(item.category)", score: score)
        }
        result += products.filter { $0.isActive && $0.venueID == venueID }.compactMap { product in
            let primary = [product.brand, product.category, product.productType].joined(separator: " ")
            guard let score = rank(name: product.name, primary: primary, secondary: product.menuDetails, exclusions: primary, query: parsed) else { return nil }
            return SearchResult(id: product.id, kind: .product, title: product.name, subtitle: product.category, score: score)
        }
        return result.sorted { $0.score == $1.score ? $0.title < $1.title : $0.score > $1.score }
    }

    /// One-character spelling tolerance for longer words; short words stay exact.
    static func matches(_ token: String, in text: String) -> Bool {
        if text.contains(token) { return true }
        guard token.count >= 5 else { return false }
        return text.split(separator: " ").contains { word in
            let a = Array(token), b = Array(word)
            guard abs(a.count - b.count) <= 1 else { return false }
            var i = 0, j = 0, edits = 0
            while i < a.count && j < b.count {
                if a[i] == b[j] { i += 1; j += 1; continue }
                edits += 1
                if edits > 1 { return false }
                if a.count >= b.count { i += 1 }
                if b.count >= a.count { j += 1 }
            }
            return edits + (a.count - i) + (b.count - j) <= 1
        }
    }

    static func canonical(_ text: String) -> String { SearchNormalizer.normalize(text).replacingOccurrences(of: "whiskey", with: "whisky") }
    static func rank(name: String, primary: String, secondary: String, exclusions: String, query: ParsedQuery) -> Double? {
        let name = canonical(name), primary = canonical(primary), secondary = canonical(secondary)
        let exclusions = canonical(exclusions)
        if query.negative.contains(where: { exclusions.contains($0) }) { return nil }
        guard !query.positive.isEmpty else { return 1 }
        let combined = name + " " + primary + " " + secondary
        guard query.positive.allSatisfy({ matches($0, in: combined) }) else { return nil }
        let phrase = query.positive.joined(separator: " ")
        var score: Double = name == phrase ? 1_000 : (name.hasPrefix(phrase) ? 600 : (name.contains(phrase) ? 400 : 0))
        for token in query.positive {
            if name.split(separator: " ").contains(Substring(token)) { score += 100 }
            else if name.contains(token) { score += 65 }
            else if primary.contains(token) { score += 35 }
            else { score += 10 }
        }
        return score
    }
}
