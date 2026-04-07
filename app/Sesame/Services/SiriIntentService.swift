import CoreSpotlight
import Foundation
import os
import SwiftData

enum SiriIntentService {
    private static let logger = Logger(subsystem: Logger.appSubsystem, category: "SiriIntentService")
    static let enabledKey = UserDefaultsKey.siriIntentsEnabled

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func updateSpotlightIndex() async {
        if isEnabled {
            await indexAllAccounts()
        } else {
            await removeAllFromIndex()
        }
    }

    @MainActor
    static func indexAllAccounts() async {
        let context = SharedModelContainer.shared.mainContext

        let accounts: [Account]
        do {
            accounts = try AccountService.fetchActive(modelContext: context)
        } catch {
            logger.error("Failed to fetch accounts for Spotlight indexing: \(error)")
            return
        }

        let items = accounts.map { account in
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = account.effectiveIssuer
            attrs.contentDescription = account.effectiveName
            return CSSearchableItem(
                uniqueIdentifier: account.id.uuidString,
                domainIdentifier: "\(Bundle.main.bundleIdentifier!).accounts",
                attributeSet: attrs
            )
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            logger.error("Failed to index searchable items: \(error)")
        }
    }

    static func removeAllFromIndex() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(
                withDomainIdentifiers: ["\(Bundle.main.bundleIdentifier!).accounts"]
            )
        } catch {
            logger.error("Failed to remove searchable items: \(error)")
        }
    }
}
