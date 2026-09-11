import XCTest
@testable import BARCore

final class OperationsTests: XCTestCase {
    func testStockShortfallAndOrderRounding() {
        let stock = StockItem(id: "gin", name: "Gin", currentStock: 1.5, parLevel: 6)
        XCTAssertEqual(stock.requiredStock, 4.5)
        XCTAssertEqual(stock.orderQuantity, 5)
        XCTAssertEqual(StockCalculator.orderText(items: [stock]), "Suggested order\nGin × 5")
    }
    func testStockAtOrAboveParNeedsNoOrder() {
        XCTAssertEqual(StockCalculator.required(current: 7, par: 6), 0)
        XCTAssertEqual(StockCalculator.order(items: [StockItem(id: "x", name: "X", currentStock: 6, parLevel: 6)]), [])
    }
    func testInvalidStockDoesNotProduceInvalidNumbers() {
        XCTAssertEqual(StockCalculator.required(current: .nan, par: 6), 0)
        XCTAssertEqual(StockCalculator.required(current: -2, par: 6), 6)
        XCTAssertEqual(StockCalculator.wholeQuantity(.infinity), 0)
    }
    func testPrepCompletionAndRequiredQuantity() {
        var prep = PrepItem(id: "p", name: "Syrup", currentAmount: 0.8, targetAmount: 3)
        XCTAssertEqual(prep.requiredAmount, 2.2, accuracy: 0.00001)
        XCTAssertEqual(prep.progress, 0.8 / 3, accuracy: 0.00001)
        prep.markComplete(at: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(prep.currentAmount, 3)
        XCTAssertEqual(prep.requiredAmount, 0)
        XCTAssertEqual(prep.progress, 1)
        XCTAssertTrue(prep.completed)
    }
    func testQuestionsDerivedFromActualDataHaveOneCorrectOption() throws {
        let drinks = try SeedLoader.load().cocktails
        for kind in QuizKind.allCases {
            let questions = QuizService.questions(cocktails: drinks, kind: kind, limit: 20)
            XCTAssertEqual(questions.count, 20)
            for question in questions {
                XCTAssertEqual(question.options.filter(question.isCorrect).count, 1)
                XCTAssertEqual(Set(question.options).count, question.options.count)
                XCTAssertTrue(drinks.contains { $0.id == question.cocktailID })
            }
        }
    }
    func testEmptyOrSingleEquivalentRecipeCannotGenerateAmbiguousQuiz() {
        XCTAssertTrue(QuizService.questions(cocktails: []).isEmpty)
        let drink = Cocktail(id: "a", name: "One", ingredients: [Ingredient(name: "Gin")])
        XCTAssertTrue(QuizService.questions(cocktails: [drink]).isEmpty)
    }
    func testTrainingAccuracyAndMasteryTrackAnswers() {
        var progress = TrainingProgress()
        XCTAssertEqual(progress.accuracy, 0)
        progress.record(correct: true, cocktailID: "a")
        progress.record(correct: false, cocktailID: "a")
        XCTAssertEqual(progress.accuracy, 0.5)
        XCTAssertEqual(progress.answered, 2)
        XCTAssertTrue(progress.masteredCocktailIDs.isEmpty)
    }
}
