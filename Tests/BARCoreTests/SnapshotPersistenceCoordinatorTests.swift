import Foundation
import XCTest
@testable import BARCore

final class SnapshotPersistenceCoordinatorTests: XCTestCase {
    private func snapshot(_ name: String) -> AppSnapshot {
        AppSnapshot(preferences: UserPreferences(employeeName: name))
    }

    func testDelayedStockSnapshotCannotOverwriteANewerImmediateSave() throws {
        let initial = snapshot("Initial")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        var stockEdit = initial
        stockEdit.stockLists = [StockListItem(venueID: "v", kind: .order, name: "Gin", quantity: 2)]
        let delayedRevision = writer.reserveWrite()
        var profileEdit = stockEdit
        profileEdit.preferences.employeeName = "New name"
        XCTAssertTrue(try writer.save(profileEdit, revision: writer.reserveWrite()))

        XCTAssertFalse(try writer.save(stockEdit, revision: delayedRevision))
        XCTAssertEqual(try repository.load(), profileEdit)
        XCTAssertEqual(writer.lastConfirmedSnapshot, profileEdit)
        XCTAssertEqual(repository.writeCount, 1)
    }

    func testRapidEditsOnlyPersistTheLatestReservedSnapshot() throws {
        let initial = snapshot("Initial")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        let first = writer.reserveWrite()
        let second = writer.reserveWrite()
        let latest = writer.reserveWrite()

        XCTAssertFalse(try writer.save(snapshot("One tap"), revision: first))
        XCTAssertFalse(try writer.save(snapshot("Two taps"), revision: second))
        XCTAssertTrue(try writer.save(snapshot("Final quantity"), revision: latest))
        XCTAssertEqual(try repository.load().preferences.employeeName, "Final quantity")
        XCTAssertEqual(repository.writeCount, 1)
    }

    func testNewEditsDoNotWaitForDiskAndFinishAfterAnInFlightWrite() {
        let initial = snapshot("Initial")
        let older = snapshot("Older stock edit")
        let newer = snapshot("Newer profile edit")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        repository.pauseNextSave(started: started, release: release)
        defer { release.signal() }
        let oldDone = expectation(description: "Older disk write completes")
        let newReserved = expectation(description: "New edit reserves without waiting for disk")
        let newDone = expectation(description: "Newer disk write completes")
        let oldRevision = writer.reserveWrite()
        DispatchQueue.global().async {
            do { XCTAssertTrue(try writer.save(older, revision: oldRevision)) }
            catch { XCTFail("Unexpected save error: \(error)") }
            oldDone.fulfill()
        }
        XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
        DispatchQueue.global().async {
            let revision = writer.reserveWrite()
            newReserved.fulfill()
            do { XCTAssertTrue(try writer.save(newer, revision: revision)) }
            catch { XCTFail("Unexpected save error: \(error)") }
            newDone.fulfill()
        }
        wait(for: [newReserved], timeout: 2)
        release.signal()
        wait(for: [oldDone, newDone], timeout: 3)
        XCTAssertEqual(try repository.load(), newer)
        XCTAssertEqual(writer.lastConfirmedSnapshot, newer)
    }

    func testResetWaitsForAnInFlightSaveAndRejectsItsLateRetry() {
        let initial = snapshot("Fresh seed")
        let old = snapshot("Data to reset")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        repository.pauseNextSave(started: started, release: release)
        defer { release.signal() }
        let oldDone = expectation(description: "Old save finishes")
        let resetDone = expectation(description: "Reset finishes")
        let oldRevision = writer.reserveWrite()
        DispatchQueue.global().async {
            do { XCTAssertTrue(try writer.save(old, revision: oldRevision)) }
            catch { XCTFail("Unexpected save error: \(error)") }
            oldDone.fulfill()
        }
        XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
        DispatchQueue.global().async {
            do { XCTAssertEqual(try writer.reset(), initial) }
            catch { XCTFail("Unexpected reset error: \(error)") }
            resetDone.fulfill()
        }
        release.signal()
        wait(for: [oldDone, resetDone], timeout: 3)
        XCTAssertFalse(try writer.save(old, revision: oldRevision))
        XCTAssertEqual(try repository.load(), initial)
        XCTAssertEqual(writer.lastConfirmedSnapshot, initial)
    }

    func testFailedSaveRetainsTheLastConfirmedSnapshotForRollback() throws {
        let initial = snapshot("Initial")
        let confirmed = snapshot("Saved stock edit")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        try writer.save(confirmed, revision: writer.reserveWrite())
        repository.failNextSave()

        XCTAssertThrowsError(try writer.save(snapshot("Unsaved next edit"), revision: writer.reserveWrite()))
        XCTAssertEqual(writer.lastConfirmedSnapshot, confirmed)
        XCTAssertEqual(try repository.load(), confirmed)
        XCTAssertEqual(repository.writeCount, 1)
    }

    func testFailedResetStillInvalidatesPendingPreResetSnapshot() throws {
        let initial = snapshot("Existing state")
        let repository = ControlledRepository(initial)
        let writer = SnapshotPersistenceCoordinator(repository: repository, initialSnapshot: initial)
        let pending = writer.reserveWrite()
        repository.failNextReset()

        XCTAssertThrowsError(try writer.reset())
        XCTAssertFalse(try writer.save(snapshot("Old pending edit"), revision: pending))
        XCTAssertEqual(writer.lastConfirmedSnapshot, initial)
        XCTAssertEqual(try repository.load(), initial)
    }
}

private final class ControlledRepository: AppRepository, @unchecked Sendable {
    private enum Failure: Error { case expected, timedOut }
    private let lock = NSLock()
    private let seed: AppSnapshot
    private var state: AppSnapshot
    private var writes = 0
    private var failSave = false
    private var failReset = false
    private var gate: (started: DispatchSemaphore, release: DispatchSemaphore)?

    init(_ seed: AppSnapshot) { self.seed = seed; state = seed }
    var writeCount: Int { lock.lock(); defer { lock.unlock() }; return writes }
    func load() throws -> AppSnapshot { lock.lock(); defer { lock.unlock() }; return state }
    func failNextSave() { lock.lock(); failSave = true; lock.unlock() }
    func failNextReset() { lock.lock(); failReset = true; lock.unlock() }
    func pauseNextSave(started: DispatchSemaphore, release: DispatchSemaphore) {
        lock.lock(); gate = (started, release); lock.unlock()
    }
    func save(_ snapshot: AppSnapshot) throws {
        lock.lock()
        let currentGate = gate
        gate = nil
        let shouldFail = failSave
        failSave = false
        lock.unlock()
        if let currentGate {
            currentGate.started.signal()
            guard currentGate.release.wait(timeout: .now() + 5) == .success else { throw Failure.timedOut }
        }
        if shouldFail { throw Failure.expected }
        lock.lock(); state = snapshot; writes += 1; lock.unlock()
    }
    func reset() throws -> AppSnapshot {
        lock.lock(); defer { lock.unlock() }
        if failReset { failReset = false; throw Failure.expected }
        state = seed
        return seed
    }
}
