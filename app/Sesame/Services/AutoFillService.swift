#if AUTOFILL_CAPABLE
    import AuthenticationServices
    import Foundation
    import os
    import SwiftData

    enum AutoFillService {
        private static let logger = Logger(subsystem: Logger.appSubsystem, category: "AutoFillService")
        static let enabledKey = UserDefaultsKey.autoFillEnabled

        static var isEnabled: Bool {
            UserDefaults.standard.bool(forKey: enabledKey)
        }

        @MainActor
        static func syncIdentityStore() async {
            let store = ASCredentialIdentityStore.shared
            let state = await store.state()

            guard state.isEnabled else { return }

            let context = SharedModelContainer.shared.mainContext

            let accounts: [Account]
            do {
                accounts = try AccountService.fetchActive(modelContext: context)
            } catch {
                logger.error("Failed to fetch accounts for AutoFill sync: \(error)")
                return
            }

            let identities: [ASCredentialIdentity] = accounts.compactMap { account in
                guard let website = account.website else { return nil }
                let serviceId = ASCredentialServiceIdentifier(
                    identifier: website,
                    type: .domain
                )
                return ASOneTimeCodeCredentialIdentity(
                    serviceIdentifier: serviceId,
                    label: "\(account.effectiveIssuer) (\(account.effectiveName))",
                    recordIdentifier: account.id.uuidString
                )
            }

            do {
                try await store.replaceCredentialIdentities(identities)
            } catch {
                logger.error("Failed to replace credential identities: \(error)")
            }
        }

        static func clearIdentityStore() async {
            do {
                try await ASCredentialIdentityStore.shared.removeAllCredentialIdentities()
            } catch {
                logger.error("Failed to clear credential identity store: \(error)")
            }
        }
    }
#endif
