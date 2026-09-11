import Foundation

public struct RecentItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: RecentKind
    public var viewedAt: Date

    public init(id: String, kind: RecentKind, viewedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.viewedAt = viewedAt
    }

    enum CodingKeys: String, CodingKey { case id, kind, viewedAt }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(RecentKind.self, forKey: .kind)
        viewedAt = try c.value(Date.self, for: .viewedAt, default: Date())
    }
}
