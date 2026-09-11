import Foundation

public enum ContentImportService {
    /// Imports content only. Local identity and personal state cannot be replaced by a file.
    public static func merge(data: Data, preserving local: AppSnapshot) throws -> AppSnapshot {
        var imported = try SeedLoader.makeDecoder().decode(AppSnapshot.self, from: data)
        imported.preferences = local.preferences
        imported.training = local.training
        imported.user = local.user
        imported.batches = local.batches
        imported.stockLists = local.stockLists
        if imported.catalogueVersion == 0 { imported.products = local.products }
        imported.catalogueVersion = max(imported.catalogueVersion, local.catalogueVersion)
        guard imported.venues.contains(where: { $0.id == local.preferences.venueID }) else {
            throw DataValidationError.invalid("Import must include your current venue.")
        }
        try SeedLoader.validate(snapshot: imported)
        return imported
    }
}
