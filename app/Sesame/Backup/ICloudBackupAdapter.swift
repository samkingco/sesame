#if ICLOUD_CAPABLE
    import Foundation
    import os
    import UIKit

    final class ICloudBackupAdapter: BackupAdapter {
        let adapterKey = "icloud"

        static let containerIdentifier = Bundle.main.infoDictionary?["ICloudContainerID"] as! String

        private let resolveFilename: @Sendable () -> String?
        private let documentsDirectory: URL?
        private let fileManager: FileManager

        private let logger = Logger(
            subsystem: Logger.appSubsystem,
            category: "ICloudBackupAdapter"
        )

        /// Production initializer — resolves the iCloud Drive ubiquity container.
        /// Reads the per-device backup filename from UserDefaults at each operation.
        init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
            self.fileManager = fileManager
            self.resolveFilename = {
                defaults.string(forKey: UserDefaultsKey.backupFilenamePrefix + "icloud")
            }
            let container = fileManager.url(
                forUbiquityContainerIdentifier: Self.containerIdentifier
            )
            #if DEMO_ENABLED
                if container == nil, LaunchMode.isDemoData {
                    documentsDirectory = fileManager.temporaryDirectory.appending(path: "icloud-demo/Documents")
                } else {
                    documentsDirectory = container?.appending(path: "Documents")
                }
            #else
                documentsDirectory = container?.appending(path: "Documents")
            #endif
        }

        /// Testing initializer — uses a local directory and explicit filename.
        init(localDirectory: URL, backupFilename: String? = nil, fileManager: FileManager = .default) {
            self.fileManager = fileManager
            self.resolveFilename = { backupFilename }
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

        func retrieve(id: String) async throws -> Data {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }
            let fileURL = dir.appending(path: id)

            guard fileManager.fileExists(atPath: fileURL.path()) else {
                throw ICloudBackupError.noBackupFound
            }

            return try Data(contentsOf: fileURL)
        }

        func lastDestinationBackupDate() async throws -> Date? {
            guard let dir = documentsDirectory, let filename = resolveFilename() else { return nil }
            let fileURL = dir.appending(path: filename)

            guard fileManager.fileExists(atPath: fileURL.path()) else { return nil }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path())
            return attributes[.modificationDate] as? Date
        }

        func deleteBackup() async throws {
            let fileURL = try backupFileURL()
            guard fileManager.fileExists(atPath: fileURL.path()) else { return }
            try fileManager.removeItem(at: fileURL)
        }

        // MARK: - Listing

        func listBackups() throws -> [BackupFile] {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }

            if !fileManager.fileExists(atPath: dir.path()) {
                return []
            }

            let contents = try fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            return contents.compactMap { url -> BackupFile? in
                guard url.pathExtension == "sesame" else { return nil }

                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))
                    .flatMap(\.contentModificationDate) ?? Date.distantPast

                let filename = url.lastPathComponent
                return BackupFile(
                    id: filename,
                    name: Self.displayName(for: filename),
                    modifiedAt: modDate
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
        }

        // MARK: - Private

        static func displayName(for filename: String) -> String {
            var name = filename
            if name.hasSuffix(".backup.sesame") {
                name = String(name.dropLast(".backup.sesame".count))
            } else if name.hasSuffix(".sesame") {
                name = String(name.dropLast(".sesame".count))
            }
            return name
        }

        private func backupFileURL() throws -> URL {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }
            guard let filename = resolveFilename() else {
                throw ICloudBackupError.noBackupFilename
            }
            return dir.appending(path: filename)
        }
    }

    // MARK: - Filename Generation

    extension ICloudBackupAdapter {
        static func generateBackupFilename() -> String {
            let deviceName = sanitizeDeviceName(UIDevice.current.name)
            let nanoID = generateNanoID(length: 8)
            return "\(deviceName)-\(nanoID).backup.sesame"
        }

        static func sanitizeDeviceName(_ name: String) -> String {
            let lowered = name.lowercased()
            let alphanumeric = lowered.map { $0.isLetter || $0.isNumber ? $0 : Character("-") }
            let collapsed = String(alphanumeric)
                .replacing(/\-{2,}/, with: "-")
            return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }

        private static func generateNanoID(length: Int) -> String {
            let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
            return String((0 ..< length).compactMap { _ in alphabet.randomElement() })
        }
    }

    // MARK: - Errors

    enum ICloudBackupError: LocalizedError {
        case iCloudUnavailable
        case noBackupFound
        case noBackupFilename

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                "iCloud is not available. Sign in to iCloud in Settings."
            case .noBackupFound:
                "No backup found in iCloud."
            case .noBackupFilename:
                "No backup filename configured."
            }
        }
    }
#endif
