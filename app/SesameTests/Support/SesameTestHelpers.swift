import Foundation
@testable import Sesame

// MARK: - StubKeychain

/// In-memory keychain that stores and retrieves secrets by account ID.
///
/// - When `defaultSecret` is non-nil: returns it for any ID not in `storage` or `failingIds`.
/// - When `defaultSecret` is nil (strict mode): throws for any ID not in `storage`.
/// - IDs in `failingIds` always throw.
final class StubKeychain: KeychainServiceProtocol {
    var storage: [UUID: String] = [:]
    var failingIds: Set<UUID> = []

    private let defaultSecret: String?

    init(defaultSecret: String? = "JBSWY3DPEHPK3PXP") {
        self.defaultSecret = defaultSecret
    }

    init(secrets: [UUID: String], defaultSecret: String? = "JBSWY3DPEHPK3PXP") {
        storage = secrets
        self.defaultSecret = defaultSecret
    }

    func save(secret: String, for accountId: UUID) throws {
        storage[accountId] = secret
    }

    func read(for accountId: UUID) throws -> String {
        if failingIds.contains(accountId) {
            throw KeychainError.readFailed(-25300)
        }
        if let secret = storage[accountId] {
            return secret
        }
        if let defaultSecret {
            return defaultSecret
        }
        throw KeychainError.readFailed(-25300)
    }

    func delete(for accountId: UUID) throws {
        storage[accountId] = nil
    }
}

// MARK: - SpyKeychain

/// Keychain spy that tracks `save` and `delete` calls in addition to storing secrets.
final class SpyKeychain: KeychainServiceProtocol {
    var storage: [UUID: String] = [:]
    var savedIds: [UUID] = []
    var deletedIds: [UUID] = []

    private let defaultSecret: String

    init(defaultSecret: String = "JBSWY3DPEHPK3PXP") {
        self.defaultSecret = defaultSecret
    }

    func save(secret: String, for accountId: UUID) throws {
        storage[accountId] = secret
        savedIds.append(accountId)
    }

    func read(for accountId: UUID) throws -> String {
        if let secret = storage[accountId] {
            return secret
        }
        return defaultSecret
    }

    func delete(for accountId: UUID) throws {
        storage[accountId] = nil
        deletedIds.append(accountId)
    }
}
