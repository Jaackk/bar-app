import Foundation

public struct AppSnapshot: Codable, Hashable, Sendable {
    public var catalogueVersion: Int = 0
    public var products: [Product] = []
    public var stockLists: [StockListItem] = []
    public var schemaVersion: Int
    public var venues: [Venue]
    public var cocktails: [Cocktail]
    public var wines: [Wine]
    public var prep: [PrepItem]
    public var stock: [StockItem]
    public var preferences: UserPreferences
    public var training: TrainingProgress
    public var batches: [SavedBatch]
    public var user: User

    public init(schemaVersion: Int = 1, venues: [Venue] = [], cocktails: [Cocktail] = [], wines: [Wine] = [], prep: [PrepItem] = [], stock: [StockItem] = [], preferences: UserPreferences = UserPreferences(), training: TrainingProgress = TrainingProgress(), batches: [SavedBatch] = [], user: User = User()) {
        self.schemaVersion = schemaVersion
        self.venues = venues
        self.cocktails = cocktails
        self.wines = wines
        self.prep = prep
        self.stock = stock
        self.preferences = preferences
        self.training = training
        self.batches = batches
        self.user = user
    }

    enum CodingKeys: String, CodingKey { case catalogueVersion, products, stockLists, schemaVersion, venues, cocktails, wines, prep, stock, preferences, training, batches, user }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        catalogueVersion = try c.value(Int.self, for: .catalogueVersion, default: 0)
        products = try c.value([Product].self, for: .products, default: [])
        stockLists = try c.value([StockListItem].self, for: .stockLists, default: [])
        schemaVersion = try c.value(Int.self, for: .schemaVersion, default: 1)
        venues = try c.value([Venue].self, for: .venues, default: [])
        cocktails = try c.value([Cocktail].self, for: .cocktails, default: [])
        wines = try c.value([Wine].self, for: .wines, default: [])
        prep = try c.value([PrepItem].self, for: .prep, default: [])
        stock = try c.value([StockItem].self, for: .stock, default: [])
        preferences = try c.value(UserPreferences.self, for: .preferences, default: UserPreferences())
        training = try c.value(TrainingProgress.self, for: .training, default: TrainingProgress())
        batches = try c.value([SavedBatch].self, for: .batches, default: [])
        user = try c.value(User.self, for: .user, default: User())
    }
}
