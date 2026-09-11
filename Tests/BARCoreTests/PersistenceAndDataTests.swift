import XCTest
@testable import BARCore

final class PersistenceAndDataTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("BARTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func fixture() -> AppSnapshot {
        AppSnapshot(venues: [Venue(id: "v", name: "Test venue"), Venue(id: "other", name: "Other venue")],
                    cocktails: [Cocktail(id: "g", name: "Classic", ingredients: [Ingredient(name: "Gin", amount: 50)])],
                    prep: [PrepItem(id: "p", name: "Syrup", venueID: "v", currentAmount: 0.2, targetAmount: 1)],
                    stock: [StockItem(id: "s", name: "Gin", venueID: "v", currentStock: 1.5, parLevel: 6)],
                    preferences: UserPreferences(venueID: "v"), user: User(venueID: "v"))
    }
    func testAllBundledSeedsDecodeWithoutSkippedRecords() throws {
        let report = try SeedLoader.loadWithReport()
        XCTAssertTrue(report.warnings.isEmpty, report.warnings.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(report.snapshot.cocktails.filter { $0.venueID == nil }.count, 31)
        XCTAssertFalse(report.snapshot.venues.isEmpty)
        XCTAssertGreaterThanOrEqual(report.snapshot.wines.count, 10)
        XCTAssertTrue(report.snapshot.cocktails.filter { $0.venueID != nil }.allSatisfy(\.isSample))
        XCTAssertTrue(report.snapshot.wines.allSatisfy(\.isSample))
    }
    func testMinimalCocktailDecodesUsefulDefaults() throws {
        let drink = try SeedLoader.makeDecoder().decode(Cocktail.self, from: Data(#"{"id":"x","name":"Minimal"}"#.utf8))
        XCTAssertTrue(drink.isActive)
        XCTAssertEqual(drink.ingredients, [])
        XCTAssertNil(drink.venueID)
    }
    func testMalformedIndividualSeedRecordIsSkipped() throws {
        let venueData = try SeedLoader.makeEncoder().encode([Venue(id: "v", name: "Venue")])
        try venueData.write(to: directory.appendingPathComponent("venues.json"))
        for name in ["classics", "wines", "prep", "stock"] { try Data("[]".utf8).write(to: directory.appendingPathComponent(name + ".json")) }
        try Data(#"[{"id":"good","name":"Valid"},{"id":"bad"},{"id":"negative","name":"Bad amount","ingredients":[{"name":"Rum","amount":-5}]}]"#.utf8).write(to: directory.appendingPathComponent("cocktails.json"))
        XCTAssertEqual(try SeedLoader.load(directory: directory).cocktails.map(\.id), ["good"])
    }
    func testFirstLoadSeedsExactlyOnceAndRelaunchPersistsEntireLocalState() throws {
        var seeds = 0
        let repository = LocalAppRepository(directory: directory) { seeds += 1; return self.fixture() }
        var state = try repository.load()
        state.preferences.employeeName = "Sam"
        state.preferences.favouriteCocktailIDs.insert("g")
        state.preferences.recordRecent(id: "g", kind: .cocktail)
        state.training.record(correct: true, cocktailID: "g")
        state.stock[0].currentStock = 2.25
        state.prep[0].markComplete()
        state.batches.append(SavedBatch(cocktailID: "g", name: "Classic × 25", serves: 25))
        try repository.save(state)
        let reloaded = try LocalAppRepository(directory: directory, seed: { throw DataValidationError.invalid("Should not seed twice") }).load()
        XCTAssertEqual(seeds, 1)
        XCTAssertEqual(reloaded.preferences.employeeName, "Sam")
        XCTAssertEqual(reloaded.preferences.favouriteCocktailIDs, ["g"])
        XCTAssertEqual(reloaded.preferences.recentItems.first?.id, "g")
        XCTAssertEqual(reloaded.training.correct, 1)
        XCTAssertEqual(reloaded.stock[0].currentStock, 2.25)
        XCTAssertTrue(reloaded.prep[0].completed)
        XCTAssertEqual(reloaded.batches.count, 1)
    }
    func testCorruptSavedDataPreservedOnLoadAndSaveUntilExplicitReset() throws {
        let repo = LocalAppRepository(directory: directory, seed: fixture)
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: repo.stateURL)
        XCTAssertThrowsError(try repo.load())
        XCTAssertThrowsError(try repo.save(fixture()))
        XCTAssertEqual(try Data(contentsOf: repo.stateURL), corrupt)
        XCTAssertEqual(try repo.reset().venues.first?.id, "v")
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("state-before-reset.json")), corrupt)
    }
    func testInvalidSaveDoesNotReplaceLastGoodState() throws {
        let repo = LocalAppRepository(directory: directory, seed: fixture)
        var state = try repo.load()
        state.stock[0].currentStock = -2
        XCTAssertThrowsError(try repo.save(state))
        XCTAssertEqual(try repo.load().stock[0].currentStock, 1.5)
    }
    func testValidationRejectsUnknownVenueDuplicateIDAndFutureSchema() throws {
        var state = fixture(); state.stock[0].venueID = "missing"
        XCTAssertThrowsError(try SeedLoader.validate(snapshot: state))
        state = fixture(); state.cocktails.append(state.cocktails[0])
        XCTAssertThrowsError(try SeedLoader.validate(snapshot: state))
        state = fixture(); state.schemaVersion = 99
        XCTAssertThrowsError(try SeedLoader.validate(snapshot: state))
    }
    func testContentRepositoryRolesAndVenueIsolation() throws {
        let content = LocalContentRepository(appRepository: LocalAppRepository(directory: directory, seed: fixture))
        XCTAssertEqual(try content.fetchStock(venueID: "other"), [])
        XCTAssertThrowsError(try content.saveCocktail(Cocktail(id: "new", name: "New"), role: .bartender))
        try content.saveCocktail(Cocktail(id: "new", name: "New"), role: .manager)
        XCTAssertEqual(try content.fetchCocktails(venueID: "v").count, 2)
        var stock = try XCTUnwrap(content.fetchStock(venueID: "v").first)
        stock.currentStock = 4; stock.parLevel = 100
        try content.saveStock(stock, role: .bartender)
        XCTAssertEqual(try content.fetchStock(venueID: "v").first?.currentStock, 4)
        XCTAssertEqual(try content.fetchStock(venueID: "v").first?.parLevel, 6)
    }
    func testRecentHistoryDeduplicatesAndIsBounded() {
        var prefs = UserPreferences()
        for index in 0..<30 { prefs.recordRecent(id: String(index), kind: .cocktail) }
        prefs.recordRecent(id: "15", kind: .cocktail)
        XCTAssertEqual(prefs.recentItems.count, 20)
        XCTAssertEqual(prefs.recentItems.first?.id, "15")
        XCTAssertEqual(prefs.recentItems.filter { $0.id == "15" }.count, 1)
    }
}
