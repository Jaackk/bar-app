import Foundation

public struct BARBackup: Codable, Sendable {
    public let format: String
    public let version: Int
    public let exportedAt: Date
    public let snapshot: AppSnapshot
}
public enum BackupService {
    public static let maximumBytes = 256 * 1024 * 1024
    public static func export(_ snapshot: AppSnapshot, at date: Date = Date()) throws -> Data {
        try SeedLoader.validate(snapshot: snapshot)
        let data = try SeedLoader.makeEncoder().encode(BARBackup(format: "BAR-backup", version: 1, exportedAt: date, snapshot: snapshot))
        guard data.count <= maximumBytes else { throw DataValidationError.invalid("This backup exceeds 256 MB. Contact support before removing records.") }
        return data
    }
    public static func read(_ data: Data) throws -> AppSnapshot {
        guard data.count <= maximumBytes else { throw DataValidationError.invalid("Choose a BAR backup under 256 MB.") }
        let backup = try SeedLoader.makeDecoder().decode(BARBackup.self, from: data)
        guard backup.format == "BAR-backup", backup.version == 1 else { throw DataValidationError.invalid("This backup format needs a newer version of BAR.") }
        try SeedLoader.validate(snapshot: backup.snapshot)
        let updated = try MenuMigration.apply(to: backup.snapshot)
        try SeedLoader.validate(snapshot: updated)
        return updated
    }
    public static func readFile(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw DataValidationError.invalid("Choose a BAR file under 256 MB.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw DataValidationError.invalid("This file is too large.") }
        return data
    }
}
