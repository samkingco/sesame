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

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let blob = Data("test-backup-payload".utf8)

            try await adapter.store(blob: blob)
            let retrieved = try await adapter.retrieve()

            #expect(retrieved == blob)
        }

        // MARK: - lastDestinationBackupDate

        @Test("lastDestinationBackupDate returns nil when no backup exists")
        func noBackupReturnsNil() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)
            let date = try await adapter.lastDestinationBackupDate()

            #expect(date == nil)
        }

        @Test("lastDestinationBackupDate returns a date after store")
        func dateAfterStore() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)
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
                _ = try await adapter.retrieve()
            }
        }

        // MARK: - Store overwrites

        @Test("store overwrites previous backup")
        func storeOverwrites() async throws {
            let dir = try makeTempDirectory()
            defer { cleanup(dir) }

            let adapter = ICloudBackupAdapter(localDirectory: dir)

            try await adapter.store(blob: Data("first".utf8))
            try await adapter.store(blob: Data("second".utf8))

            let retrieved = try await adapter.retrieve()
            #expect(retrieved == Data("second".utf8))
        }

        // MARK: - Creates directory

        @Test("store creates Documents directory if needed")
        func createsDirectory() async throws {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("ICloudBackupAdapterTests-\(UUID().uuidString)")
            defer { cleanup(dir) }

            // Don't pre-create — adapter should create it
            let adapter = ICloudBackupAdapter(localDirectory: dir)
            try await adapter.store(blob: Data("data".utf8))

            let retrieved = try await adapter.retrieve()
            #expect(retrieved == Data("data".utf8))
        }
    }

#endif
