#if AUTOFILL_CAPABLE
    import AuthenticationServices
    import Foundation
    import os
    import SwiftData

    /// Sesame's AutoFill switch is the system one in Settings › General ›
    /// AutoFill & Passwords, so there's no separate in-app preference.
    enum AutoFillService {
        private static let logger = Logger(subsystem: Logger.appSubsystem, category: "AutoFillService")

        static var isEnabled: Bool {
            get async {
                await ASCredentialIdentityStore.shared.state().isEnabled
            }
        }

        /// Shows the system prompt to turn Sesame on. Returns whether it's on afterwards.
        static func requestEnable() async -> Bool {
            await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
        }

        static func openSettings() async {
            do {
                try await ASSettingsHelper.openCredentialProviderAppSettings()
            } catch {
                logger.error("Failed to open AutoFill settings: \(error)")
            }
        }

        @MainActor
        static func syncIdentityStore() async {
            let context = SharedModelContainer.shared.mainContext

            do {
                let accounts = try AccountService.fetchActive(modelContext: context)
                try await AutoFillIdentities.replace(with: accounts)
            } catch {
                logger.error("Failed to sync AutoFill identities: \(error)")
            }
        }
    }
#endif
