import XCTest
@testable import BARCore

final class HouseUpdateTests: XCTestCase {
    func testEverySuppliedSpecAndServiceOnlyFoam() throws {
        let state = try SeedLoader.load()
        XCTAssertEqual(state.cocktails.filter { $0.sourceReference?.hasPrefix("cocktail_specs") == true }.count, 16)
        XCTAssertEqual(state.cocktails.filter(\.isHouseClassic).count, 46)
        let sea = try XCTUnwrap(state.cocktails.first { $0.name == "Sea Glass" })
        XCTAssertEqual(sea.ingredients.first { $0.name == "Havana 3" }?.amount, 35)
        let batch = BatchCalculator.calculate(cocktail: sea, serves: 25)
        XCTAssertEqual(try XCTUnwrap(batch.lines.first { $0.ingredient.name == "Havana 3" }).quantity, 901.25, accuracy: 0.001)
        XCTAssertEqual(batch.lines.first { $0.ingredient.name == "Pineapple Foam Top" }?.quantity, 2500)
        XCTAssertEqual(batch.lines.first { $0.ingredient.name == "Pineapple Foam Top" }?.behaviour, .serviceOnly)
        let bitter = try XCTUnwrap(state.cocktails.first { $0.name == "Italian Bitter" })
        XCTAssertEqual(bitter.ingredients.first { $0.name == "Peroni" }?.amount, 150)
        let dry = try XCTUnwrap(state.cocktails.first { $0.name == "Gin Martini" })
        let wet = try XCTUnwrap(state.cocktails.first { $0.name == "Gin Martini (Wet)" })
        XCTAssertEqual(dry.ingredients.first { $0.name == "Martini Extra Dry" }?.amount, 10)
        XCTAssertEqual(wet.ingredients.first { $0.name == "Martini Extra Dry" }?.amount, 20)
        XCTAssertFalse(BatchCalculator.calculate(cocktail: dry, serves: 10).lines.contains { $0.ingredient.name.contains("Dirty") })
    }
    func testRealMenuFoodSearchesAndSharedProducts() throws {
        let state = try SeedLoader.load()
        for query in ["steak", "fish", "wine for steak", "what goes with fish", "ribeye"] {
            let results = SearchService.search(query: query, cocktails: state.cocktails, wines: state.wines, products: state.products, venueID: "rockwater-hove")
            XCTAssertTrue(results.contains { $0.kind == .wine }, query)
            XCTAssertFalse(WineRecommender.recommend(wines: state.wines, query: query).isEmpty, query)
        }
        XCTAssertTrue(SearchService.search(query: "negrni", cocktails: state.cocktails, wines: [], venueID: "rockwater-hove").contains { $0.title == "Negroni" })
        let new = Product(venueID: "rockwater-hove", name: "New Ginger Beer", brand: "Test", category: "Mixers")
        XCTAssertEqual(SearchService.search(query: "new ginger", cocktails: [], wines: [], products: [new], venueID: new.venueID).first?.id, new.id)
        XCTAssertEqual(StockListService.search([new], venueID: new.venueID, query: "test mixers").count, 1)
    }
    func testListsImagesAndMigrationSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = LocalAppRepository(directory: directory)
        var state = try repo.load()
        var product = Product(venueID: "rockwater-hove", name: "Test product")
        product.imageData = Data([1, 2, 3])
        state.products.append(product)
        StockListService.add(product, kind: .restock, to: &state.stockLists)
        StockListService.add(product, kind: .restock, to: &state.stockLists)
        StockListService.add(product, kind: .order, to: &state.stockLists)
        XCTAssertEqual(state.stockLists.map(\.quantity), [2, 1])
        state.stockLists.append(StockListItem(venueID: product.venueID, kind: .restock, name: "Custom", quantity: 3))
        state.preferences.employeeName = "Saved name"
        state.catalogueVersion = 1
        let deletedID = state.products[0].id
        state.products[0].isActive = false
        try repo.save(state)
        let reopened = try LocalAppRepository(directory: directory).load()
        XCTAssertEqual(reopened.preferences.employeeName, "Saved name")
        XCTAssertEqual(reopened.stockLists, state.stockLists)
        XCTAssertEqual(reopened.products.first { $0.id == product.id }?.imageData, product.imageData)
        XCTAssertEqual(reopened.products.first { $0.id == deletedID }?.isActive, false)
        XCTAssertEqual(reopened.catalogueVersion, 2)
        var list = reopened.stockLists
        StockListService.setQuantity(-1, id: list[0].id, venueID: product.venueID, in: &list)
        XCTAssertEqual(list.count, 2)
        StockListService.clear(.restock, venueID: product.venueID, in: &list)
        XCTAssertEqual(StockListService.text(list, kind: .order, venueID: product.venueID), "STOCK ORDER\n\nTest product x1")
    }
}
