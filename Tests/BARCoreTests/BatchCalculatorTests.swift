import XCTest
@testable import BARCore

final class BatchCalculatorTests: XCTestCase {
    private let cocktail = Cocktail(id: "test", name: "Test sour", ingredients: [
        Ingredient(id: "rum", name: "Rum", amount: 40, bottleSize: 700),
        Ingredient(id: "lime", name: "Lime juice", amount: 20)
    ])
    func testTenServes() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 10, wastagePercent: 0).lines[0].quantity, 400) }
    func testTwentyFiveServesThreePercent() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 25).lines[0].quantity, 1_030, accuracy: 0.00001) }
    func testFiftyServes() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 50, wastagePercent: 0).totalVolumeML, 3_000) }
    func testCustomServes() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 37, wastagePercent: 0).lines[0].quantity, 1_480) }
    func testDifferentWastage() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 10, wastagePercent: 8).lines[0].quantity, 432, accuracy: 0.00001) }
    func testMillilitresToLitres() {
        let result = BatchCalculator.calculate(cocktail: cocktail, serves: 25)
        XCTAssertEqual(result.lines[0].litres!, 1.03, accuracy: 0.00001)
        XCTAssertEqual(MeasurementFormatter.litres(fromML: 750), 0.75)
    }
    func testWholeBottleCeiling() { XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 25).lines[0].bottles, 2) }
    func testExactBottleDoesNotRoundUpForFloatingPointNoise() {
        let drink = Cocktail(id: "t", name: "Test", ingredients: [Ingredient(name: "Rum", amount: 70, bottleSize: 700)])
        XCTAssertEqual(BatchCalculator.calculate(cocktail: drink, serves: 10, wastagePercent: 0).lines[0].bottles, 1)
    }
    func testZeroAndNegativeServesAreSafe() {
        for serves in [0, -12] {
            let result = BatchCalculator.calculate(cocktail: cocktail, serves: serves)
            XCTAssertEqual(result.serves, 0)
            XCTAssertEqual(result.totalVolumeML, 0)
            XCTAssertEqual(result.lines[0].bottles, 0)
        }
    }
    func testServiceOnlyExcludedFromBatchVolumeAndWastage() {
        let drink = Cocktail(id: "t", name: "Fizz", ingredients: [Ingredient(name: "Soda", amount: 100, batchable: false, batchBehaviour: .serviceOnly)])
        let result = BatchCalculator.calculate(cocktail: drink, serves: 10)
        XCTAssertEqual(result.lines[0].quantity, 1_000)
        XCTAssertEqual(result.totalVolumeML, 0)
        XCTAssertTrue(result.notes.contains { $0.contains("during service") })
    }
    func testNonBatchableIceExcluded() {
        let drink = Cocktail(id: "t", name: "Icy", ingredients: [Ingredient(name: "Ice", amount: 5, unit: .piece, batchBehaviour: .nonBatchable)])
        XCTAssertTrue(BatchCalculator.calculate(cocktail: drink, serves: 25).lines.isEmpty)
    }
    func testGarnishCountsUseWholePiecesWithoutWastage() {
        let drink = Cocktail(id: "t", name: "Garnish", ingredients: [Ingredient(name: "Lime", amount: 0.5, unit: .piece, batchBehaviour: .garnishCount)])
        let result = BatchCalculator.calculate(cocktail: drink, serves: 25)
        XCTAssertEqual(result.lines[0].quantity, 13)
        XCTAssertNil(result.lines[0].volumeML)
    }
    func testPrepareSeparatelyScalesWithWastageButNotIntoBaseVolume() {
        let drink = Cocktail(id: "t", name: "Foamy", ingredients: [Ingredient(name: "Foam", amount: 30, batchBehaviour: .prepareSeparately, bottleSize: 1_000)])
        let result = BatchCalculator.calculate(cocktail: drink, serves: 25)
        XCTAssertEqual(result.lines[0].quantity, 772.5, accuracy: 0.00001)
        XCTAssertEqual(result.totalVolumeML, 0)
        XCTAssertEqual(result.lines[0].bottles, 1)
    }
    func testVolumeUnitsAndUnmeasuredTops() {
        let drink = Cocktail(id: "t", name: "Mixed units", ingredients: [Ingredient(name: "Rum", amount: 4, unit: .cl), Ingredient(name: "Juice", amount: 0.02, unit: .litre), Ingredient(name: "Foam", unit: .top, batchBehaviour: .prepareSeparately)])
        let result = BatchCalculator.calculate(cocktail: drink, serves: 10, wastagePercent: 0)
        XCTAssertEqual(result.totalVolumeML, 600)
        XCTAssertNil(result.lines.last?.litres)
        XCTAssertEqual(result.lines.last?.measurement, "At service / to taste")
    }
    func testInvalidWastageCannotPropagateNaN() {
        XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 10, wastagePercent: .nan).totalVolumeML, 600)
        XCTAssertEqual(BatchCalculator.calculate(cocktail: cocktail, serves: 10, wastagePercent: -3).wastagePercent, 0)
    }
    func testFractionalBottleAndDashDropMeasuresRemainExact() throws {
        let drink = Cocktail(id: "t", name: "Measured", ingredients: [Ingredient(name: "Gin", amount: 25, bottleSize: 700), Ingredient(name: "Bitters", amount: 1.5, unit: .dash), Ingredient(name: "Foamer", amount: 3, unit: .drop, batchBehaviour: .serviceOnly)])
        let batch = BatchCalculator.calculate(cocktail: drink, serves: 35, wastagePercent: 0)
        XCTAssertEqual(try XCTUnwrap(batch.lines[0].volumeML) / 700, 1.25)
        XCTAssertEqual(batch.lines[0].bottles, 2)
        XCTAssertEqual(batch.lines[1].measurement, "52.5 dash")
        XCTAssertEqual(batch.lines[2].measurement, "105 drop")
        XCTAssertEqual(batch.totalVolumeML, 875)
    }
    func testVariableQuantityDoesNotBecomeZeroMillilitres() {
        var espresso = Ingredient(name: "Espresso", amount: 0, unit: .ml, batchBehaviour: .serviceOnly)
        espresso.quantityDisplay = "One freshly pulled espresso"
        let drink = Cocktail(id: "t", name: "Espresso", ingredients: [espresso])
        let batch = BatchCalculator.calculate(cocktail: drink, serves: 35)
        XCTAssertEqual(batch.lines[0].measurement, "One freshly pulled espresso per serve")
        XCTAssertEqual(batch.totalVolumeML, 0)
    }
}
