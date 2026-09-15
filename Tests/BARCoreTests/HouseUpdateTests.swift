import XCTest
@testable import BARCore

final class HouseUpdateTests: XCTestCase {
    func testPrepDeletionPersistsForExampleAndUserPrep() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalAppRepository(directory: directory)
        var state = try repository.load()
        let example = try XCTUnwrap(state.prep.first)
        let userPrep = PrepItem(id: "user-prep", name: "Fresh lime juice", venueID: "rockwater-hove", targetAmount: 1, recipeYieldAmount: 1, isSample: false)
        state.prep.append(userPrep)
        try repository.save(state)

        state.prep.removeAll { $0.id == example.id }
        try repository.save(state)
        var reopened = try LocalAppRepository(directory: directory).load()
        XCTAssertFalse(reopened.prep.contains { $0.id == example.id })
        XCTAssertTrue(reopened.prep.contains { $0.id == userPrep.id })

        reopened.prep.removeAll { $0.id == userPrep.id }
        try repository.save(reopened)
        XCTAssertFalse(try LocalAppRepository(directory: directory).load().prep.contains { $0.id == userPrep.id })
    }
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
    func testProductCatalogueUsesCategoriesAliasesAndServiceConsumables() throws {
        let state = try SeedLoader.load()
        let absolut = try XCTUnwrap(state.products.first { $0.name == "Absolut Vodka" })
        XCTAssertEqual(absolut.category, "Vodka")
        XCTAssertTrue(StockListService.search(state.products, venueID: "rockwater-hove", query: "absolut vodka").contains { $0.id == absolut.id })
        for name in ["Lemons", "Limes", "Mint", "Basil", "Cocktail Cherries", "Ice Cubes", "Pineapple Foam"] {
            XCTAssertNotNil(state.products.first { $0.name == name }, name)
        }
        let passion = StockListService.search(state.products, venueID: "rockwater-hove", query: "passionfruit")
        XCTAssertTrue(passion.contains { $0.name.localizedCaseInsensitiveContains("Passion Fruit") })
    }
    func testBundledWineAndClassicCocktailImageryIsAssociated() throws {
        let state = try SeedLoader.load()
        for id in [
            "menu-prosecco-collezione-96-brut-masottina",
            "menu-assyrtiko-terre-grec-theopetra-estate",
            "menu-sauvignon-blanc-romans-bay-lomond-wines",
            "menu-pecorino-offida-belato-carminucci",
            "menu-sancerre-magie-des-caillottes-renaissance-fleuriet-freres",
            "menu-godello-finca-os-cobatos"
        ] {
            XCTAssertFalse(try XCTUnwrap(state.products.first { $0.id == id }).imageName.isEmpty, id)
        }
        let classics = VenueResolver.cocktails(state.cocktails, venueID: "rockwater-hove")
        for id in ["house-espresso-martini", "house-negroni", "house-margarita", "house-pina-colada", "house-old-fashioned", "house-caipirinha"] {
            XCTAssertFalse(try XCTUnwrap(classics.first { $0.id == id }).imageName.isEmpty, id)
        }
    }
    func testWineFinderUsesCanonicalProductImageWithoutCrossResolvingCuvées() throws {
        let state = try SeedLoader.load()
        let hoveWines = state.wines.filter { $0.id.hasPrefix("hove-wine-") }
        XCTAssertFalse(hoveWines.isEmpty)
        XCTAssertTrue(hoveWines.allSatisfy { $0.productID != nil }, "Every bundled Hove wine must have a stable stock-catalogue image relationship.")
        let wine = try XCTUnwrap(state.wines.first { $0.id == "hove-wine-assyrtiko-terre-grec-theopetra-estate" })
        let product = try XCTUnwrap(state.products.first { $0.id == "menu-assyrtiko-terre-grec-theopetra-estate" })
        XCTAssertEqual(wine.productID, product.id)
        XCTAssertEqual(WineProductResolver.imageSource(for: wine, products: state.products), .bundledProductImage(product))

        var custom = product
        custom.imageData = Data([1, 2, 3])
        XCTAssertEqual(WineProductResolver.imageSource(for: wine, products: [custom]), .customProductImage(custom))

        let unknown = Wine(id: "unknown", name: "Unlisted Cuvée", imageName: "")
        XCTAssertEqual(WineProductResolver.imageSource(for: unknown, products: [product]), .fallback)

        let differentCuvée = Wine(id: "other", name: "Assyrtiko Terre Grec Reserve", imageName: "")
        XCTAssertNil(WineProductResolver.product(for: differentCuvée, in: [product]))
    }
    func testDuplicateProductMigrationRepointsListsAndPreservesAliases() throws {
        var state = try SeedLoader.load()
        state.catalogueVersion = 15
        let venueID = "rockwater-hove"
        var duplicate = Product(id: "spec-jameson", venueID: venueID, name: "Jameson", category: "Whisky / Whiskey", imageName: "jameson")
        duplicate.imageData = Data([7, 8, 9])
        state.products.append(duplicate)
        state.stock.append(StockItem(id: duplicate.id, name: duplicate.name, venueID: venueID, category: duplicate.category, currentStock: 2, parLevel: 4))
        state.stockLists.append(StockListItem(venueID: venueID, kind: .restock, productID: duplicate.id, name: duplicate.name, quantity: 2))
        state.stockLists.append(StockListItem(venueID: venueID, kind: .restock, productID: "menu-jameson-irish-whiskey", name: "Jameson Irish Whiskey", quantity: 1))

        let migrated = try MenuMigration.apply(to: state)
        XCTAssertFalse(migrated.products.contains { $0.id == duplicate.id })
        XCTAssertEqual(migrated.stock.first { $0.id == "menu-jameson-irish-whiskey" }?.name, "Jameson Irish Whiskey")
        XCTAssertEqual(migrated.products.first { $0.id == "menu-jameson-irish-whiskey" }?.imageData, Data([7, 8, 9]))
        let list = try XCTUnwrap(migrated.stockLists.first { $0.kind == .restock && $0.productID == "menu-jameson-irish-whiskey" })
        XCTAssertEqual(list.quantity, 3)
        XCTAssertEqual(migrated.stockLists.filter { $0.kind == .restock && $0.productID == "menu-jameson-irish-whiskey" }.count, 1)
        let results = SearchService.search(query: "Jamesons", cocktails: [], wines: [], products: migrated.products, venueID: venueID)
        XCTAssertEqual(results.filter { $0.kind == .product && $0.id == "menu-jameson-irish-whiskey" }.count, 1)
        XCTAssertFalse(results.contains { $0.id == "menu-jameson-irish-whiskey" && $0.title != "Jameson Irish Whiskey" })
        XCTAssertEqual(SearchService.search(query: "Casamigos Blanca", cocktails: [], wines: [], products: migrated.products, venueID: venueID).filter { $0.id == "menu-casamigos-blanco" }.count, 1)
        XCTAssertEqual(SearchService.search(query: "Tanquary N10", cocktails: [], wines: [], products: migrated.products, venueID: venueID).filter { $0.id == "menu-tanqueray-n-ten" }.count, 1)
        XCTAssertNotNil(migrated.products.first { $0.id == "menu-casamigos-reposado" })
        XCTAssertNotNil(migrated.products.first { $0.id == "menu-tanqueray" })
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
        XCTAssertEqual(reopened.catalogueVersion, 20)
        var list = reopened.stockLists
        StockListService.setQuantity(-1, id: list[0].id, venueID: product.venueID, in: &list)
        XCTAssertEqual(list.count, 2)
        StockListService.clear(.restock, venueID: product.venueID, in: &list)
        XCTAssertEqual(StockListService.text(list, kind: .order, venueID: product.venueID), "STOCK ORDER\n\nTest product x1")
    }
}
