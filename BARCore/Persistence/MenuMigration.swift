import Foundation

/// One-time content update: personal state, old stocktake and saved lists are preserved.
public enum MenuMigration {
    public static let version = 5
    public static let sourceURL = "https://www.rockwater.uk/wp-content/uploads/2026/05/Drinks-menu-May-1.pdf"
    public static func apply(to old: AppSnapshot) throws -> AppSnapshot {
        guard old.catalogueVersion < version, old.venues.contains(where: { $0.id == "rockwater-hove" }) else { return old }
        var updated = old
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else { throw DataValidationError.invalid("Missing menu content: \(name)") }
            return try SeedLoader.makeDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        let cocktails = try read("hove-cocktails", as: [Cocktail].self) + read("house-classics", as: [Cocktail].self)
        let wines = try read("hove-wines", as: [Wine].self)
        let products = try read("hove-products", as: [Product].self)
        // Replace only bundled sample venue content; manager-approved custom records remain.
        updated.cocktails.removeAll { $0.venueID == "rockwater-hove" && $0.isSample }
        updated.wines.removeAll { $0.venueID == "rockwater-hove" && $0.isSample }
        // Early catalogue versions included recipe drinks and duplicate ingredient labels as
        // products.  Products are for stock and ordering only; recipes remain cocktails.
        let bundledProductIDs = Set(products.map(\.id))
        let retiredDrinkTypes: Set<String> = ["Coastal Cocktails", "Frozen Coastals", "Zero Proof Coastals", "Classic cocktail"]
        updated.products.removeAll {
            $0.venueID == "rockwater-hove" &&
            (retiredDrinkTypes.contains($0.productType) || ($0.id.hasPrefix("spec-") && !bundledProductIDs.contains($0.id)))
        }
        for drink in cocktails {
            if let i = updated.cocktails.firstIndex(where: { $0.id == drink.id }) { updated.cocktails[i] = drink }
            else { updated.cocktails.append(drink) }
        }
        for wine in wines where !updated.wines.contains(where: { $0.id == wine.id }) { updated.wines.append(wine) }
        for product in products {
            if let index = updated.products.firstIndex(where: { $0.id == product.id }) {
                // Keep a manager's locally chosen image, but refresh verified menu names,
                // categories, aliases and units.
                let localImage = updated.products[index].imageData
                let locallyDeleted = !updated.products[index].isActive
                updated.products[index] = product
                updated.products[index].imageData = localImage
                updated.products[index].isActive = !locallyDeleted
            } else if old.catalogueVersion == 0 || product.id.hasPrefix("spec-") || product.id.hasPrefix("service-") {
                updated.products.append(product)
            }
        }
        // Bring old stocktake-only products into the shared catalogue, preserving counts.
        for item in updated.stock where !updated.products.contains(where: { $0.venueID == item.venueID && SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(item.name) }) {
            updated.products.append(Product(id: "stock-" + item.id, venueID: item.venueID, name: item.name, category: StockListService.categories.contains(item.category) ? item.category : "Other", unit: item.unit, defaultOrderUnit: item.unit))
        }
        let replacements = Dictionary(cocktails.flatMap { c in (c.supersededCocktailIDs + (c.overridesCocktailID.map { [$0] } ?? [])).map { ($0, c.id) } }, uniquingKeysWith: { first, _ in first })
        updated.preferences.favouriteCocktailIDs = Set(updated.preferences.favouriteCocktailIDs.map { replacements[$0] ?? $0 })
        for i in updated.batches.indices { if let id = replacements[updated.batches[i].cocktailID] { updated.batches[i].cocktailID = id } }
        updated.catalogueVersion = version
        return updated
    }
}
