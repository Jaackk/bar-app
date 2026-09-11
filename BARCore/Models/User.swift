import Foundation

public struct User: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var venueID: String
    public var role: UserRole

    public init(id: String = "local-user", name: String = "Bartender", venueID: String = "", role: UserRole = .bartender) {
        self.id = id
        self.name = name
        self.venueID = venueID
        self.role = role
    }

    enum CodingKeys: String, CodingKey { case id, name, venueID, role }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.value(String.self, for: .id, default: "local-user")
        name = try c.value(String.self, for: .name, default: "Bartender")
        venueID = try c.value(String.self, for: .venueID, default: "")
        role = try c.value(UserRole.self, for: .role, default: .bartender)
    }
}
