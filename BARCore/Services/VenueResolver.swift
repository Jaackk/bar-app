import Foundation

public enum VenueResolver {
    public static func cocktails(_ cocktails: [Cocktail], venueID: String) -> [Cocktail] {
        let local = cocktails.filter { $0.isActive && $0.venueID == venueID }
        let overriddenIDs = Set(local.compactMap(\.overridesCocktailID))
        let overriddenNames = Set(local.map { SearchNormalizer.normalize($0.name) })
        let global = cocktails.filter {
            $0.isActive && $0.venueID == nil && !$0.venueSpecific &&
            !overriddenIDs.contains($0.id) && !overriddenNames.contains(SearchNormalizer.normalize($0.name))
        }
        return local.sorted { $0.name < $1.name } + global.sorted { $0.name < $1.name }
    }
}

public enum SearchNormalizer {
    public static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_GB"))
            .lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ").joined(separator: " ")
    }
    public static func tokens(_ text: String) -> [String] { normalize(text).split(separator: " ").map(String.init) }
}
