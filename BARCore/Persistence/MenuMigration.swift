import Foundation

/// One-time content update: personal state, old stocktake and saved lists are preserved.
public enum MenuMigration {
    public static let version = 1
    public static let sourceURL = "https://www.rockwater.uk/wp-content/uploads/2026/05/Drinks-menu-May-1.pdf"
    public static func apply(to old: AppSnapshot) throws -> AppSnapshot {
        guard old.catalogueVersion < version, old.venues.contains(where: { $0.id == "rockwater-hove" }) else { return old }
        var updated = old
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else { throw DataValidationError.invalid("Missing menu content: \(name)") }
            return try SeedLoader.makeDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        let cocktails = try read("hove-cocktails", as: [Cocktail].self)
        let wines = try read("hove-wines", as: [Wine].self)
        let products = try read("hove-products", as: [Product].self)
        // Replace only bundled sample venue content; manager-approved custom records remain.
        updated.cocktails.removeAll { $0.venueID == "rockwater-hove" && $0.isSample }
        updated.wines.removeAll { $0.venueID == "rockwater-hove" && $0.isSample }
        for drink in cocktails where !updated.cocktails.contains(where: { $0.id == drink.id }) { updated.cocktails.append(drink) }
        for wine in wines where !updated.wines.contains(where: { $0.id == wine.id }) { updated.wines.append(wine) }
        for product in products where !updated.products.contains(where: { $0.id == product.id }) { updated.products.append(product) }
        updated.catalogueVersion = version
        return updated
    }
}
