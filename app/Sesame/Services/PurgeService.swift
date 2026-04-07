import Foundation
import os
import SwiftData

enum PurgeService {
    static let gracePeriod: TimeInterval = 48 * 60 * 60 // 48 hours

    private static let logger = Logger(
        subsystem: Logger.appSubsystem,
        category: "PurgeService"
    )

    @MainActor
    static func purgeExpired(
        context: ModelContext,
        keychain: KeychainServiceProtocol
    ) {
        let cutoff = Date.now.addingTimeInterval(-gracePeriod)
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                if let deletedAt = $0.deletedAt {
                    deletedAt < cutoff
                } else {
                    false
                }
            }
        )

        let expired: [Account]
        do {
            expired = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch expired accounts: \(error)")
            return
        }

        for account in expired {
            do {
                try keychain.delete(for: account.id)
            } catch {
                logger.error("Failed to delete keychain secret for account \(account.id): \(error)")
                continue
            }
            context.delete(account)
        }
    }
}
