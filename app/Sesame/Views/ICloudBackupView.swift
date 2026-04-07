#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudBackupView: View {
        @Environment(BackupStore.self) private var backupStore
        @Environment(\.profileTint) private var profileTint

        let adapter: BackupAdapter

        @State private var showPasswordSetup = false
        @State private var showRecoveryKeyWarning = false
        @State private var showRemoveConfirmation = false

        var body: some View {
            Group {
                if backupStore.isConfigured(for: adapter) {
                    Form {
                        enabledContent
                    }
                    .sesameSheetContent()
                } else {
                    disabledContent
                }
            }
            .navigationTitle("iCloud Backup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showPasswordSetup) {
                ICloudPasswordSetupView(adapter: adapter) {
                    backupStore.setAutoBackupEnabled(true, for: adapter)
                    Task { await backupStore.backup(using: adapter) }
                    showPasswordSetup = false
                }
            }
            .alert("Do you use Sesame for your Apple ID?", isPresented: $showRecoveryKeyWarning) {
                Button("Set Up Recovery Key") {
                    backupStore.recoveryKeyWarningShown = true
                    if let url = URL(string: "https://support.apple.com/en-us/102403") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Continue to Backup") {
                    backupStore.recoveryKeyWarningShown = true
                    showPasswordSetup = true
                }
            } message: {
                Text(
                    // swiftlint:disable:next line_length
                    "If you lose your device, you'll need an Apple Recovery Key to access iCloud and restore your backup. Set one up before continuing."
                )
            }
        }

        private var disabledContent: some View {
            ContentUnavailableView {
                Label("iCloud Backup", systemImage: "icloud")
            } description: {
                Text(
                    // swiftlint:disable:next line_length
                    "Encrypt and back up your accounts to iCloud Drive. If you use Sesame for your Apple ID, save your backup codes separately in case you lose access to your device."
                )
            } actions: {
                Button("Set Up iCloud Backup") {
                    if backupStore.recoveryKeyWarningShown {
                        showPasswordSetup = true
                    } else {
                        showRecoveryKeyWarning = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(profileTint)
            }
            .geometryGroup()
            .safeAreaPadding(.bottom, 20)
            .sesameSheetContent()
        }

        @MainActor @ViewBuilder
        private var enabledContent: some View {
            Section {
                Toggle("Back Up Automatically", isOn: autoBackupToggle)
                    .sesameRowBackground()

                Button("Back Up Now", action: backUpNow)
                    .disabled(backupStore.isBackingUp)
                    .sesameRowBackground()
            } footer: {
                if let error = backupStore.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                } else if let date = backupStore.lastDeviceBackupDate(for: adapter) {
                    Text("Last backup \(date, format: .relative(presentation: .named))")
                } else {
                    Text("Not backed up yet")
                }
            }

            Section {
                NavigationLink("Change Password") {
                    ICloudChangePasswordView(adapter: adapter)
                }
                .sesameRowBackground()
            }

            Section {
                Button("Remove iCloud Backup", role: .destructive) {
                    showRemoveConfirmation = true
                }
                .sesameRowBackground()
            } footer: {
                Text(
                    // swiftlint:disable:next line_length
                    "Removes your backup data from iCloud Drive and your backup password from this device. You can set up iCloud backup again at any time."
                )
            }
            .alert("Remove iCloud Backup?", isPresented: $showRemoveConfirmation) {
                Button("Remove", role: .destructive) {
                    Task { await backupStore.removeBackup(for: adapter) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your accounts on this device are not affected.")
            }
        }

        private var autoBackupToggle: Binding<Bool> {
            Binding(
                get: { backupStore.isAutoBackupEnabled(for: adapter) },
                set: { backupStore.setAutoBackupEnabled($0, for: adapter) }
            )
        }

        private func backUpNow() {
            Task { await backupStore.backup(using: adapter) }
        }
    }
#endif
