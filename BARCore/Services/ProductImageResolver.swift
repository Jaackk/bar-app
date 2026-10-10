import Foundation

/// Resolves the intended image source and checks renderability through the host.
/// Generic category art is presentation fallback, not a completed product image.
/// BARCore stays independent of UIKit and does not assume a named asset exists.
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

    /// Use the same decoders as the view rendering the thumbnail. A stale asset
    /// name or undecodable local photo must remain visible in Missing Images.
    public static func hasRelevantImage(
        for product: Product,
        canRenderBundledImage: (String) -> Bool,
        canRenderCustomImage: (Data) -> Bool
    ) -> Bool {
        switch source(for: product) {
        case .custom:
            guard let data = product.imageData else { return false }
            return canRenderCustomImage(data)
        case .bundled(let name): return canRenderBundledImage(name)
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
