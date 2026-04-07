import SwiftUI

struct RestoreConfirmView: View {
    let payload: BackupPayload
    let backupService: BackupService
    let onComplete: () -> Void

    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore

    @State private var isRestoring = false
    @State private var restoreError: String?
    @State private var restoreComplete = false
    @State private var showConfirmation = false

    private let restoreService = RestoreService()

    private var accountsByProfile: [(name: String, accounts: [BackupAccount])] {
        let grouped = Dictionary(grouping: payload.accounts) { $0.profileId }

        return payload.profiles
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { profile in
                (name: profile.name, accounts: grouped[profile.id] ?? [])
            }
    }

    var body: some View {
        Form {
            if restoreComplete {
                Section {
                    Label("Restore complete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .sesameRowBackground()
                }
            }

            ForEach(accountsByProfile, id: \.name) { group in
                Section(group.name) {
                    if group.accounts.isEmpty {
                        Text("No accounts")
                            .foregroundStyle(.secondary)
                            .sesameRowBackground()
                    } else {
                        ForEach(group.accounts, id: \.id) { account in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.effectiveIssuer)
                                Text(account.effectiveName)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .sesameRowBackground()
                        }
                    }
                }
            }

            if let error = restoreError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .sesameRowBackground()
                }
            }
        }
        .sesameSheetContent()
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if restoreComplete {
                    Button("Done", action: onComplete).bold()
                } else if isRestoring {
                    ProgressView()
                } else {
                    Button("Restore", action: { showConfirmation = true })
                        .bold()
                        .tint(profileTint)
                }
            }
        }
        .alert("Replace All Data?", isPresented: $showConfirmation) {
            Button("Replace All", role: .destructive, action: executeRestore)
            Button("Cancel", role: .cancel) {}
        } message: {
            // swiftlint:disable:next line_length
            Text(
                "All existing accounts and profiles will be deleted and replaced with this backup. This cannot be undone."
            )
        }
    }

    private func executeRestore() {
        isRestoring = true
        restoreError = nil

        do {
            try restoreService.restore(
                payload: payload,
                modelContext: backupService.modelContext,
                keychain: backupService.keychain
            )
            restoreComplete = true
            backupStore.scheduleAutoBackup()
            #if AUTOFILL_CAPABLE
                if AutoFillService.isEnabled {
                    Task { await AutoFillService.syncIdentityStore() }
                }
            #endif
        } catch {
            restoreError = error.localizedDescription
        }

        isRestoring = false
    }
}
