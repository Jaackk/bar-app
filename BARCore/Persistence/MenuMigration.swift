import Foundation

/// Rockwater's venue pack; counts, lists and personal state are not pack content.
public enum MenuMigration {
    public static let version = 25
    public static let sourceURL = "https://www.rockwater.uk/wp-content/uploads/2026/05/Drinks-menu-May-1.pdf"
    public static func apply(to old: AppSnapshot) throws -> AppSnapshot {
        guard old.catalogueVersion < version, old.venues.contains(where: { $0.id == "rockwater-hove" }) else { return old }
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else { throw DataValidationError.invalid("The bundled venue menu is incomplete. Your saved data has not been replaced.") }
            return try SeedLoader.makeDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        var pack = AppSnapshot()
        pack.catalogueVersion = version
        pack.cocktails = try read("hove-cocktails", as: [Cocktail].self) + read("house-classics", as: [Cocktail].self)
        let requiredReferences = Set(pack.cocktails.compactMap(\.overridesCocktailID))
        let existingIDs = Set(old.cocktails.map(\.id))
        let globals = try read("classics", as: [Cocktail].self)
        pack.cocktails += globals.filter { requiredReferences.contains($0.id) && !existingIDs.contains($0.id) }
        pack.products = ProductCatalogueCorrections.corrected(try read("hove-products", as: [Product].self))
        pack.wines = try read("hove-wines", as: [Wine].self).map { WineProductResolver.linked($0, products: pack.products) }
        for i in pack.cocktails.indices {
            for j in pack.cocktails[i].ingredients.indices {
                pack.cocktails[i].ingredients[j].stockProductID = ProductCatalogueCorrections.canonicalID(forIngredientName: pack.cocktails[i].ingredients[j].name, products: pack.products)
            }
        }
        // Never rename two stock IDs into one or sum independent physical counts.
        // Legacy entries remain intact and visible for deliberate owner reconciliation.
        var updated = try ContentUpdateService.merge(pack, into: old)
        // Keep the earlier stock-only custom-product workflow, using the original
        // identity and unit rather than inventing a second stock identity by name.
        for item in old.stock where !item.isSample && !updated.products.contains(where: { $0.id == item.id }) {
            updated.products.append(Product(id: item.id, venueID: item.venueID, name: item.name,
                category: StockListService.categories.contains(item.category) ? item.category : "Other", unit: item.unit, defaultOrderUnit: item.unit))
        }
        return updated
    }
}
