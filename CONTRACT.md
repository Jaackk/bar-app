# BARCore public contract

Swift Package module `BARCore`, Swift 5.9, iOS 17 / macOS 13. All ids are String. Codable dates use ISO8601. All models Codable, Hashable, Identifiable and public; record initializers require only id + name except Ingredient (name, amount, unit). JSON uses camelCase keys. Missing optional/default fields decode safely.

## Seed JSON
Files in `BARCore/Data`: venues.json [Venue], cocktails.json [Cocktail] (sample venue records), classics.json [Cocktail] (global), wines.json [Wine], prep.json [PrepItem], stock.json [StockItem]. Each is a plain JSON array. Mark sample records `isSample: true`. No dates required.

- Venue: id, name, location:String, venueCode:String, branding:VenueBranding {displayName:String, subtitle:String}, createdAt/updatedAt:Date.
- UserRole enum String: bartender, manager, admin; `canEditContent`, `canManageVenues`.
- User: id, name, venueID:String, role:UserRole.
- Ingredient: id:String(default UUID), name:String, amount:Double(default 0), unit:MeasurementUnit (ml, cl, litre, dash, barspoon, top, piece, sprig, gram), batchable:Bool(default true), batchBehaviour:BatchBehaviour (normal, serviceOnly, prepareSeparately, garnishCount, nonBatchable), bottleSize:Double? (IN ML), notes:String, prepComponent:String?. `measurement:String`, `volumeML:Double?`.
- Cocktail: id, name, venueID:String?, subtitle:String, description:String, venueSpecific:Bool, category:String, baseSpirit:String, flavourTags:[String], ingredients:[Ingredient], method:String, glass:String, ice:String, garnish:String, prepInstructions:[String], serviceNotes:String, allergens:[String], imageName:String, isPopular:Bool, isActive:Bool(default true), isSample:Bool, variations:[String], overridesCocktailID:String?, createdAt/updatedAt:Date.
- Wine: id, name, venueID:String?, producer, region, country, grape, style:String; colour:WineColour (red, white, rose, sparkling, dessert); body:Int (1 light..5 full), sweetness:Int (1 dry..5 sweet), acidity:Int, tannin:Int; flavourNotes:[String], description:String, foodPairings:[String], similarTo:[String], servingNotes:String, guestDescription:String, imageName:String, venueSpecific:Bool, isActive:Bool, isSample:Bool.
- PrepItem: id,name,venueID:String, category:String, currentAmount/targetAmount:Double, unit:MeasurementUnit, recipe:[Ingredient], method:[String], storageInstructions:String, shelfLife:String, lastPreparedDate:Date?, completed:Bool, notes:String, isSample:Bool. `requiredAmount:Double`, `progress:Double` computed.
- StockItem: id,name,venueID:String, category:String, bottleSize:Double? (ML), currentStock/parLevel:Double, unit:String(default bottles), notes:String, isSample:Bool. `requiredStock:Double`, `orderQuantity:Int` computed.
- UserPreferences: employeeName:String, venueID:String, units:String(default ml), defaultWastage:Double(default 3, PERCENT), favouriteCocktailIDs:Set<String>, favouriteWineIDs:Set<String>, recentItems:[RecentItem] (id:String, kind:RecentKind cocktail/wine, viewedAt:Date); `recordRecent(id:kind:)` bounds at 20.
- TrainingProgress: answered:Int, correct:Int, masteredCocktailIDs:Set<String>; `accuracy:Double` 0...1, `record(correct:cocktailID:)`.
- SavedBatch: id:String, cocktailID:String, name:String, serves:Int, wastagePercent:Double, createdAt:Date.

## Persistence / repositories
`AppSnapshot` mutable value contains venues:[Venue], cocktails:[Cocktail], wines:[Wine], prep:[PrepItem], stock:[StockItem], preferences:UserPreferences, training:TrainingProgress, batches:[SavedBatch], user:User, schemaVersion:Int(default 1).
`SeedLoader.load(bundle: Bundle? = nil) throws -> AppSnapshot` loads built-in package data, skipping bad individual records and exposes `SeedLoader.validate(snapshot:) throws` for imports.
`AppRepository` protocol: `load() throws -> AppSnapshot`, `save(_ snapshot:AppSnapshot) throws`, `reset() throws -> AppSnapshot`.
`LocalAppRepository(directory: URL? = nil)` stores validated snapshot atomically in Application Support/BAR/state.json; corrupted saved data throws (never silently overwrites). `reset` explicitly removes only own snapshot and seeds anew.
Also CocktailRepository/WineRepository/PrepRepository/StockRepository/VenueRepository protocols with query/update APIs implemented by `LocalContentRepository(appRepository:)`; future backend implements same interfaces.

## Services
- `VenueResolver.cocktails(_ cocktails:[Cocktail], venueID:String) -> [Cocktail]` returns active local + globals with venue overrides taking priority by overridesCocktailID OR case-folded name.
- `BatchCalculator.calculate(cocktail:Cocktail, serves:Int, wastagePercent:Double = 3) -> BatchResult`. Result `serves`, `wastagePercent`, `lines:[BatchLine]`, `totalVolumeML:Double`, `notes:[String]`. Line has `id`, `ingredient:Ingredient`, `quantity:Double`, `unit:MeasurementUnit`, `volumeML:Double?`, `litres:Double?`, `bottles:Int?`, `behaviour:BatchBehaviour`, `measurement:String`. Non-batchable lines excluded; service-only, separately prepared and garnishes included and labelled, totalVolumeML counts normal only. Garnishes ceil serves × quantity without wastage. Service-only no wastage. Other measured quantities apply wastage.
- `SearchService.search(query:String, cocktails:[Cocktail], wines:[Wine], prep:[PrepItem] = [], venueID:String) -> [SearchResult]`. SearchResult `id`, `kind:SearchKind` cocktail/wine/prep, `title`, `subtitle`, `score:Double`; IDs are source ids, tie by title. Supports exclusions (`no egg`), partial tokens and full metadata.
- `WineRecommender.recommend(wines:[Wine], query:String = "", tastes:Set<String> = [], colour:WineColour? = nil) -> [WineRecommendation]`. Recommendation `id`, `wine:Wine`, `score:Double`, `reasons:[String]`.
- `StockCalculator.required(current:Double, par:Double) -> Double`; `order(items:[StockItem]) -> [StockOrderLine]` line `id`, `name`, `quantity:Int`, `shortfall:Double`; `orderText(items:[StockItem]) -> String`.
- `QuizService.questions(cocktails:[Cocktail], kind:QuizKind = .recipe, limit:Int = 10) -> [QuizQuestion]` kind recipe/ingredient; question `id`, `cocktailID`, `prompt`, `options:[String]`, `correctAnswer:String`; `isCorrect(_ answer:String)`.
- `MeasurementFormatter.string(_ amount:Double, unit:MeasurementUnit) -> String`; `.number(_ value:Double) -> String`; `.litres(fromML:Double) -> Double`.
