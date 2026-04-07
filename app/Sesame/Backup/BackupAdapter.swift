import Foundation

/// Abstraction for backup storage destinations.
///
/// Current: ICloudBackupAdapter (iCloud Drive)
/// Planned: HTTP adapter for user-hosted backup infrastructure (S3, R2, etc.)
///          Users will self-host — no data sent to our servers.
protocol BackupAdapter: Sendable {
    /// Identifier used for per-adapter UserDefaults keys (e.g. "icloud", "file")
    var adapterKey: String { get }

    /// Write an encrypted blob to the destination
    func store(blob: Data) async throws

    /// Read the encrypted blob from the destination
    func retrieve() async throws -> Data

    /// Check if a backup exists and when it was last modified
    func lastDestinationBackupDate() async throws -> Date?

    /// Delete the backup from the destination
    func deleteBackup() async throws
}
