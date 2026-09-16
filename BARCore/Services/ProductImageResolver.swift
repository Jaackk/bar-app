import Foundation

/// The single source of truth for whether a product has a real, locally
/// available image. Generic category art remains useful presentation fallback,
/// but deliberately does not satisfy the catalogue's image-completeness check.
public enum ProductImageResolver {
    public enum Source: Equatable, Sendable {
        case custom
        case bundled(String)
        case genericFallback(String)
        case none
    }

    private static let genericFallbackNames: Set<String> = [
        "fresh-fruit", "fresh-herbs", "bar-staples"
    ]

    public static func source(for product: Product) -> Source {
        if product.imageData != nil { return .custom }
        if let name = bundledImageName(for: product) {
            return genericFallbackNames.contains(name) ? .genericFallback(name) : .bundled(name)
        }
        if let fallback = categoryFallbackName(for: product) { return .genericFallback(fallback) }
        return .none
    }

    /// User-selected photos and verified bundled defaults are complete images.
    /// The category artwork used for blank/generic records is intentionally not.
    public static func hasRelevantImage(for product: Product) -> Bool {
        switch source(for: product) {
        case .custom, .bundled: return true
        case .genericFallback, .none: return false
        }
    }

    public static func bundledImageName(for product: Product) -> String? {
        let name = ProductCatalogueCorrections.defaultImageName(for: product)
        return name.isEmpty ? nil : name
    }

    public static func categoryFallbackName(for product: Product) -> String? {
        guard product.brand.isEmpty else { return nil }
        switch product.category {
        case "Fresh Fruit": return "fresh-fruit"
        case "Fresh Herbs", "Garnishes": return "fresh-herbs"
        case "Juices", "Syrups / Cordials", "Purees", "Mixers", "Prep": return "bar-staples"
        default: return nil
        }
    }
}
