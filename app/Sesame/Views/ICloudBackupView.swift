#if ICLOUD_CAPABLE
    import SwiftUI

    struct ICloudBackupView: View {
        @Environment(BackupStore.self) private var backupStore

        let adapter: BackupAdapter

        @State private var showPasswordSetup = false
        @State private var showRecoveryKeyWarning = false
        @State private var showRemoveConfirmation = false
        @State private var showChangePassword = false
        @State private var backupRefreshID = 0

        var body: some View {
            Group {
                if backupStore.isConfigured(for: adapter) {
                    Form {
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
                            }
                        }

                        ICloudBackupFilesSection(adapter: adapter, refreshID: backupRefreshID)

                        Section {
                            Button("Change Password") {
                                showChangePassword = true
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
                                "Removes all backup data from iCloud Drive, including backups from other devices, and your backup password from this device. You can set up iCloud backup again at any time."
                            )
                        }
                        .alert("Remove iCloud Backup?", isPresented: $showRemoveConfirmation) {
                            Button("Remove", role: .destructive) {
                                Task { await backupStore.removeBackup(for: adapter) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                // swiftlint:disable:next line_length
                                "This will remove all iCloud backups, including those from other devices. Your accounts on this device are not affected."
                            )
                        }
                    }
                    .sesameSheetContent()
                } else {
                    ICloudBackupDisabledView(onSetup: handleSetup)
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
            .navigationDestination(isPresented: $showChangePassword) {
                ICloudChangePasswordView(adapter: adapter)
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

        private var autoBackupToggle: Binding<Bool> {
            Binding(
                get: { backupStore.isAutoBackupEnabled(for: adapter) },
                set: { backupStore.setAutoBackupEnabled($0, for: adapter) }
            )
        }

        private func handleSetup() {
            if backupStore.recoveryKeyWarningShown {
                showPasswordSetup = true
            } else {
                showRecoveryKeyWarning = true
            }
        }

        private func backUpNow() {
            Task {
                await backupStore.backup(using: adapter)
                backupRefreshID += 1
            }
        }
    }
#endif
