import Foundation

/// Serialises repository writes while allowing the UI to invalidate a queued
/// snapshot without waiting for disk I/O. The owner reserves revisions in UI
/// mutation order; background workers may only write their reserved revision.
/// Repository access and confirmed state are protected by the locks below.
public final class SnapshotPersistenceCoordinator: @unchecked Sendable {
    private let repository: any AppRepository
    private let writeLock = NSLock()
    private let stateLock = NSLock()
    private var revision: UInt64 = 0
    private var confirmedSnapshot: AppSnapshot

    public init(repository: any AppRepository, initialSnapshot: AppSnapshot) {
        self.repository = repository
        confirmedSnapshot = initialSnapshot
    }

    public var lastConfirmedSnapshot: AppSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        return confirmedSnapshot
    }

    /// This lock never covers repository I/O, so rapid edits remain responsive
    /// even if a previous background write has already begun.
    @discardableResult public func reserveWrite() -> UInt64 {
        stateLock.lock(); defer { stateLock.unlock() }
        revision &+= 1
        return revision
    }

    public func isCurrent(_ candidate: UInt64) -> Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return candidate == revision
    }

    /// Returns false when a later edit/reset has superseded this snapshot.
    /// An already-running write finishes before any newer write or reset.
    @discardableResult public func save(_ snapshot: AppSnapshot, revision: UInt64) throws -> Bool {
        writeLock.lock(); defer { writeLock.unlock() }
        guard isCurrent(revision) else { return false }
        try repository.save(snapshot)
        stateLock.lock()
        confirmedSnapshot = snapshot
        stateLock.unlock()
        return true
    }

    /// The UI owner calls this synchronously, preventing a new edit until reset
    /// completes. Invalidate first so older queued workers cannot restore data.
    public func reset() throws -> AppSnapshot {
        reserveWrite()
        writeLock.lock(); defer { writeLock.unlock() }
        let fresh = try repository.reset()
        stateLock.lock()
        confirmedSnapshot = fresh
        stateLock.unlock()
        return fresh
    }
}
