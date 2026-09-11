import Foundation

public struct VenueBranding: Codable, Hashable, Sendable {
    public var displayName: String
    public var subtitle: String

    public init(displayName: String = "BAR", subtitle: String = "Great drinks. Brighter people.") {
        self.displayName = displayName
        self.subtitle = subtitle
    }

    enum CodingKeys: String, CodingKey { case displayName, subtitle }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.value(String.self, for: .displayName, default: "BAR")
        subtitle = try c.value(String.self, for: .subtitle, default: "Great drinks. Brighter people.")
    }
}
