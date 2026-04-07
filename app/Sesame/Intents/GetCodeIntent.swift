import AppIntents
import SwiftData

struct GetCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Verification Code"
    static var description = IntentDescription("Gets a current TOTP verification code for an account.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Account")
    var account: AccountEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get code for \(\.$account)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard SiriIntentService.isEnabled else {
            return .result(
                value: "",
                dialog: "Open Sesame and enable Siri & Shortcuts in Settings to use this shortcut."
            )
        }

        let context = SharedModelContainer.shared.mainContext
        let accountId = account.id
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { $0.id == accountId && $0.deletedAt == nil }
        )

        guard let dbAccount = try context.fetch(descriptor).first else {
            return .result(
                value: "",
                dialog: "Account not found."
            )
        }

        let codeService = CodeService(keychain: KeychainService())
        codeService.refreshCodes(for: [dbAccount], at: .now)

        guard let code = codeService.code(for: dbAccount.id)?.code else {
            return .result(
                value: "",
                dialog: "Could not generate verification code."
            )
        }

        ClipboardService.copy(code)

        let issuer = dbAccount.effectiveIssuer
        return .result(
            value: code,
            dialog: "Your \(issuer) code is \(code). It's been copied to your clipboard."
        )
    }
}
