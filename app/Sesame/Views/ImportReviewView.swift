import SwiftData
import SwiftUI

struct ImportReviewView: View {
    let accounts: [ParsedOTPAccount]
    let initialProfileId: UUID
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]

    @State private var selectedProfileId: UUID
    @State private var selectedIndices: Set<Int>
    @State private var isImporting = false
    @State private var importError: String?

    private let keychain: KeychainServiceProtocol

    init(
        accounts: [ParsedOTPAccount],
        initialProfileId: UUID,
        keychain: KeychainServiceProtocol = KeychainService(),
        onDone: @escaping () -> Void
    ) {
        self.accounts = accounts
        self.initialProfileId = initialProfileId
        self.keychain = keychain
        self.onDone = onDone
        _selectedProfileId = State(initialValue: initialProfileId)
        _selectedIndices = State(initialValue: Set(accounts.indices))
    }

    var body: some View {
        Form {
            if profiles.count >= 2 {
                Section {
                    Picker("Import to", selection: $selectedProfileId) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .sesameRowBackground()
                }
            }

            Section {
                ForEach(Array(accounts.enumerated()), id: \.offset) { index, account in
                    ImportAccountRow(
                        account: account,
                        isSelected: selectedIndices.contains(index),
                        disabled: isImporting,
                        onToggle: { toggleSelection(index) }
                    )
                }
            }

            if let importError {
                Section {
                    Text(importError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .sesameRowBackground()
                }
            }
        }
        .sesameSheetContent()
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isImporting {
                    ProgressView()
                } else {
                    Button("Import", action: executeImport)
                        .bold()
                        .disabled(selectedIndices.isEmpty)
                        .tint(profileTint)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    private func executeImport() {
        isImporting = true
        importError = nil

        do {
            let existingAccounts = try AccountService.fetchActive(modelContext: modelContext)

            let candidateSecrets = Set(accounts.map(\.secret))
            var duplicateSecrets = try AccountService.findDuplicateSecrets(
                candidates: candidateSecrets,
                keychain: keychain,
                modelContext: modelContext
            )

            // Build set of existing issuer+name combos for suffix incrementing
            var existingNames = Set<String>()
            for account in existingAccounts {
                existingNames.insert(dedupKey(issuer: account.effectiveIssuer, name: account.effectiveName))
            }

            for index in selectedIndices.sorted() {
                let parsed = accounts[index]
                var name = parsed.name

                if duplicateSecrets.contains(parsed.secret) {
                    var suffix = 2
                    var candidate = "\(parsed.name) (\(suffix))"
                    while existingNames.contains(
                        dedupKey(issuer: parsed.issuer ?? "", name: candidate)
                    ) {
                        suffix += 1
                        candidate = "\(parsed.name) (\(suffix))"
                    }
                    name = candidate
                }

                let newAccount = Account(
                    profileId: selectedProfileId,
                    issuer: parsed.issuer ?? "",
                    name: name,
                    type: parsed.type,
                    algorithm: parsed.algorithm,
                    digits: parsed.digits,
                    period: parsed.period,
                    counter: parsed.counter,
                    website: parsed.website
                )

                try AccountService.create(
                    account: newAccount,
                    secret: parsed.secret,
                    keychain: keychain,
                    modelContext: modelContext,
                    backupStore: backupStore
                )

                // Track for dedup within the batch
                duplicateSecrets.insert(parsed.secret)
                existingNames.insert(dedupKey(issuer: parsed.issuer ?? "", name: name))
            }

            let count = selectedIndices.count
            Toast.show("Imported \(count) account\(count == 1 ? "" : "s")")
            onDone()
        } catch {
            importError = error.localizedDescription
            isImporting = false
        }
    }

    private func dedupKey(issuer: String, name: String) -> String {
        "\(issuer):\(name)"
    }
}

// MARK: - ImportAccountRow

private struct ImportAccountRow: View {
    let account: ParsedOTPAccount
    let isSelected: Bool
    let disabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.issuer ?? account.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if account.issuer != nil {
                        Text(account.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .sesameRowBackground()
    }
}
