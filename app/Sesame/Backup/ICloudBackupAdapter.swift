#if ICLOUD_CAPABLE
    import Foundation
    import os

    final class ICloudBackupAdapter: BackupAdapter {
        let adapterKey = "icloud"

        static let backupFileName = "sesame-backup.sesame"
        static let containerIdentifier = Bundle.main.infoDictionary?["ICloudContainerID"] as! String

        private let documentsDirectory: URL?
        private let fileManager: FileManager

        private let logger = Logger(
            subsystem: Logger.appSubsystem,
            category: "ICloudBackupAdapter"
        )

        /// Production initializer — resolves the iCloud Drive ubiquity container.
        init(fileManager: FileManager = .default) {
            self.fileManager = fileManager
            let container = fileManager.url(
                forUbiquityContainerIdentifier: Self.containerIdentifier
            )
            documentsDirectory = container?.appending(path: "Documents")
        }

        /// Testing initializer — uses a local directory instead of iCloud.
        init(localDirectory: URL, fileManager: FileManager = .default) {
            self.fileManager = fileManager
            documentsDirectory = localDirectory
        }

        // MARK: - Availability

        static var isAvailable: Bool {
            if LaunchMode.isSimulator { return true }
            return FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) != nil
        }

        // MARK: - BackupAdapter

        func store(blob: Data) async throws {
            let fileURL = try backupFileURL()

            let dir = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: dir.path()) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            try blob.write(to: fileURL, options: .atomic)
            logger.info("Backup stored (\(blob.count) bytes)")
        }

        func retrieve() async throws -> Data {
            let fileURL = try backupFileURL()

            guard fileManager.fileExists(atPath: fileURL.path()) else {
                throw ICloudBackupError.noBackupFound
            }

            return try Data(contentsOf: fileURL)
        }

        func lastDestinationBackupDate() async throws -> Date? {
            guard let dir = documentsDirectory else { return nil }
            let fileURL = dir.appending(path: Self.backupFileName)

            guard fileManager.fileExists(atPath: fileURL.path()) else { return nil }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path())
            return attributes[.modificationDate] as? Date
        }

        func deleteBackup() async throws {
            let fileURL = try backupFileURL()
            guard fileManager.fileExists(atPath: fileURL.path()) else { return }
            try fileManager.removeItem(at: fileURL)
        }

        // MARK: - Private

        private func backupFileURL() throws -> URL {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }
            return dir.appending(path: Self.backupFileName)
        }
    }

    // MARK: - Errors

    enum ICloudBackupError: LocalizedError {
        case iCloudUnavailable
        case noBackupFound

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                "iCloud is not available. Sign in to iCloud in Settings."
            case .noBackupFound:
                "No backup found in iCloud."
            }
        }
    }
#endif
