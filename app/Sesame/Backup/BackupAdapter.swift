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

    /// Read an encrypted blob by its adapter-specific identifier.
    /// The ID comes from `BackupFile.id` returned by `listBackups()`.
    func retrieve(id: String) async throws -> Data

    /// Check if a backup exists and when it was last modified
    func lastDestinationBackupDate() async throws -> Date?

    /// Delete the backup from the destination
    func deleteBackup() async throws

    /// List all backup files at the destination
    func listBackups() throws -> [BackupFile]
}

struct BackupFile: Identifiable {
    /// Opaque identifier — meaning is adapter-specific (e.g. filename, server UUID).
    let id: String
    /// Human-readable name for display in the UI.
    let name: String
    let modifiedAt: Date
}
