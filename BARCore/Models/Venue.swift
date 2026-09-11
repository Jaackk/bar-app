import Foundation

public struct Venue: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var location: String
    public var venueCode: String
    public var branding: VenueBranding
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, name: String, location: String = "", venueCode: String = "", branding: VenueBranding = VenueBranding(), createdAt: Date = Date(timeIntervalSince1970: 0), updatedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.id = id
        self.name = name
        self.location = location
        self.venueCode = venueCode
        self.branding = branding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case id, name, location, venueCode, branding, createdAt, updatedAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        location = try c.value(String.self, for: .location, default: "")
        venueCode = try c.value(String.self, for: .venueCode, default: "")
        branding = try c.value(VenueBranding.self, for: .branding, default: VenueBranding())
        createdAt = try c.value(Date.self, for: .createdAt, default: Date(timeIntervalSince1970: 0))
        updatedAt = try c.value(Date.self, for: .updatedAt, default: Date(timeIntervalSince1970: 0))
    }
}
