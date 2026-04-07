import Foundation
@testable import Sesame
import Testing

struct KeychainServiceTests {
    let keychain = KeychainService()

    @Test func saveAndRead() throws {
        let id = Foundation.UUID()
        let secret = "JBSWY3DPEHPK3PXP"

        try keychain.save(secret: secret, for: id)
        let read = try keychain.read(for: id)
        #expect(read == secret)

        // Cleanup
        try keychain.delete(for: id)
    }

    @Test func overwriteExisting() throws {
        let id = Foundation.UUID()

        try keychain.save(secret: "FIRST", for: id)
        try keychain.save(secret: "SECOND", for: id)
        let read = try keychain.read(for: id)
        #expect(read == "SECOND")

        try keychain.delete(for: id)
    }

    @Test func deleteExisting() throws {
        let id = Foundation.UUID()

        try keychain.save(secret: "JBSWY3DPEHPK3PXP", for: id)
        try keychain.delete(for: id)

        #expect(throws: KeychainError.self) {
            try keychain.read(for: id)
        }
    }

    @Test func deleteNonExistent() throws {
        // Should not throw for missing items
        try keychain.delete(for: Foundation.UUID())
    }

    @Test func readNonExistent() {
        #expect(throws: KeychainError.self) {
            try keychain.read(for: Foundation.UUID())
        }
    }
}
