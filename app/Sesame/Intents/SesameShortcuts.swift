import AppIntents

struct SesameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetCodeIntent(),
            phrases: [
                "Get code in \(.applicationName)",
                "Get \(\.$account) code in \(.applicationName)",
                "\(.applicationName) code for \(\.$account)",
                "Get auth code in \(.applicationName)",
                "Get \(\.$account) auth code in \(.applicationName)",
                "Get OTP code in \(.applicationName)",
                "Get \(\.$account) OTP code in \(.applicationName)",
                "What's my \(\.$account) code in \(.applicationName)",
                "What's my \(\.$account) auth code in \(.applicationName)",
                "Show my \(\.$account) code in \(.applicationName)",
            ],
            shortTitle: "Get Verification Code",
            systemImageName: "lock.shield"
        )
    }
}
