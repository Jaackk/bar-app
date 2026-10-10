import Foundation

public struct ContentConflict: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(kind):\(recordID)" }
    public var kind: String
    public var recordID: String
    public var name: String
    public var reason: String
    public var proposed: Data
}

/// Legacy content without a known baseline is treated as a local edit.
/// Counts, pars, lists, photos and personal state are never pack payloads.
public enum ContentUpdateService {
    public static func merge(_ incoming: AppSnapshot, into local: AppSnapshot) throws -> AppSnapshot {
        guard incoming.cocktails.allSatisfy({ $0.displaySpecification == nil }) else {
            throw DataValidationError.invalid("A displayed specification cannot replace a venue source recipe.")
        }
        var baselines = local.contentBaselines
        var conflicts = local.contentConflicts
        func merge<T: Codable & Hashable & Identifiable>(_ candidates: [T], current: inout [T], kind: String, name: (T) -> String) throws where T.ID == String {
            for candidate in candidates {
                let key = "\(kind):\(candidate.id)"
                let proposed = try SeedLoader.makeEncoder().encode(candidate)
                if let index = current.firstIndex(where: { $0.id == candidate.id }) {
                    let existing = try SeedLoader.makeEncoder().encode(current[index])
                    if existing == proposed || baselines[key] == existing {
                        current[index] = candidate
                        conflicts.removeAll { $0.id == key }
                    } else {
                        conflicts.removeAll { $0.id == key }
                        conflicts.append(ContentConflict(kind: kind, recordID: candidate.id, name: name(candidate), reason: "Your saved version differs. Review both versions before replacing it.", proposed: proposed))
                    }
                } else { current.append(candidate) }
                baselines[key] = proposed
            }
        }
        var result = local
        try merge(incoming.cocktails, current: &result.cocktails, kind: "cocktail", name: { $0.name })
        try merge(incoming.wines, current: &result.wines, kind: "wine", name: { $0.name })
        var proposedProducts = incoming.products
        for i in proposedProducts.indices {
            if let previous = local.products.first(where: { $0.id == proposedProducts[i].id }) {
                proposedProducts[i].imageData = previous.imageData
                if !previous.isActive { proposedProducts[i].isActive = false }
            }
        }
        try merge(proposedProducts, current: &result.products, kind: "product", name: { $0.name })
        result.contentBaselines = baselines; result.contentConflicts = conflicts
        result.catalogueVersion = max(local.catalogueVersion, incoming.catalogueVersion)
        return result
    }

    public static func resolve(_ conflict: ContentConflict, acceptIncoming: Bool, in local: AppSnapshot) throws -> AppSnapshot {
        var result = local
        guard result.contentConflicts.contains(where: { $0 == conflict }) else { return result }
        if acceptIncoming {
            switch conflict.kind {
            case "cocktail":
                let value = try SeedLoader.makeDecoder().decode(Cocktail.self, from: conflict.proposed)
                guard value.id == conflict.recordID, let i = result.cocktails.firstIndex(where: { $0.id == value.id }) else { throw DataValidationError.invalid("The recipe no longer matches this update.") }
                result.cocktails[i] = value
            case "wine":
                let value = try SeedLoader.makeDecoder().decode(Wine.self, from: conflict.proposed)
                guard value.id == conflict.recordID, let i = result.wines.firstIndex(where: { $0.id == value.id }) else { throw DataValidationError.invalid("The wine no longer matches this update.") }
                result.wines[i] = value
            case "product":
                var value = try SeedLoader.makeDecoder().decode(Product.self, from: conflict.proposed)
                guard value.id == conflict.recordID, let i = result.products.firstIndex(where: { $0.id == value.id }) else { throw DataValidationError.invalid("The product no longer matches this update.") }
                value.imageData = result.products[i].imageData
                value.isActive = result.products[i].isActive
                result.products[i] = value
            default: throw DataValidationError.invalid("This content type needs a newer version of BAR.")
            }
        }
        result.contentBaselines[conflict.id] = conflict.proposed
        result.contentConflicts.removeAll { $0.id == conflict.id }
        try SeedLoader.validate(snapshot: result)
        return result
    }
}
