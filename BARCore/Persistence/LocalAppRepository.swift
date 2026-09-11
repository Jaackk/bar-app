import Foundation

public protocol AppRepository {
    func load() throws -> AppSnapshot
    func save(_ snapshot: AppSnapshot) throws
    func reset() throws -> AppSnapshot
}

public enum PersistenceError: LocalizedError {
    case unreadableSavedData(URL, String)
    public var errorDescription: String? {
        switch self {
        case .unreadableSavedData(_, let detail):
            return "BAR could not read saved data. It has been preserved. Restore a backup or use Reset local data to start again. \(detail)"
        }
    }
}

/// The UI depends on AppRepository; disk encoding and paths stay inside this adapter.
/// An eventual cloud adapter should serve the same validated cache and sync separately.
public final class LocalAppRepository: AppRepository {
    public let directory: URL
    public var stateURL: URL { directory.appendingPathComponent("state.json") }
    private let seed: () throws -> AppSnapshot
    private let lock = NSRecursiveLock()

    public init(directory: URL? = nil, seed: @escaping () throws -> AppSnapshot = { try SeedLoader.load() }) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BAR", isDirectory: true)
        self.seed = seed
    }
    public func load() throws -> AppSnapshot {
        lock.lock(); defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let previous = try readExisting()
            let migrated = try MenuMigration.apply(to: previous)
            if migrated != previous { try write(migrated) }
            return migrated
        }
        let snapshot = try seed()
        try write(snapshot)
        return snapshot
    }
    public func save(_ snapshot: AppSnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        // A damaged existing file must never be silently replaced by an in-memory fallback.
        if FileManager.default.fileExists(atPath: stateURL.path) { _ = try readExisting() }
        try write(snapshot)
    }
    public func reset() throws -> AppSnapshot {
        lock.lock(); defer { lock.unlock() }
        let fresh = try seed()
        try SeedLoader.validate(snapshot: fresh)
        // Keep one recoverable pre-reset backup, including a corrupt original when present.
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let backup = directory.appendingPathComponent("state-before-reset.json")
            let original = try Data(contentsOf: stateURL)
            try original.write(to: backup, options: .atomic)
        }
        try write(fresh)
        return fresh
    }
    private func readExisting() throws -> AppSnapshot {
        do {
            let snapshot = try SeedLoader.makeDecoder().decode(AppSnapshot.self, from: Data(contentsOf: stateURL))
            try SeedLoader.validate(snapshot: snapshot)
            return snapshot
        } catch { throw PersistenceError.unreadableSavedData(stateURL, error.localizedDescription) }
    }
    private func write(_ snapshot: AppSnapshot) throws {
        try SeedLoader.validate(snapshot: snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try SeedLoader.makeEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: stateURL, options: .atomic)
        #endif
    }
}
