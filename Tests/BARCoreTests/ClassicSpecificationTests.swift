import XCTest
@testable import BARCore

final class ClassicSpecificationTests: XCTestCase {
    private func sidecar() throws -> Cocktail { try XCTUnwrap(SeedLoader.load().cocktails.first { $0.id == "house-sidecar" }) }
    func testEveryBundledClassicHasResearchAndUnambiguousIdentity() throws {
        let state = try SeedLoader.load(), library = try ClassicSpecifications.load()
        let classics = state.cocktails.filter { $0.venueID == nil || $0.isHouseClassic }
        XCTAssertEqual(classics.count, 77)
        XCTAssertEqual(library.count, 49)
        XCTAssertEqual(library.filter { $0.recommended != nil }.count, 48)
        for drink in classics {
            let ref = try XCTUnwrap(ClassicSpecifications.reference(for: drink.id, in: library), drink.name)
            XCTAssertFalse(ref.sources.isEmpty); XCTAssertFalse(ref.verifiedOn.isEmpty)
            if let recommended = ref.recommended {
                XCTAssertFalse(recommended.ingredients.isEmpty); XCTAssertFalse(recommended.prepInstructions.isEmpty)
                XCTAssertTrue(recommended.ingredients.allSatisfy { $0.stockProductID == nil })
            }
        }
    }
    func testCustomDefaultsAndSidecarTechniqueWithoutRewritingMeasures() throws {
        let original = try sidecar(), library = try ClassicSpecifications.load()
        let displayed = ClassicSpecifications.resolve(original, preferences: UserPreferences(), library: library)
        XCTAssertEqual(displayed.displaySpecification, .custom)
        XCTAssertEqual(displayed.ingredients, original.ingredients)
        XCTAssertTrue(displayed.method.lowercased().contains("shake"))
        XCTAssertTrue(displayed.prepInstructions.joined().lowercased().contains("strain"))
        XCTAssertEqual(original.method, "Muddle limes/sugar + build")
        XCTAssertEqual(original.ingredients.map(\.amount), [50, 25, 10])
    }
    func testGlobalAndPerClassicOverrideHierarchy() throws {
        let library = try ClassicSpecifications.load(), original = try sidecar()
        var prefs = UserPreferences()
        XCTAssertEqual(ClassicSpecifications.selection(for: original.id, preferences: prefs, library: library), .custom)
        prefs.classicDefault = .recommended
        XCTAssertEqual(ClassicSpecifications.selection(for: original.id, preferences: prefs, library: library), .recommended)
        prefs.classicOverrides["reference-sidecar"] = .custom
        XCTAssertEqual(ClassicSpecifications.selection(for: original.id, preferences: prefs, library: library), .custom)
        prefs.classicOverrides.removeValue(forKey: "reference-sidecar")
        XCTAssertEqual(ClassicSpecifications.selection(for: original.id, preferences: prefs, library: library), .recommended)
        prefs.classicDefault = .custom; prefs.classicOverrides["reference-sidecar"] = .recommended
        XCTAssertEqual(ClassicSpecifications.selection(for: original.id, preferences: prefs, library: library), .recommended)
    }
    func testPreferencesPersistAndOldPreferencesDefaultCustom() throws {
        var prefs = UserPreferences(); prefs.classicDefault = .recommended; prefs.classicOverrides["reference-sidecar"] = .custom
        XCTAssertEqual(try SeedLoader.makeDecoder().decode(UserPreferences.self, from: SeedLoader.makeEncoder().encode(prefs)), prefs)
        let old = try SeedLoader.makeDecoder().decode(UserPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(old.classicDefault, .custom); XCTAssertTrue(old.classicOverrides.isEmpty)
    }
    func testRepeatedSwitchingNeverMutatesEitherDataset() throws {
        var custom = try sidecar(); let original = custom
        let library = try ClassicSpecifications.load(), pristine = library
        var prefs = UserPreferences()
        for i in 0..<100 {
            prefs.classicDefault = i.isMultiple(of: 2) ? .custom : .recommended
            var displayed = ClassicSpecifications.resolve(custom, preferences: prefs, library: library)
            displayed.ingredients[0].amount = 999
        }
        XCTAssertEqual(custom, original); XCTAssertEqual(library, pristine)
        custom.ingredients[0].amount = 42
        prefs.classicDefault = .recommended
        let recommended = ClassicSpecifications.resolve(custom, preferences: prefs, library: library)
        XCTAssertEqual(recommended.ingredients.map(\.amount), [50, 20, 20])
        XCTAssertEqual(recommended.id, custom.id)
    }
    func testOwnerEditedMethodIsNotSilentlyReplaced() throws {
        var custom = try sidecar(); custom.method = "Approved prebatch service procedure"
        XCTAssertEqual(ClassicSpecifications.resolve(custom, preferences: UserPreferences(), library: try ClassicSpecifications.load()).method, custom.method)
    }
    func testPimmsDoesNotTeachShakingCarbonatedLemonade() throws {
        let state = try SeedLoader.load(), library = try ClassicSpecifications.load()
        let drink = try XCTUnwrap(state.cocktails.first { $0.id == "house-pimms" })
        let resolved = ClassicSpecifications.resolve(drink, preferences: UserPreferences(), library: library)
        XCTAssertTrue(resolved.method.lowercased().contains("build"))
        XCTAssertEqual(resolved.ingredients, drink.ingredients)
    }
    func testBatchCarriesRecommendedAndSavedCalculationSurvivesPreferenceChange() throws {
        let library = try ClassicSpecifications.load(), custom = try sidecar()
        var prefs = UserPreferences(); prefs.classicDefault = .recommended
        let selected = ClassicSpecifications.resolve(custom, preferences: prefs, library: library)
        let batch = BatchCalculator.calculate(cocktail: selected, serves: 35, wastagePercent: 0)
        XCTAssertEqual(batch.lines.map(\.quantity), [1750, 700, 700])
        var saved = SavedBatch(cocktailID: selected.id, name: selected.name, serves: 35, wastagePercent: 0)
        saved.specification = selected
        let reopened = try SeedLoader.makeDecoder().decode(SavedBatch.self, from: SeedLoader.makeEncoder().encode(saved))
        prefs.classicDefault = .custom
        XCTAssertEqual(reopened.specification?.displaySpecification, .recommended)
        XCTAssertEqual(BatchCalculator.calculate(cocktail: try XCTUnwrap(reopened.specification), serves: 35, wastagePercent: 0), batch)
    }
    func testTrainingRevisionChangesWithSpecButHistorySurvives() throws {
        let library = try ClassicSpecifications.load(), original = try sidecar()
        var prefs = UserPreferences()
        let custom = ClassicSpecifications.resolve(original, preferences: prefs, library: library)
        var progress = TrainingProgress(); progress.record(correct: true, cocktailID: custom.id)
        progress.masteredRevisions[custom.id] = TrainingProgress.revision(for: custom)
        XCTAssertTrue(progress.isMastered(custom))
        prefs.classicDefault = .recommended
        XCTAssertFalse(progress.isMastered(ClassicSpecifications.resolve(original, preferences: prefs, library: library)))
        XCTAssertEqual(progress.answered, 1); XCTAssertEqual(progress.correct, 1)
    }
    func testUnresolvedCustomIsExcludedFromTrainingButRecommendedIsUsable() throws {
        let library = try ClassicSpecifications.load(), state = try SeedLoader.load()
        let original = try XCTUnwrap(state.cocktails.first { $0.id == "house-bloody-mary" })
        XCTAssertFalse(ClassicSpecifications.resolve(original, preferences: UserPreferences(), library: library).trainingEligible)
        var prefs = UserPreferences(); prefs.classicDefault = .recommended
        XCTAssertTrue(ClassicSpecifications.resolve(original, preferences: prefs, library: library).trainingEligible)
    }
    func testDisplayedRecommendedCannotBeImportedIntoCustom() throws {
        var state = try SeedLoader.load(), prefs = UserPreferences(); prefs.classicDefault = .recommended
        let i = try XCTUnwrap(state.cocktails.firstIndex { $0.id == "house-sidecar" })
        state.cocktails[i] = ClassicSpecifications.resolve(state.cocktails[i], preferences: prefs, library: try ClassicSpecifications.load())
        XCTAssertThrowsError(try ContentImportService.merge(data: SeedLoader.makeEncoder().encode(state), preserving: SeedLoader.load()))
    }
    func testSearchFindsAlternateIngredientWithoutDuplicateCocktail() throws {
        let raw = try sidecar(), library = try ClassicSpecifications.load()
        var prefs = UserPreferences(); prefs.classicDefault = .recommended
        let drink = ClassicSpecifications.resolve(raw, preferences: prefs, library: library)
        let results = SearchService.search(query: "housebrand", cocktails: [drink], wines: [], venueID: "rockwater-hove", alternativeIngredients: [drink.id: ["Housebrand cognac"]])
        XCTAssertEqual(results.map(\.id), [raw.id])
    }
    func testQuizNeverIncludesUnresolvedRecipesAndAlwaysNamesContext() throws {
        let library = try ClassicSpecifications.load(), state = try SeedLoader.load()
        let drinks = state.cocktails.map { ClassicSpecifications.resolve($0, preferences: state.preferences, library: library) }
        let questions = QuizService.questions(cocktails: drinks, limit: 1_000)
        XCTAssertFalse(questions.contains { $0.cocktailID == "house-bloody-mary" })
        XCTAssertFalse(questions.isEmpty)
        XCTAssertTrue(questions.allSatisfy { $0.prompt.hasPrefix("Venue / Custom") || $0.prompt.hasPrefix("Recommended classic") || $0.prompt.hasPrefix("Classic reference") })
    }
}
