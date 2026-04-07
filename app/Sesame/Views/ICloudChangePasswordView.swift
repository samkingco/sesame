#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudChangePasswordView: View {
        @Environment(BackupStore.self) private var backupStore
        @Environment(\.profileTint) private var profileTint
        @Environment(\.dismiss) private var dismiss

        let adapter: BackupAdapter

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
                    emptyMessage: "Enter a new password.",
                    error: saveError,
                    hint: "Changing your password will re-encrypt and back up immediately."
                )
            }
            .sesameSheetContent()
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
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
                Task { await backupStore.backup(using: adapter) }
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
#endif
