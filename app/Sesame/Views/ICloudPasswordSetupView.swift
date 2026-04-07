#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudPasswordSetupView: View {
        let adapter: BackupAdapter
        var onComplete: () -> Void

        @Environment(BackupStore.self) private var backupStore
        @Environment(\.profileTint) private var profileTint

        @State private var password = ""
        @State private var confirmPassword = ""
        @State private var showValidation = false
        @State private var saveError: String?

        var body: some View {
            Form {
                PasswordEntryFields(
                    password: $password,
                    confirmation: $confirmPassword,
                    showValidation: showValidation,
                    emptyMessage: "Enter a backup password.",
                    error: saveError,
                    hint: """
                    This password encrypts your backup. You'll need it to restore \
                    your accounts. It cannot be recovered.
                    """
                )
            }
            .sesameSheetContent()
            .navigationTitle("iCloud Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enable", action: save)
                        .bold()
                        .tint(profileTint)
                }
            }
        }

        private func save() {
            showValidation = true
            guard PasswordValidation.isValid(password: password, confirmation: confirmPassword) else { return }

            do {
                try backupStore.backupService.saveBackupPassword(password, for: adapter.adapterKey)
                onComplete()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
#endif
