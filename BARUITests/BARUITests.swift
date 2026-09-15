import XCTest

final class BARUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["home-search"].waitForExistence(timeout: 20))
    }
    private func capture(_ name: String) {
        // Allow native navigation animations to settle before recording visual evidence.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, swipes: Int = 8) {
        for _ in 0..<swipes { if element.exists && element.isHittable { return }; app.swipeUp() }
    }
    private func tapText(_ label: String) {
        let button = app.buttons.containing(.staticText, identifier: label).firstMatch
        let element = button.exists ? button : app.staticTexts[label].firstMatch
        reveal(element); XCTAssertTrue(element.exists, "Missing \(label)"); element.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }
    private func tab(_ name: String) { app.tabBars.buttons[name].tap() }

    func testCocktailBatchFavouritesAndRelaunch() throws {
        capture("01 Home")
        tapText("Cocktails")
        XCTAssertTrue(app.navigationBars["Cocktails"].exists)
        capture("02 Cocktail library")
        tapText("Sea Glass")
        XCTAssertTrue(app.buttons["favourite-cocktail"].waitForExistence(timeout: 5))
        capture("03 Cocktail detail")
        app.buttons["favourite-cocktail"].tap()
        let batch = app.buttons["batch-button"]
        reveal(batch); batch.tap()
        XCTAssertTrue(app.navigationBars["Batch Calculator"].waitForExistence(timeout: 5))
        capture("04 Batch calculator")
        XCTAssertEqual(app.textFields["batch-serves"].value as? String, "25")
        XCTAssertTrue(app.staticTexts["901.25ml"].exists || app.staticTexts["901.25ml"].exists)
        app.buttons["50 serves"].tap()
        XCTAssertEqual(app.textFields["batch-serves"].value as? String, "50")
        let save = app.buttons["Save batch"]
        reveal(save); save.tap()
        XCTAssertTrue(app.buttons["Batch saved"].exists)
        let prep = app.buttons["Start prep"]
        reveal(prep); prep.tap()
        XCTAssertTrue(app.buttons["Added to today’s prep"].exists)
        app.terminate(); app.launchArguments = ["--uitesting", "--keep-state"]; app.launch()
        tab("Profile")
        tapText("Favourites")
        XCTAssertTrue(app.staticTexts["Sea Glass"].waitForExistence(timeout: 5))
        capture("05 Persisted favourites")
    }
    func testUniversalSearchWineAndClassics() throws {
        tab("Search")
        let field = app.textFields["universal-search"]
        field.tap(); field.typeText("negroni\n")
        XCTAssertTrue(app.staticTexts["Negroni"].waitForExistence(timeout: 5))
        capture("06 Universal search")
        tapText("Negroni")
        XCTAssertTrue(app.buttons["favourite-cocktail"].waitForExistence(timeout: 5))
        tab("Home")
        tapText("Classics")
        XCTAssertTrue(app.navigationBars["Classics"].exists)
        capture("07 Classics")
        app.navigationBars.buttons.firstMatch.tap()
        tapText("Wine Finder")
        XCTAssertTrue(app.navigationBars["Wine Finder"].exists)
        app.buttons["Dry"].tap(); app.buttons["Crisp"].tap()
        capture("08 Wine Finder")
        let wineSearch = app.textFields["universal-search"]
        reveal(wineSearch); wineSearch.tap(); wineSearch.typeText("seafood\n")
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["Let’s broaden the choice"].exists)
        capture("09 Wine food pairing")
        app.swipeDown(); app.swipeDown()
        app.buttons["Clear search"].tap()
        wineSearch.tap(); wineSearch.typeText("Marlborough\n")
        tapText("Sauvignon Blanc Awatere, Spoke")
        XCTAssertTrue(app.buttons["Favourite wine"].waitForExistence(timeout: 5))
        app.buttons["Favourite wine"].tap()
        capture("09b Wine detail")
    }
    func testPrepStockAndProfile() throws {
        tab("Prep"); capture("10 Prep")
        let firstPrep = app.scrollViews.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Citrus")).firstMatch
        if firstPrep.exists { firstPrep.tap() } else { tapText("Citrus cordial") }
        capture("11 Prep recipe")
        let complete = app.buttons["Mark prepared to target"]
        reveal(complete); complete.tap()
        XCTAssertTrue(app.staticTexts["Prepared and ready"].exists || app.staticTexts["Ready for service"].exists)
        tab("Stock"); capture("12 Stock")
        app.buttons["open-order"].tap()
        capture("13 Suggested order")
        XCTAssertTrue(app.buttons["add-products"].exists)
        tab("Profile"); capture("14 Profile")
        XCTAssertTrue(app.navigationBars["Profile"].exists)
    }
    func testPrepSwipeDeletePersists() throws {
        tab("Prep")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "prep-row-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let rowIdentifier = row.identifier
        let deletedLabel = row.label
        row.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertFalse(app.buttons[rowIdentifier].exists)
        app.terminate()
        app.launchArguments = ["--uitesting", "--keep-state"]
        app.launch()
        tab("Prep")
        XCTAssertFalse(app.staticTexts[deletedLabel].exists)
    }
    func testLearnFlashcardsAndQuiz() throws {
        tapText("Learn"); capture("15 Learn")
        tapText("Cocktail flashcards")
        let revealButton = app.buttons["Reveal specification"]
        reveal(revealButton); revealButton.tap()
        capture("16 Flashcard answer")
        let knew = app.buttons["I knew it"]; reveal(knew); knew.tap()
        app.navigationBars.buttons.firstMatch.tap()
        tapText("Recipe quiz")
        capture("17 Recipe quiz")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "QUESTION")).firstMatch.exists)
        app.buttons["quiz-option-0"].tap()
        let next = app.buttons["Next question"]
        reveal(next); next.tap()
        XCTAssertTrue(app.staticTexts["QUESTION 2 OF 10"].isHittable)
    }
    func testStockCountAndPreferencesPersist() throws {
        openStocktake()
        let search = app.textFields["universal-search"]
        search.tap(); search.typeText("Tanqueray\n")
        app.swipeUp()
        let quarter = app.buttons["Set open bottle to ¼"]
        reveal(quarter); quarter.tap()
        XCTAssertTrue(app.buttons["Edit Tanqueray current count, 1.25 bottle"].exists)
        capture("18 Fractional stock count")
        tab("Profile")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        let name = app.textFields["employee-name"]
        name.tap()
        if let current = name.value as? String { name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)) }
        name.typeText("Sam\n")
        app.terminate(); app.launchArguments = ["--uitesting", "--keep-state"]; app.launch()
        XCTAssertTrue(app.staticTexts["Good morning, Sam,"].exists || app.staticTexts["Good afternoon, Sam,"].exists || app.staticTexts["Good evening, Sam,"].exists)
        openStocktake()
        app.textFields["universal-search"].tap(); app.textFields["universal-search"].typeText("Tanqueray\n")
        app.swipeUp()
        XCTAssertTrue(app.buttons["Edit Tanqueray current count, 1.25 bottle"].exists)
        app.buttons["Edit Tanqueray current count, 1.25 bottle"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        if let current = amount.value as? String { amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)) }
        amount.typeText("1000.5")
        app.buttons["Save amount"].tap()
        let largeCount = app.buttons["Edit Tanqueray current count, 1,000.5 bottle"]
        XCTAssertTrue(largeCount.waitForExistence(timeout: 5))
        largeCount.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "1000.5")
        capture("19 Large count editor")
        app.buttons["Save amount"].tap()
        XCTAssertTrue(largeCount.waitForExistence(timeout: 5))
    }

    private func openStocktake() {
        tab("Profile")
        reveal(app.buttons["Manager"]); app.buttons["Manager"].tap()
        tapText("Stocktake")
    }
    func testNewStockListsAndSharedCatalogue() throws {
        tab("Stock"); capture("Stock landing")
        app.buttons["open-restock"].tap()
        XCTAssertTrue(app.staticTexts["Nothing needed yet."].exists)
        app.buttons["add-products"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Aperol")
        let add = app.buttons["Add Aperol"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        try XCTUnwrap(app.buttons.matching(identifier: "Increase Aperol").allElementsBoundByIndex.first { $0.isHittable }).tap()
        capture("Product picker")
        app.buttons["picker-done"].tap()
        XCTAssertTrue(app.buttons["picker-done"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Edit Aperol quantity").firstMatch.value as? String, "2")
        capture("Restock working list")
        app.terminate(); app.launchArguments = ["--uitesting", "--keep-state"]; app.launch()
        tab("Stock"); app.buttons["open-restock"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "Edit Aperol quantity").firstMatch.value as? String, "2")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["open-order"].tap()
        XCTAssertTrue(app.staticTexts["No products added."].exists)
        app.navigationBars.buttons.firstMatch.tap()
        tapText("Products & photos")
        app.buttons["Add Product"].tap()
        let name = app.textFields["product-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Service Test Soda")
        capture("Product editor with photo controls")
        XCTAssertTrue(app.buttons["Choose photo"].exists)
        app.buttons["Save"].tap()
        tab("Search")
        let field = app.textFields["universal-search"]
        field.tap(); field.typeText("Service Test Soda\n")
        XCTAssertTrue(app.staticTexts["Service Test Soda"].waitForExistence(timeout: 5))
        tapText("Service Test Soda")
        app.buttons["Add to Stock Order"].tap()
        XCTAssertTrue(app.buttons["Added to Stock Order"].exists)
        capture("Shared product detail")
    }
    func testHouseSpecsAndFoodSearch() throws {
        tapText("Cocktails"); tapText("Sea Glass")
        XCTAssertTrue(app.buttons["favourite-cocktail"].waitForExistence(timeout: 5))
        capture("Updated Sea Glass recipe")
        let batch = app.buttons["batch-button"]; reveal(batch); batch.tap()
        XCTAssertTrue(app.staticTexts["901.25ml"].waitForExistence(timeout: 5))
        capture("House recipe batch")
        tab("Search")
        let field = app.textFields["universal-search"]
        field.tap(); field.typeText("steak\n")
        XCTAssertFalse(app.staticTexts["No matches yet"].exists)
        capture("Steak wine search")
        app.buttons["Clear search"].tap(); field.tap(); field.typeText("fish\n")
        XCTAssertFalse(app.staticTexts["No matches yet"].exists)
        capture("Fish wine search")
    }

}
