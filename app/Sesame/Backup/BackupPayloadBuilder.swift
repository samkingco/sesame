import Foundation
import os
import SwiftData

enum BackupPayloadBuilder {
    private static let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "BackupPayloadBuilder"
    )

    static func build(
        context: ModelContext,
        keychain: KeychainServiceProtocol
    ) throws -> BackupPayload {
        let activePredicate = #Predicate<Account> { $0.deletedAt == nil }
        let accounts = try context.fetch(FetchDescriptor<Account>(predicate: activePredicate))
        let profiles = try context.fetch(FetchDescriptor<Profile>())

        let backupAccounts: [BackupAccount] = accounts.compactMap { account in
            do {
                let secret = try keychain.read(for: account.id)
                return BackupAccount(
                    id: account.id,
                    profileId: account.profileId,
                    issuer: account.issuer,
                    displayIssuer: account.displayIssuer,
                    name: account.name,
                    displayName: account.displayName,
                    type: account.type,
                    algorithm: account.algorithm,
                    digits: account.digits,
                    period: account.period,
                    counter: account.counter,
                    createdAt: account.createdAt,
                    secret: secret,
                    website: account.website
                )
            } catch {
                logger.warning("Skipping account \(account.id): \(error.localizedDescription)")
                return nil
            }
        }

        let backupProfiles = profiles.map { profile in
            BackupProfile(
                id: profile.id,
                name: profile.name,
                color: profile.color,
                sortOrder: profile.sortOrder
            )
        }

        return BackupPayload(
            payloadVersion: 1,
            createdAt: .now,
            profiles: backupProfiles,
            accounts: backupAccounts
        )
    }
}
