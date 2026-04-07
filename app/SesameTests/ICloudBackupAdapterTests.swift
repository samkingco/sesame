#if ICLOUD_CAPABLE
    import Foundation
    @testable import Sesame
    import SwiftData
    import Testing

    struct ICloudBackupAdapterTests {
        private func makeTempDirectory() throws -> URL {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ICloudBackupAdapterTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        private func cleanup(_ dir: URL) {
            try? FileManager.default.removeItem(at: dir)
        }

        // MARK: - Round-trip

        @Test("store and retrieve round-trips a blob")
        func roundTrip() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let filename = "test-device-abc12345.backup.sesame"
            let adapter = ICloudBackupAdapter(
                localDirectory: dir,
                backupFilename: filename
            )
            let blob = Data("test-backup-payload".utf8)

            try await adapter.store(blob: blob)
            let retrieved = try await adapter.retrieve(id: filename)

            #expect(retrieved == blob)
        }

        // MARK: - lastDestinationBackupDate

        @Test("lastDestinationBackupDate returns nil when no backup exists")
        func noBackupReturnsNil() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(
                localDirectory: dir,
                backupFilename: "test-device-abc12345.backup.sesame"
            )
            let date = try await adapter.lastDestinationBackupDate()

            #expect(date == nil)
        }

        @Test("lastDestinationBackupDate returns a date after store")
        func dateAfterStore() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(
                localDirectory: dir,
                backupFilename: "test-device-abc12345.backup.sesame"
            )
            let before = Date.now

            try await adapter.store(blob: Data("data".utf8))

            let date = try await adapter.lastDestinationBackupDate()
            #expect(date != nil)
            #expect(try #require(date) >= before)
        }

        // MARK: - Retrieve without backup

        @Test("retrieve throws when no backup exists")
        func retrieveThrowsWhenEmpty() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)

            await #expect(throws: ICloudBackupError.self) {
                _ = try await adapter.retrieve(id: "nonexistent.backup.sesame")
            }
        }

        // MARK: - Store overwrites

        @Test("store overwrites previous backup")
        func storeOverwrites() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let filename = "test-device-abc12345.backup.sesame"
            let adapter = ICloudBackupAdapter(
                localDirectory: dir,
                backupFilename: filename
            )

            try await adapter.store(blob: Data("first".utf8))
            try await adapter.store(blob: Data("second".utf8))

            let retrieved = try await adapter.retrieve(id: filename)
            #expect(retrieved == Data("second".utf8))
        }

        // MARK: - Creates directory

        @Test("store creates Documents directory if needed")
        func createsDirectory() async throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ICloudBackupAdapterTests-\(UUID().uuidString)")
            defer { cleanup(dir) }

            // Don't pre-create — adapter should create it
            let adapter = ICloudBackupAdapter(
                localDirectory: dir,
                backupFilename: "test-device-abc12345.backup.sesame"
            )
            let filename = "test-device-abc12345.backup.sesame"
            try await adapter.store(blob: Data("data".utf8))

            let retrieved = try await adapter.retrieve(id: filename)
            #expect(retrieved == Data("data".utf8))
        }

        // MARK: - Store without filename

        @Test("store throws when no backup filename is set")
        func storeThrowsWithoutFilename() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)

            await #expect(throws: ICloudBackupError.self) {
                try await adapter.store(blob: Data("data".utf8))
            }
        }

        // MARK: - listBackups

        @Test("listBackups returns empty array when no files exist")
        func listBackupsEmpty() throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let backups = try adapter.listBackups()

            #expect(backups.isEmpty)
        }

        @Test("listBackups returns empty array when directory doesn't exist")
        func listBackupsNoDirectory() throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("nonexistent-\(UUID().uuidString)")

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let backups = try adapter.listBackups()

            #expect(backups.isEmpty)
        }

        @Test("listBackups returns all .sesame files with correct filenames and dates")
        func listBackupsMultipleFiles() throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let files = [
                "sams-iphone-k7x2m9ab.backup.sesame",
                "sams-ipad-x1y2z3w4.backup.sesame",
                "sesame-backup.sesame",
            ]
            for file in files {
                try Data("data".utf8).write(to: dir.appending(path: file))
            }

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let backups = try adapter.listBackups()

            #expect(backups.count == 3)
            let ids = Set(backups.map(\.id))
            #expect(ids == Set(files))
            #expect(backups.allSatisfy { $0.modifiedAt != Date.distantPast })
        }

        @Test("listBackups ignores non-.sesame files")
        func listBackupsIgnoresOtherFiles() throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            try Data("data".utf8).write(to: dir.appending(path: "device-abc12345.backup.sesame"))
            try Data("data".utf8).write(to: dir.appending(path: "notes.txt"))
            try Data("data".utf8).write(to: dir.appending(path: "photo.jpg"))

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let backups = try adapter.listBackups()

            #expect(backups.count == 1)
            #expect(backups[0].id == "device-abc12345.backup.sesame")
        }

        @Test("listBackups sorts by modification date, newest first")
        func listBackupsSortOrder() throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let oldFile = dir.appending(path: "old-device-aaaaaaaa.backup.sesame")
            try Data("old".utf8).write(to: oldFile)
            // Set modification date to the past
            try FileManager.default.setAttributes(
                [.modificationDate: Date.distantPast],
                ofItemAtPath: oldFile.path()
            )

            let newFile = dir.appending(path: "new-device-bbbbbbbb.backup.sesame")
            try Data("new".utf8).write(to: newFile)

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let backups = try adapter.listBackups()

            #expect(backups.count == 2)
            #expect(backups[0].id == "new-device-bbbbbbbb.backup.sesame")
            #expect(backups[1].id == "old-device-aaaaaaaa.backup.sesame")
        }

        // MARK: - Device-specific filename

        @Test("store writes to the device-specific filename")
        func storeWritesToDeviceFile() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let filename = "sams-iphone-k7x2m9ab.backup.sesame"
            let adapter = ICloudBackupAdapter(localDirectory: dir, backupFilename: filename)

            try await adapter.store(blob: Data("payload".utf8))

            let exists = FileManager.default.fileExists(
                atPath: dir.appending(path: filename).path()
            )
            #expect(exists)
        }

        @Test("retrieve reads from the device-specific filename")
        func retrieveReadsDeviceFile() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let filename = "sams-iphone-k7x2m9ab.backup.sesame"
            try Data("manual-write".utf8).write(to: dir.appending(path: filename))

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let data = try await adapter.retrieve(id: filename)

            #expect(data == Data("manual-write".utf8))
        }

        // MARK: - Filename generation

        @Test("generateBackupFilename produces {sanitized-name}-{8-char-id}.backup.sesame")
        func filenameFormat() throws {
            let filename = ICloudBackupAdapter.generateBackupFilename()
            #expect(filename.hasSuffix(".backup.sesame"))

            let withoutSuffix = String(filename.dropLast(".backup.sesame".count))
            let parts = withoutSuffix.split(separator: "-")
            // At least 2 parts: device name + nano ID
            #expect(parts.count >= 2)
            // Last part is the 8-char nano ID
            let nanoID = try String(#require(parts.last))
            #expect(nanoID.count == 8)
            #expect(nanoID.allSatisfy { $0.isLowercase || $0.isNumber })
        }

        // MARK: - Device name sanitization

        @Test("sanitizeDeviceName lowercases and replaces spaces with dashes")
        func sanitizeSpaces() {
            #expect(ICloudBackupAdapter.sanitizeDeviceName("Sam's iPhone") == "sam-s-iphone")
        }

        @Test("sanitizeDeviceName removes special characters")
        func sanitizeSpecialChars() {
            #expect(ICloudBackupAdapter.sanitizeDeviceName("My (Cool) Phone!") == "my-cool-phone")
        }

        @Test("sanitizeDeviceName collapses multiple dashes")
        func sanitizeDoubleDashes() {
            #expect(ICloudBackupAdapter.sanitizeDeviceName("A  --  B") == "a-b")
        }

        @Test("sanitizeDeviceName trims leading and trailing dashes")
        func sanitizeTrimDashes() {
            #expect(ICloudBackupAdapter.sanitizeDeviceName("--hello--") == "hello")
        }

        // MARK: - Display name

        @Test("displayName strips .backup.sesame suffix")
        func displayNameBackupSesame() {
            #expect(ICloudBackupAdapter
                .displayName(for: "sams-iphone-k7x2m9ab.backup.sesame") == "sams-iphone-k7x2m9ab")
        }

        @Test("displayName strips .sesame suffix for legacy files")
        func displayNameLegacySesame() {
            #expect(ICloudBackupAdapter.displayName(for: "sesame-backup.sesame") == "sesame-backup")
        }

        // MARK: - Export filename

        @Test("export filename uses {date}.backup.sesame format")
        func exportFilename() throws {
            let blob = Data("test".utf8)
            let url = try ExportBackupView.writeTempFile(blob: blob)
            defer { try? FileManager.default.removeItem(at: url) }

            let filename = url.lastPathComponent
            #expect(filename.hasSuffix(".backup.sesame"))
            // Should be YYYY-MM-DD.backup.sesame
            let datePart = String(filename.dropLast(".backup.sesame".count))
            #expect(datePart.count == 10)
            #expect(datePart.contains("-"))
        }
    }

#endif
