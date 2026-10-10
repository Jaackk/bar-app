import Foundation

public enum ContentImportService {
    public static func merge(data: Data, preserving local: AppSnapshot) throws -> AppSnapshot {
        guard data.count <= BackupService.maximumBytes else { throw DataValidationError.invalid("The content file is too large.") }
        var imported = try SeedLoader.makeDecoder().decode(AppSnapshot.self, from: data)
        // Personal fields are not required in a content pack and never imported.
        imported.preferences = local.preferences
        imported.user = local.user
        try SeedLoader.validate(snapshot: imported)
        guard imported.cocktails.allSatisfy({ $0.displaySpecification == nil }) else {
            throw DataValidationError.invalid("Import venue source recipes, not a displayed Recommended specification or saved batch.")
        }
        guard Set(imported.venues.map(\.id)).isSubset(of: Set(local.venues.map(\.id))) else { throw DataValidationError.invalid("This content belongs to a different venue.") }
        var pack = AppSnapshot()
        // Only bundled migrations advance this marker. A content import must not
        // prevent future application upgrades by supplying an arbitrary version.
        pack.catalogueVersion = local.catalogueVersion
        pack.cocktails = imported.cocktails.filter { $0.venueID == local.preferences.venueID }
        pack.wines = imported.wines.filter { $0.venueID == local.preferences.venueID }
        pack.products = imported.products.filter { $0.venueID == local.preferences.venueID }
        let result = try ContentUpdateService.merge(pack, into: local)
        try SeedLoader.validate(snapshot: result)
        return result
    }
}
