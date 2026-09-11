import Foundation

public enum MeasurementUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case ml, cl, litre, dash, barspoon, top, piece, sprig, gram
    public var label: String { self == .litre ? "L" : (self == .gram ? "g" : rawValue) }
    public var isVolume: Bool { [.ml, .cl, .litre].contains(self) }
}
public enum BatchBehaviour: String, Codable, CaseIterable, Hashable, Sendable {
    case normal, serviceOnly, prepareSeparately, garnishCount, nonBatchable
    public var label: String {
        switch self {
        case .normal: return "Batch together"
        case .serviceOnly: return "At service"
        case .prepareSeparately: return "Prepare separately"
        case .garnishCount: return "Garnishes"
        case .nonBatchable: return "Do not batch"
        }
    }
}
public enum WineColour: String, Codable, CaseIterable, Hashable, Sendable {
    case red, white, rose, sparkling, dessert
    public var label: String { self == .rose ? "Rosé" : rawValue.capitalized }
}
public enum UserRole: String, Codable, CaseIterable, Hashable, Sendable {
    case bartender, manager, admin
    public var canEditContent: Bool { self != .bartender }
    public var canManageVenues: Bool { self == .admin }
}
public enum RecentKind: String, Codable, Hashable, Sendable { case cocktail, wine }
public enum SearchKind: String, Codable, Hashable, Sendable { case cocktail, wine, prep }
public enum QuizKind: String, Codable, CaseIterable, Hashable, Sendable { case recipe, ingredient }

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ type: T.Type, for key: Key, default fallback: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? fallback()
    }
}

public enum MeasurementFormatter {
    public static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    public static func string(_ amount: Double, unit: MeasurementUnit) -> String {
        if unit == .top { return amount > 0 ? "\(number(amount)) top" : "Top" }
        let separator = unit.isVolume || unit == .gram ? "" : " "
        return "\(number(amount))\(separator)\(unit.label)"
    }
    public static func litres(fromML amount: Double) -> Double { amount / 1_000 }
}
