import Foundation
import os
import Security

protocol KeychainServiceProtocol {
    func save(secret: String, for accountId: UUID) throws
    func read(for accountId: UUID) throws -> String
    func delete(for accountId: UUID) throws
}

final class KeychainService: KeychainServiceProtocol {
    private static let logger = Logger(subsystem: Logger.appSubsystem, category: "KeychainService")
    private let service = KeychainIdentifier.secretsService

    func save(secret: String, for accountId: UUID) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId.uuidString,
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            Self.logger.error("Failed to delete existing keychain item before save (OSStatus \(deleteStatus))")
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func read(for accountId: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.readFailed(status)
        }

        return secret
    }

    func delete(for accountId: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "Failed to encode secret"
        case let .saveFailed(s): "Keychain save failed (OSStatus \(s))"
        case let .readFailed(s): "Keychain read failed (OSStatus \(s))"
        case let .deleteFailed(s): "Keychain delete failed (OSStatus \(s))"
        }
    }
}
