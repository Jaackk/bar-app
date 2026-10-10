import XCTest
@testable import BARCore

final class ReleaseSafetyTests: XCTestCase {
    private func fixture() -> AppSnapshot {
        var value = AppSnapshot(venues: [Venue(id: "v", name: "Independent venue")],
            cocktails: [Cocktail(id: "c", name: "House", venueID: "v", ingredients: [Ingredient(id: "gin", name: "Gin", amount: 50)])],
            prep: [PrepItem(id: "prep", name: "Syrup", venueID: "v", currentAmount: 2, targetAmount: 3)],
            stock: [StockItem(id: "legacy-gin", name: "Gin", venueID: "v", currentStock: 2.75, parLevel: 8, unit: "bottle")],
            preferences: UserPreferences(venueID: "v"), user: User(venueID: "v"))
        value.products = [Product(id: "legacy-gin", venueID: "v", name: "Gin", unit: "bottle", defaultOrderUnit: "case", isActive: false)]
        value.products[0].imageData = Data([1, 2, 3])
        value.stockLists = [StockListItem(id: "list", venueID: "v", kind: .order, productID: "legacy-gin", name: "Gin", quantity: 3, unit: "case")]
        value.preferences.favouriteCocktailIDs = ["c"]
        value.preferences.classicDefault = .recommended
        value.preferences.classicOverrides["reference-sidecar"] = .custom
        value.training.record(correct: true, cocktailID: "c")
        var batch = SavedBatch(cocktailID: "c", name: "House", serves: 35, createdAt: Date(timeIntervalSince1970: 1700000000))
        batch.specification = value.cocktails[0]
        value.batches = [batch]
        return value
    }
    func testFullBackupRoundTripPreservesEveryOperationalField() throws {
        let value = fixture()
        XCTAssertEqual(try BackupService.read(BackupService.export(value)), value)
    }
    func testBackupRejectsMalformedFutureAndInvalidState() throws {
        XCTAssertThrowsError(try BackupService.read(Data("{}".utf8)))
        let value = fixture()
        let future = BARBackup(format: "BAR-backup", version: 99, exportedAt: Date(), snapshot: value)
        XCTAssertThrowsError(try BackupService.read(SeedLoader.makeEncoder().encode(future)))
        var invalid = value; invalid.stock[0].currentStock = -1
        XCTAssertThrowsError(try BackupService.export(invalid))
        let unsafe = BARBackup(format: "BAR-backup", version: 1, exportedAt: Date(), snapshot: invalid)
        XCTAssertThrowsError(try BackupService.read(SeedLoader.makeEncoder().encode(unsafe)))
    }
    func testRestoreCreatesUsableSafetyCopyAndInvalidRestoreDoesNotTouchDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = fixture()
        let repo = LocalAppRepository(directory: directory, seed: { original })
        _ = try repo.load()
        var next = original; next.stock[0].currentStock = 9
        try repo.restore(next)
        XCTAssertEqual(try repo.load(), next)
        XCTAssertEqual(try BackupService.read(XCTUnwrap(repo.safetyBackupData())), original)
        var invalid = original; invalid.schemaVersion = 100
        XCTAssertThrowsError(try repo.restore(invalid))
        XCTAssertEqual(try repo.load(), next)
        XCTAssertEqual(try BackupService.read(XCTUnwrap(repo.safetyBackupData())), original)
    }
    func testRestoreInvalidatesOldQueuedDebounce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = fixture()
        let repo = LocalAppRepository(directory: directory, seed: { original })
        let coordinator = SnapshotPersistenceCoordinator(repository: repo, initialSnapshot: try repo.load())
        let stale = coordinator.reserveWrite()
        var restored = original; restored.stock[0].currentStock = 12
        try coordinator.restore(restored)
        XCTAssertFalse(try coordinator.save(original, revision: stale))
        XCTAssertEqual(try repo.load(), restored)
    }
    func testContentUpdateQueuesUnknownLocalChangesWithoutMutatingUserWork() throws {
        let local = fixture()
        var incoming = local
        incoming.cocktails[0].ingredients[0].amount = 40
        incoming.products[0].name = "Corrected gin"; incoming.products[0].imageData = nil
        incoming.products[0].isActive = true
        incoming.stock[0].currentStock = 999
        incoming.preferences.employeeName = "Must not import"
        let merged = try ContentUpdateService.merge(incoming, into: local)
        XCTAssertEqual(merged.cocktails, local.cocktails)
        XCTAssertEqual(merged.products, local.products)
        XCTAssertEqual(merged.stock, local.stock)
        XCTAssertEqual(merged.stockLists, local.stockLists)
        XCTAssertEqual(merged.preferences, local.preferences)
        XCTAssertEqual(merged.training, local.training)
        XCTAssertEqual(merged.batches, local.batches)
        XCTAssertEqual(merged.contentConflicts.count, 2)
    }
    func testKnownUneditedContentCanUpdateWhileNewRecordsAreAdded() throws {
        let local = fixture()
        let tracked = try ContentUpdateService.merge(local, into: local)
        var incoming = local
        incoming.cocktails[0].garnish = "Lemon"
        incoming.products.append(Product(id: "new", venueID: "v", name: "New product"))
        let updated = try ContentUpdateService.merge(incoming, into: tracked)
        XCTAssertEqual(updated.cocktails[0].garnish, "Lemon")
        XCTAssertTrue(updated.contentConflicts.isEmpty)
        XCTAssertEqual(updated.products.count, 2)
        XCTAssertEqual(updated.stock, local.stock)
    }
    func testAcceptProductRevisionPreservesLatestUserPhotoInactiveStateAndUnits() throws {
        let local = fixture()
        var incoming = local; incoming.products[0].name = "New label"; incoming.products[0].unit = "case"
        var queued = try ContentUpdateService.merge(incoming, into: local)
        queued.products[0].imageData = Data([8, 9])
        let resolved = try ContentUpdateService.resolve(XCTUnwrap(queued.contentConflicts.first), acceptIncoming: true, in: queued)
        XCTAssertEqual(resolved.products[0].name, "New label")
        XCTAssertEqual(resolved.products[0].imageData, Data([8, 9]))
        XCTAssertFalse(resolved.products[0].isActive)
        XCTAssertEqual(resolved.stock, local.stock)
        XCTAssertEqual(resolved.stockLists, local.stockLists)
    }
    func testDecliningUpdateKeepsHouseRecipeAndDoesNotDeleteHistory() throws {
        let local = fixture()
        var incoming = local; incoming.cocktails[0].method = "New method"
        let queued = try ContentUpdateService.merge(incoming, into: local)
        let resolved = try ContentUpdateService.resolve(XCTUnwrap(queued.contentConflicts.first), acceptIncoming: false, in: queued)
        XCTAssertEqual(resolved.cocktails, local.cocktails)
        XCTAssertTrue(resolved.contentConflicts.isEmpty)
        XCTAssertEqual(resolved.training, local.training)
    }
    func testRemovedPackEntriesDoNotRemoveInactiveOrLocalRecords() throws {
        let local = fixture()
        let merged = try ContentUpdateService.merge(AppSnapshot(), into: local)
        XCTAssertEqual(merged, local)
    }
    func testPrepNewDayDoesNotResetPreparedAmountOrInventory() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        var item = PrepItem(id: "p", name: "Prep", currentAmount: 5, targetAmount: 3)
        item.markComplete(at: date)
        XCTAssertTrue(item.isComplete(on: date))
        XCTAssertFalse(item.isComplete(on: date.addingTimeInterval(86_400)))
        XCTAssertEqual(item.currentAmount, 5)
        XCTAssertEqual(item.lastPreparedDate, date)
    }
    func testOldCompletionWithoutPreparedDateIsNotTodaysCompletion() throws {
        let item = try SeedLoader.makeDecoder().decode(PrepItem.self, from: Data(#"{"id":"p","name":"Prep","completed":true,"currentAmount":4}"#.utf8))
        XCTAssertFalse(item.isComplete())
        XCTAssertEqual(item.currentAmount, 4)
    }
    func testUncountedStockIsNotZeroStockOrAnOrderSuggestion() {
        var item = StockItem(id: "gin", name: "Gin", currentStock: 0, parLevel: 6)
        item.hasRecordedCount = false
        XCTAssertEqual(item.requiredStock, 0)
        XCTAssertTrue(StockCalculator.order(items: [item]).isEmpty)
        item.hasRecordedCount = true
        XCTAssertEqual(item.requiredStock, 6)
    }
    func testLegacyCountsRemainRecorded() throws {
        let item = try SeedLoader.makeDecoder().decode(StockItem.self, from: Data(#"{"id":"gin","name":"Gin","currentStock":2.5,"parLevel":6}"#.utf8))
        XCTAssertTrue(item.hasRecordedCount)
        XCTAssertEqual(item.requiredStock, 3.5)
    }
    func testExportsKeepCaseBottleAndCustomUnits() {
        let entries = [StockListItem(venueID: "v", kind: .order, name: "Beer", quantity: 3, unit: "case"), StockListItem(venueID: "v", kind: .order, name: "Gin", quantity: 2, unit: "bottle"), StockListItem(venueID: "v", kind: .order, name: "Cloths", quantity: 1, unit: "pack")]
        let output = StockListService.text(entries, kind: .order, venueID: "v")
        XCTAssertTrue(output.contains("Beer × 3 case")); XCTAssertTrue(output.contains("Gin × 2 bottle")); XCTAssertTrue(output.contains("Cloths × 1 pack"))
        XCTAssertTrue(output.contains("not submitted to a supplier"))
    }
    func testFreshInstallHasNoInventedOperationalCountsOrPrep() throws {
        let value = try SeedLoader.load()
        XCTAssertTrue(value.stock.isEmpty); XCTAssertTrue(value.prep.isEmpty)
        XCTAssertTrue(value.stockLists.isEmpty); XCTAssertTrue(value.batches.isEmpty)
        XCTAssertEqual(value.training.answered, 0)
    }
    func testRealisticOldInstallationUpgradePreservesBothUnitsAndEveryUserDomain() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/used-installation-v15.json")
        let old = try SeedLoader.makeDecoder().decode(AppSnapshot.self, from: Data(contentsOf: file))
        try SeedLoader.validate(snapshot: old)
        let migrated = try MenuMigration.apply(to: old)
        try SeedLoader.validate(snapshot: migrated)
        XCTAssertEqual(migrated.stock, old.stock)
        XCTAssertEqual(migrated.stockLists, old.stockLists)
        XCTAssertEqual(migrated.preferences, old.preferences)
        XCTAssertEqual(migrated.prep, old.prep)
        XCTAssertEqual(migrated.training, old.training)
        XCTAssertEqual(migrated.batches, old.batches)
        XCTAssertEqual(migrated.user, old.user)
        XCTAssertEqual(migrated.products.first { $0.id == "spec-jameson" }, old.products[0])
        XCTAssertTrue(migrated.products.contains { $0.id == "spec-blend-coffee" })
        XCTAssertEqual(migrated.catalogueVersion, MenuMigration.version)
        XCTAssertEqual(try MenuMigration.apply(to: migrated), migrated)
    }
}
