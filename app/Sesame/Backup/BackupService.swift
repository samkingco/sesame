import Foundation
import os
import Security
import SwiftData

@MainActor
final class BackupService {
    let keychain: KeychainServiceProtocol
    let modelContext: ModelContext

    private let defaults: UserDefaults

    private static let keychainService = KeychainIdentifier.backupService
    private static let passwordAccountPrefix = KeychainIdentifier.backupPasswordAccountPrefix
    private static let lastBackupPrefix = UserDefaultsKey.lastBackupPrefix

    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "BackupService"
    )

    init(
        keychain: KeychainServiceProtocol,
        modelContext: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.modelContext = modelContext
        self.defaults = defaults
    }

    // MARK: - Backup & Retrieve

    func backup(using adapter: BackupAdapter, password: String) async throws {
        let payload = try BackupPayloadBuilder.build(context: modelContext, keychain: keychain)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(payload)

        // Argon2 key derivation is CPU-intensive; avoid blocking MainActor
        let blob = try await Task.detached {
            try BackupCrypto.encrypt(payload: jsonData, password: password)
        }.value
        try await adapter.store(blob: blob)

        defaults.set(Date.now, forKey: Self.lastBackupPrefix + adapter.adapterKey)
    }

    func retrieve(using adapter: BackupAdapter, password: String) async throws -> BackupPayload {
        let blob = try await adapter.retrieve()
        // Argon2 key derivation is CPU-intensive; avoid blocking MainActor
        let jsonData = try await Task.detached {
            try BackupCrypto.decrypt(blob: blob, password: password)
        }.value

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: jsonData)
    }

    func buildEncryptedBlob(password: String) async throws -> Data {
        let payload = try BackupPayloadBuilder.build(context: modelContext, keychain: keychain)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(payload)
        // Argon2 key derivation is CPU-intensive; avoid blocking MainActor
        return try await Task.detached {
            try BackupCrypto.encrypt(payload: jsonData, password: password)
        }.value
    }

    // MARK: - Last Backup Date

    func lastDeviceBackupDate(for adapterKey: String) -> Date? {
        defaults.object(forKey: Self.lastBackupPrefix + adapterKey) as? Date
    }

    // MARK: - Backup Password (per-adapter)

    private static func passwordAccountKey(for adapterKey: String) -> String {
        passwordAccountPrefix + adapterKey
    }

    func saveBackupPassword(_ password: String, for adapterKey: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.passwordAccountKey(for: adapterKey),
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func storedBackupPassword(for adapterKey: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.passwordAccountKey(for: adapterKey),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return password
    }

    func clearBackupPassword(for adapterKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.passwordAccountKey(for: adapterKey),
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
