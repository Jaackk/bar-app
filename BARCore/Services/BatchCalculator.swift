import Foundation

public struct BatchLine: Identifiable, Hashable, Sendable {
    public var id: String { ingredient.id }
    public let ingredient: Ingredient
    public let quantity: Double
    public let unit: MeasurementUnit
    public let volumeML: Double?
    public let bottles: Int?
    public var behaviour: BatchBehaviour { ingredient.batchBehaviour }
    public var litres: Double? { volumeML.map { $0 / 1_000 } }
    public var measurement: String {
        unit == .top ? "At service / to taste" : MeasurementFormatter.string(quantity, unit: unit)
    }
}
public struct BatchResult: Hashable, Sendable {
    public let serves: Int
    public let wastagePercent: Double
    public let lines: [BatchLine]
    public let totalVolumeML: Double
    public let notes: [String]
}
public enum BatchCalculator {
    /// Wastage is a percentage (3 means 3%). Garnishes and service additions are not wasted in the batch.
    public static func calculate(cocktail: Cocktail, serves: Int, wastagePercent: Double = 3) -> BatchResult {
        guard cocktail.recipeVerified else { return BatchResult(serves: 0, wastagePercent: 0, lines: [], totalVolumeML: 0, notes: ["House measures are not published. Add a verified venue specification before batching."]) }
        let safeServes = min(max(serves, 0), 100_000)
        let wastage = wastagePercent.isFinite ? min(max(wastagePercent, 0), 100) : 0
        var notes = ["Combine the measured batch ingredients in a clean, labelled container. Keep chilled and follow the approved venue storage procedure."]
        let lines = cocktail.ingredients.compactMap { ingredient -> BatchLine? in
            let behaviour = ingredient.batchBehaviour
            guard behaviour != .nonBatchable else { return nil }
            guard ingredient.batchable || behaviour == .serviceOnly || behaviour == .garnishCount || behaviour == .prepareSeparately else { return nil }
            let factor = behaviour == .garnishCount || behaviour == .serviceOnly ? 1 : 1 + wastage / 100
            let safeAmount = ingredient.amount.isFinite ? max(ingredient.amount, 0) : 0
            let rawQuantity = safeAmount * Double(safeServes) * factor
            let quantity = behaviour == .garnishCount ? ceil(rawQuantity) : rawQuantity
            let volume: Double?
            switch ingredient.unit {
            case .ml: volume = quantity
            case .cl: volume = quantity * 10
            case .litre: volume = quantity * 1_000
            default: volume = nil
            }
            let bottles: Int?
            if let ml = volume, let size = ingredient.bottleSize, size.isFinite, size > 0 {
                bottles = StockCalculator.wholeQuantity(ml / size)
            } else { bottles = nil }
            switch behaviour {
            case .serviceOnly: notes.append("Add \(ingredient.name.lowercased()) during service.")
            case .prepareSeparately: notes.append("Prepare \(ingredient.name.lowercased()) separately.")
            case .garnishCount: notes.append("Prepare \(MeasurementFormatter.number(quantity)) \(ingredient.name.lowercased()) for garnish.")
            default: break
            }
            let citrus = ["lemon", "lime", "grapefruit", "orange juice"]
            if citrus.contains(where: { ingredient.name.lowercased().contains($0) }) {
                notes.append("Keep fresh citrus chilled and separate until needed; prepare for the current service.")
            }
            return BatchLine(ingredient: ingredient, quantity: quantity, unit: ingredient.unit, volumeML: volume, bottles: bottles)
        }
        var seen = Set<String>()
        notes = notes.filter { seen.insert($0).inserted }
        return BatchResult(serves: safeServes, wastagePercent: wastage, lines: lines,
                           totalVolumeML: lines.filter { $0.behaviour == .normal }.compactMap(\.volumeML).reduce(0, +), notes: notes)
    }
}
