import Foundation
import os
import SwiftData

enum RestoreError: Error, LocalizedError {
    case passwordRequired
    case invalidData

    var errorDescription: String? {
        switch self {
        case .passwordRequired: "A password is required to decrypt this backup."
        case .invalidData: "The file does not contain valid backup data."
        }
    }
}

struct RestoreService {
    private let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "RestoreService"
    )

    /// Decrypt a `.sesame` backup blob and decode the payload.
    static func decryptPayload(data: Data, password: String?) async throws -> BackupPayload {
        guard let password else { throw RestoreError.passwordRequired }

        // Detached: Argon2id key derivation is CPU-intensive, must run off @MainActor
        let json = try await Task.detached {
            try BackupCrypto.decrypt(blob: data, password: password)
        }.value

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(BackupPayload.self, from: json)
        } catch {
            throw RestoreError.invalidData
        }
    }

    func restore(
        payload: BackupPayload,
        modelContext: ModelContext,
        keychain: KeychainServiceProtocol
    ) throws {
        // Delete all existing accounts + their keychain secrets
        let existingAccounts = try modelContext.fetch(FetchDescriptor<Account>())
        for account in existingAccounts {
            do {
                try keychain.delete(for: account.id)
            } catch {
                logger.error("Failed to delete keychain secret for account \(account.id): \(error)")
            }
            modelContext.delete(account)
        }

        // Delete all existing profiles
        let existingProfiles = try modelContext.fetch(FetchDescriptor<Profile>())
        for profile in existingProfiles {
            modelContext.delete(profile)
        }

        // Insert profiles from payload
        for backupProfile in payload.profiles {
            let profile = Profile(
                id: backupProfile.id,
                name: backupProfile.name,
                color: backupProfile.color,
                sortOrder: backupProfile.sortOrder
            )
            modelContext.insert(profile)
        }

        // Ensure default profile exists even if not in payload
        let hasDefault = payload.profiles.contains { $0.id == Profile.defaultID }
        if !hasDefault {
            modelContext.insert(Profile.makeDefault())
        }

        // Insert accounts from payload
        for backupAccount in payload.accounts {
            let account = Account(
                id: backupAccount.id,
                profileId: backupAccount.profileId,
                issuer: backupAccount.issuer,
                displayIssuer: backupAccount.displayIssuer,
                name: backupAccount.name,
                displayName: backupAccount.displayName,
                type: backupAccount.type,
                algorithm: backupAccount.algorithm,
                digits: backupAccount.digits,
                period: backupAccount.period,
                counter: backupAccount.counter,
                createdAt: backupAccount.createdAt,
                website: backupAccount.website
            )
            modelContext.insert(account)
            try keychain.save(secret: backupAccount.secret, for: account.id)
        }

        try modelContext.save()
    }
}
