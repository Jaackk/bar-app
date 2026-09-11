import XCTest
@testable import BARCore

final class SearchAndWineTests: XCTestCase {
    func testExactNameOutranksIngredientMatch() {
        let exact = Cocktail(id: "a", name: "Ginger", ingredients: [Ingredient(name: "Rum")])
        let ingredient = Cocktail(id: "b", name: "Ginger Sour", ingredients: [Ingredient(name: "Ginger")])
        let result = SearchService.search(query: "ginger", cocktails: [ingredient, exact], wines: [], venueID: "v")
        XCTAssertEqual(result.first?.id, "a")
    }
    func testPartialNameCaseAndDiacriticMatch() {
        let drink = Cocktail(id: "a", name: "Piña Colada")
        XCTAssertEqual(SearchService.search(query: "PINA col", cocktails: [drink], wines: [], venueID: "v").first?.id, "a")
    }
    func testMultipleIngredientAndStyleTokens() {
        let good = Cocktail(id: "a", name: "Coastal", baseSpirit: "Gin", flavourTags: ["Citrus"], ingredients: [Ingredient(name: "Gin")])
        let bad = Cocktail(id: "b", name: "Gin and tonic", baseSpirit: "Gin")
        XCTAssertEqual(SearchService.search(query: "gin citrus", cocktails: [bad, good], wines: [], venueID: "v").map(\.id), ["a"])
    }
    func testNoEggExcludesEggIngredientAndAllergen() {
        let egg = Cocktail(id: "a", name: "Egg sour", ingredients: [Ingredient(name: "Egg white")])
        let allergen = Cocktail(id: "b", name: "Foam sour", allergens: ["Egg"])
        let good = Cocktail(id: "c", name: "Sour", serviceNotes: "Contains no egg")
        XCTAssertEqual(SearchService.search(query: "no egg", cocktails: [egg, allergen, good], wines: [], venueID: "v").map(\.id), ["c"])
    }
    func testVenueOverrideByNameAndExplicitID() {
        let global = Cocktail(id: "g", name: "Negroni")
        let local = Cocktail(id: "l", name: "NEGRONI", venueID: "a")
        let other = Cocktail(id: "x", name: "Other venue", venueID: "b")
        XCTAssertEqual(VenueResolver.cocktails([global, local, other], venueID: "a").map(\.id), ["l"])
        let renamed = Cocktail(id: "r", name: "House Negroni", venueID: "a", overridesCocktailID: "g")
        XCTAssertEqual(VenueResolver.cocktails([global, renamed], venueID: "a").map(\.id), ["r"])
        XCTAssertEqual(VenueResolver.cocktails([global, renamed], venueID: "b").map(\.id), ["g"])
    }
    func testInactiveAndOtherVenueContentExcluded() {
        let result = SearchService.search(query: "", cocktails: [Cocktail(id: "x", name: "X", isActive: false)], wines: [Wine(id: "w", name: "W", venueID: "other")], prep: [PrepItem(id: "p", name: "P", venueID: "other")], venueID: "v")
        XCTAssertTrue(result.isEmpty)
    }
    private var wines: [Wine] {
        [Wine(id: "white", name: "Coastal white", grape: "Sauvignon Blanc", colour: .white, body: 2, sweetness: 1, acidity: 5, flavourNotes: ["Mineral", "Citrus"], foodPairings: ["Seafood", "Sea bass", "Shellfish"]),
         Wine(id: "red", name: "Valley red", grape: "Malbec", colour: .red, body: 5, sweetness: 1, acidity: 3, tannin: 4, flavourNotes: ["Oaky", "Black fruit"], foodPairings: ["Steak", "Beef"], similarTo: ["Cabernet Sauvignon"]),
         Wine(id: "sweet", name: "Dessert gold", grape: "Muscat", colour: .dessert, body: 3, sweetness: 5, foodPairings: ["Dessert", "Cheese"])]
    }
    func testDryCrispTasteConstraints() {
        XCTAssertEqual(WineRecommender.recommend(wines: wines, tastes: ["Dry", "Crisp"]).map(\.id), ["white"])
    }
    func testSteakPairingRanksRedAndExplains() {
        let result = WineRecommender.recommend(wines: wines, query: "What goes with steak?")
        XCTAssertEqual(result.first?.id, "red")
        XCTAssertTrue(result.first?.reasons.contains("Pairs with steak") == true)
    }
    func testFullBodiedRedAndFamiliarGrape() {
        XCTAssertEqual(WineRecommender.recommend(wines: wines, query: "full bodied red").first?.id, "red")
        XCTAssertEqual(WineRecommender.recommend(wines: wines, query: "I normally drink Sauvignon Blanc").first?.id, "white")
    }
    func testSimilarWineMetadataAndColourFilter() {
        XCTAssertEqual(WineRecommender.recommend(wines: wines, query: "similar to Cabernet").first?.id, "red")
        XCTAssertTrue(WineRecommender.recommend(wines: wines, tastes: ["Sweet"], colour: .red).isEmpty)
    }
    func testWineUniversalSearchUsesStructuredAttributes() {
        XCTAssertEqual(SearchService.search(query: "dry white", cocktails: [], wines: wines, venueID: "v").map(\.id), ["white"])
        XCTAssertEqual(SearchService.search(query: "sea bass", cocktails: [], wines: wines, venueID: "v").first?.id, "white")
    }
    func testUnknownWineQueryReturnsEmpty() { XCTAssertTrue(WineRecommender.recommend(wines: wines, query: "unfindablegrape").isEmpty) }
}
