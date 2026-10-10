import XCTest
@testable import BARCore

final class ContentImportTests: XCTestCase {
    private func local() -> AppSnapshot {
        AppSnapshot(venues: [Venue(id: "v", name: "Venue")], preferences: UserPreferences(employeeName: "Sam", venueID: "v"), user: User(id: "employee", name: "Sam", venueID: "v", role: .bartender))
    }
    func testContentOnlyImportPreservesPersonalStateAndIdentity() throws {
        var original = local()
        original.preferences.favouriteCocktailIDs.insert("drink")
        original.training.record(correct: true, cocktailID: "drink")
        let data = Data(#"{"venues":[{"id":"v","name":"Updated venue"}],"cocktails":[{"id":"drink","name":"Updated recipe","venueID":"v"}],"user":{"id":"attacker","role":"admin"}}"#.utf8)
        let merged = try ContentImportService.merge(data: data, preserving: original)
        XCTAssertEqual(merged.venues, original.venues)
        XCTAssertEqual(merged.cocktails[0].name, "Updated recipe")
        XCTAssertEqual(merged.user, original.user)
        XCTAssertEqual(merged.preferences, original.preferences)
        XCTAssertEqual(merged.training, original.training)
    }
    func testImportRequiresActiveVenue() {
        let data = Data(#"{"venues":[{"id":"other","name":"Other venue"}]}"#.utf8)
        XCTAssertThrowsError(try ContentImportService.merge(data: data, preserving: local()))
    }
    func testImportRejectsInvalidRecordsWithoutModifyingCaller() {
        let original = local()
        let data = Data(#"{"venues":[{"id":"v","name":"Venue"}],"stock":[{"id":"gin","name":"Gin","venueID":"v","currentStock":-1}]}"#.utf8)
        XCTAssertThrowsError(try ContentImportService.merge(data: data, preserving: original))
        XCTAssertEqual(original, local())
    }
    func testImportRejectsMalformedJSON() {
        XCTAssertThrowsError(try ContentImportService.merge(data: Data("not-json".utf8), preserving: local()))
    }

    func testImportCannotSuppressFutureBundledMigrations() throws {
        var original = local()
        original.catalogueVersion = 25
        let data = Data(#"{"catalogueVersion":999999,"venues":[{"id":"v","name":"Venue"}]}"#.utf8)
        let merged = try ContentImportService.merge(data: data, preserving: original)
        XCTAssertEqual(merged.catalogueVersion, original.catalogueVersion)
    }
}
