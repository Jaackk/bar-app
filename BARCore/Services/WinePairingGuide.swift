import Foundation

/// Editorial style guidance, separate from menu facts; shared by both search entry points.
public enum WinePairingGuide {
    public static func pairings(_ wine: Wine) -> [String] {
        if !wine.foodPairings.isEmpty { return wine.foodPairings }
        switch wine.colour {
        case .red: return wine.body >= 3 ? ["steak", "beef", "lamb", "grilled meat", "mushrooms"] : ["duck", "chicken", "mushrooms", "salmon", "tuna"]
        case .white: return wine.body >= 4 ? ["roast chicken", "creamy pasta", "grilled fish", "salmon"] : ["fish", "seafood", "shellfish", "prawns", "oysters", "salad", "goat cheese"]
        case .rose: return ["fish", "salad", "grilled prawns", "Mediterranean dishes"]
        case .orange: return ["spiced vegetables", "roast chicken", "cheese"]
        case .sparkling: return ["oysters", "shellfish", "fish and chips", "canapés"]
        case .dessert: return ["dessert", "chocolate", "blue cheese"]
        }
    }
    public static func expand(_ text: String) -> String {
        let aliases = ["seafood": "seafood fish shellfish prawns shrimp oysters mussels", "steak": "steak beef ribeye sirloin fillet filet", "chicken": "chicken poultry", "salad": "salad vegetables vegetarian", "prawns": "prawns shrimp", "mushrooms": "mushrooms mushroom", "cheese": "cheese fromage"]
        return SearchNormalizer.tokens(text).map { aliases[$0] ?? $0 }.joined(separator: " ")
    }
}
