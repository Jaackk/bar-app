import Foundation

public struct StockOrderLine: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let quantity: Int
    public let shortfall: Double
}
public enum StockCalculator {
    public static func required(current: Double, par: Double) -> Double {
        guard current.isFinite, par.isFinite else { return 0 }
        return max(max(par, 0) - max(current, 0), 0)
    }
    public static func wholeQuantity(_ amount: Double) -> Int {
        guard amount.isFinite, amount > 0 else { return 0 }
        // Keep malformed or excessive imported numbers safely inside Int conversion bounds.
        return Int(min(ceil(amount - 0.000_000_001), 1_000_000_000))
    }
    public static func order(items: [StockItem]) -> [StockOrderLine] {
        items.filter { $0.requiredStock > 0 }.map {
            StockOrderLine(id: $0.id, name: $0.name, quantity: $0.orderQuantity, shortfall: $0.requiredStock)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    public static func orderText(items: [StockItem]) -> String {
        let lines = order(items: items)
        return lines.isEmpty ? "All stock is at par." : "Suggested order\n" + lines.map { "\($0.name) × \($0.quantity)" }.joined(separator: "\n")
    }
}
