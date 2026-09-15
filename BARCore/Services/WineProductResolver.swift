import Foundation

/// Resolves a Wine record to its single canonical stock-catalogue product.  The stored
/// relationship is always preferred; the strict-name fallback only backfills older snapshots.
public enum WineProductResolver {
    public enum ImageSource: Equatable, Sendable {
        case customProductImage(Product)
        case bundledProductImage(Product)
        case wineImage(String)
        case fallback
    }

    public static func product(for wine: Wine, in products: [Product]) -> Product? {
        if let productID = wine.productID,
           let product = products.first(where: { $0.id == productID && $0.isActive }) {
            return product
        }
        // Only exact canonical names are considered.  This deliberately cannot turn one
        // cuvée or champagne expression into another that happens to share a producer.
        let expectedName = SearchNormalizer.normalize(wine.name)
        let matches = products.filter {
            $0.isActive && wineCategories.contains($0.category) &&
            SearchNormalizer.normalize($0.name) == expectedName
        }
        return matches.count == 1 ? matches[0] : nil
    }

    public static func imageSource(for wine: Wine, products: [Product]) -> ImageSource {
        if let product = product(for: wine, in: products) {
            if product.imageData != nil { return .customProductImage(product) }
            if !product.imageName.isEmpty { return .bundledProductImage(product) }
        }
        if !wine.imageName.isEmpty { return .wineImage(wine.imageName) }
        return .fallback
    }

    public static func linked(_ wine: Wine, products: [Product]) -> Wine {
        var wine = wine
        wine.productID = product(for: wine, in: products)?.id
        return wine
    }

    private static let wineCategories: Set<String> = ["Wine", "Sparkling / Champagne"]
}
