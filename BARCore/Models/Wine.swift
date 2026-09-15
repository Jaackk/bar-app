import Foundation

public struct Wine: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    /// The canonical stock-catalogue record for this wine.  This gives every wine surface
    /// one offline image source, including manager-selected product photos.
    public var productID: String?
    public var name: String
    public var venueID: String?
    public var producer: String
    public var region: String
    public var country: String
    public var grape: String
    public var style: String
    public var colour: WineColour
    public var body: Int
    public var sweetness: Int
    public var acidity: Int
    public var tannin: Int
    public var flavourNotes: [String]
    public var description: String
    public var foodPairings: [String]
    public var similarTo: [String]
    public var servingNotes: String
    public var guestDescription: String
    public var imageName: String
    public var venueSpecific: Bool
    public var isActive: Bool
    public var isSample: Bool

    public init(id: String, productID: String? = nil, name: String, venueID: String? = nil, producer: String = "", region: String = "", country: String = "", grape: String = "", style: String = "", colour: WineColour = .white, body: Int = 3, sweetness: Int = 1, acidity: Int = 3, tannin: Int = 1, flavourNotes: [String] = [], description: String = "", foodPairings: [String] = [], similarTo: [String] = [], servingNotes: String = "", guestDescription: String = "", imageName: String = "", venueSpecific: Bool = false, isActive: Bool = true, isSample: Bool = false) {
        self.id = id
        self.productID = productID
        self.name = name
        self.venueID = venueID
        self.producer = producer
        self.region = region
        self.country = country
        self.grape = grape
        self.style = style
        self.colour = colour
        self.body = body
        self.sweetness = sweetness
        self.acidity = acidity
        self.tannin = tannin
        self.flavourNotes = flavourNotes
        self.description = description
        self.foodPairings = foodPairings
        self.similarTo = similarTo
        self.servingNotes = servingNotes
        self.guestDescription = guestDescription
        self.imageName = imageName
        self.venueSpecific = venueSpecific
        self.isActive = isActive
        self.isSample = isSample
    }

    enum CodingKeys: String, CodingKey { case id, productID, name, venueID, producer, region, country, grape, style, colour, body, sweetness, acidity, tannin, flavourNotes, description, foodPairings, similarTo, servingNotes, guestDescription, imageName, venueSpecific, isActive, isSample }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        productID = try c.decodeIfPresent(String.self, forKey: .productID)
        name = try c.decode(String.self, forKey: .name)
        venueID = try c.decodeIfPresent(String.self, forKey: .venueID)
        producer = try c.value(String.self, for: .producer, default: "")
        region = try c.value(String.self, for: .region, default: "")
        country = try c.value(String.self, for: .country, default: "")
        grape = try c.value(String.self, for: .grape, default: "")
        style = try c.value(String.self, for: .style, default: "")
        colour = try c.value(WineColour.self, for: .colour, default: .white)
        body = try c.value(Int.self, for: .body, default: 3)
        sweetness = try c.value(Int.self, for: .sweetness, default: 1)
        acidity = try c.value(Int.self, for: .acidity, default: 3)
        tannin = try c.value(Int.self, for: .tannin, default: 1)
        flavourNotes = try c.value([String].self, for: .flavourNotes, default: [])
        description = try c.value(String.self, for: .description, default: "")
        foodPairings = try c.value([String].self, for: .foodPairings, default: [])
        similarTo = try c.value([String].self, for: .similarTo, default: [])
        servingNotes = try c.value(String.self, for: .servingNotes, default: "")
        guestDescription = try c.value(String.self, for: .guestDescription, default: "")
        imageName = try c.value(String.self, for: .imageName, default: "")
        venueSpecific = try c.value(Bool.self, for: .venueSpecific, default: false)
        isActive = try c.value(Bool.self, for: .isActive, default: true)
        isSample = try c.value(Bool.self, for: .isSample, default: false)
    }
}
