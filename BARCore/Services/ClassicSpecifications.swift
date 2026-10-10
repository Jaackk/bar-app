import Foundation

public enum ClassicSpecification: String, Codable, CaseIterable, Hashable, Sendable {
    case custom, recommended
    public var label: String { self == .custom ? "Custom" : "Recommended" }
}

public enum PreparationAction: String, Codable, Hashable, Sendable {
    case build, shake, stir, dryShake, reverseDryShake, blend, muddle, roll, strain, fineStrain, top, layer
}

public struct RecipeSource: Codable, Hashable, Sendable {
    public let name: String
    public let url: String
}

public struct ClassicReference: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let aliases: [String]
    public let recommended: Cocktail?
    public let actions: [PreparationAction]
    public let sources: [RecipeSource]
    public let verifiedOn: String
    public let version: Int
    public let decision: String
    public let customReview: String
    public let customTrainingEligible: Bool
    public let correctedLegacyMethod: String?
    public let customMethod: String?
    public let customSteps: [String]?
}

/// Curated reference content is bundled separately from editable venue snapshots.
/// A selection returns a value copy; it never writes a recipe or a stock mapping.
public enum ClassicSpecifications {
    public static func load() throws -> [ClassicReference] {
        guard let url = Bundle.module.url(forResource: "recommended-classics", withExtension: "json") else {
            throw DataValidationError.invalid("The classic reference library is missing. Reinstall BAR without deleting your data, or restore from a backup on another installation.")
        }
        let values = try SeedLoader.makeDecoder().decode([ClassicReference].self, from: Data(contentsOf: url))
        try SeedLoader.unique(values.map(\.id), label: "classic reference")
        try SeedLoader.unique(values.flatMap(\.aliases), label: "classic alias")
        for value in values {
            guard !value.sources.isEmpty, !value.aliases.isEmpty else { throw DataValidationError.invalid("A classic reference is missing its evidence.") }
            if let recipe = value.recommended { try SeedLoader.validateCocktail(recipe) }
        }
        return values
    }

    public static func reference(for id: String, in library: [ClassicReference]) -> ClassicReference? {
        library.first { $0.aliases.contains(id) }
    }

    public static func selection(for id: String, preferences: UserPreferences, library: [ClassicReference]) -> ClassicSpecification {
        let key = reference(for: id, in: library)?.id ?? id
        return preferences.classicOverrides[key] ?? preferences.classicDefault
    }

    public static func resolve(_ custom: Cocktail, preferences: UserPreferences, library: [ClassicReference]) -> Cocktail {
        guard let reference = reference(for: custom.id, in: library) else { return custom }
        let requested = selection(for: custom.id, preferences: preferences, library: library)
        // Global-only recipes have no approved venue Custom. Say so rather than
        // labelling an old generic recipe as a Rockwater specification.
        if (requested == .recommended || custom.venueID == nil), var result = reference.recommended {
            result.id = custom.id
            result.name = custom.name
            result.venueID = custom.venueID
            result.venueSpecific = custom.venueSpecific
            result.imageName = custom.imageName
            result.isHouseClassic = custom.isHouseClassic
            result.isActive = custom.isActive
            result.isPopular = custom.isPopular
            result.displaySpecification = .recommended
            result.referenceVersion = reference.version
            result.sourceReference = "Recommended · verified \(reference.verifiedOn)"
            result.sourceURL = reference.sources.first?.url
            return result
        }
        var result = custom
        result.supersededCocktailIDs = custom.supersededCocktailIDs.filter { reference.aliases.contains($0) }
        result.displaySpecification = .custom
        result.referenceVersion = reference.version
        result.trainingEligible = reference.customTrainingEligible && !custom.serviceNotes.contains("Source check:")
        // Only the exact erroneous imported instruction is corrected. A deliberate
        // owner-edited house method is never silently replaced.
        if let legacy = reference.correctedLegacyMethod, custom.method == legacy,
           let method = reference.customMethod, let steps = reference.customSteps {
            result.method = method
            result.prepInstructions = steps
        }
        return result
    }
}
