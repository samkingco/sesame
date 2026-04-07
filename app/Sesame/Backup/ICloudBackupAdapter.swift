#if ICLOUD_CAPABLE
    import Foundation
    import os
    import UIKit

    final class ICloudBackupAdapter: BackupAdapter {
        let adapterKey = "icloud"

        private let resolveFilename: @Sendable () -> String?
        private let documentsDirectory: URL?
        private let fileManager: FileManager

        private let logger = Logger(
            subsystem: Logger.appSubsystem,
            category: "ICloudBackupAdapter"
        )

        /// Production initializer — takes a pre-resolved iCloud container URL.
        /// Call `resolveContainerURL()` off the main thread first, then pass the result here.
        init(containerURL: URL, fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
            self.fileManager = fileManager
            resolveFilename = {
                defaults.string(forKey: UserDefaultsKey.backupFilenamePrefix + "icloud")
            }
            documentsDirectory = containerURL.appending(path: "Documents")
        }

        /// Testing initializer — uses a local directory and explicit filename.
        init(localDirectory: URL, backupFilename: String? = nil, fileManager: FileManager = .default) {
            self.fileManager = fileManager
            resolveFilename = { backupFilename }
            documentsDirectory = localDirectory
        }

        private static let containerIdentifier = Bundle.main.infoDictionary?["ICloudContainerID"] as! String

        /// Resolves the iCloud container URL. Nonisolated async so it runs off
        /// the main actor when awaited from a @MainActor context.
        static func resolveContainerURL() async -> URL? {
            FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)
        }

        // MARK: - BackupAdapter

        func store(blob: Data) async throws {
            let fileURL = try backupFileURL()

            let dir = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            var coordinatorError: NSError?
            var writeError: Error?
            NSFileCoordinator()
                .coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { writingURL in
                    do {
                        try blob.write(to: writingURL)
                    } catch {
                        writeError = error
                    }
                }
            if let error = coordinatorError ?? writeError {
                throw error
            }
            logger.info("Backup stored (\(blob.count) bytes)")
        }

        func retrieve(id: String) async throws -> Data {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }
            let fileURL = dir.appending(path: id)

            var coordinatorError: NSError?
            var result: Result<Data, Error>?
            NSFileCoordinator()
                .coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { readingURL in
                    do {
                        result = try .success(Data(contentsOf: readingURL))
                    } catch {
                        result = .failure(error)
                    }
                }
            if let error = coordinatorError {
                throw error
            }
            guard let result else { throw ICloudBackupError.iCloudUnavailable }
            do {
                return try result.get()
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                throw ICloudBackupError.noBackupFound
            }
        }

        func lastDestinationBackupDate() async throws -> Date? {
            guard let dir = documentsDirectory, let filename = resolveFilename() else { return nil }
            let fileURL = dir.appending(path: filename)

            guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            return attributes[.modificationDate] as? Date
        }

        func deleteBackup() async throws {
            let fileURL = try backupFileURL()

            var coordinatorError: NSError?
            var deleteError: Error?
            NSFileCoordinator()
                .coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { writingURL in
                    do {
                        guard fileManager.fileExists(atPath: writingURL.path) else { return }
                        try fileManager.removeItem(at: writingURL)
                    } catch {
                        deleteError = error
                    }
                }
            if let error = coordinatorError ?? deleteError {
                throw error
            }
        }

        // MARK: - Listing

        func listBackups() throws -> [BackupFile] {
            guard let dir = documentsDirectory else {
                throw ICloudBackupError.iCloudUnavailable
            }

            var coordinatorError: NSError?
            var result: Result<[BackupFile], Error>?
            NSFileCoordinator().coordinate(readingItemAt: dir, options: [], error: &coordinatorError) { readingURL in
                do {
                    guard fileManager.fileExists(atPath: readingURL.path) else {
                        result = .success([])
                        return
                    }

                    let contents = try fileManager.contentsOfDirectory(
                        at: readingURL,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: .skipsHiddenFiles
                    )

                    let files = contents.compactMap { url -> BackupFile? in
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

                    result = .success(files)
                } catch {
                    result = .failure(error)
                }
            }
            if let error = coordinatorError {
                throw error
            }
            guard let result else { throw ICloudBackupError.iCloudUnavailable }
            return try result.get()
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
