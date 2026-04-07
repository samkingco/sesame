import SwiftData
import SwiftUI

struct AccountConfirmationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore

    let parsed: ParsedOTPAccount
    let profileId: UUID
    var onSaved: (Account) -> Void

    @State private var editableIssuer: String
    @State private var editableName: String
    @State private var editableWebsite: String
    @State private var saveError: String?

    private var detailsSummary: String {
        var parts = [
            parsed.type.rawValue.uppercased(),
            parsed.algorithm.rawValue.uppercased(),
            "\(parsed.digits) digits",
        ]
        if parsed.type == .totp {
            parts.append("\(parsed.period)s")
        }
        if parsed.type == .hotp {
            parts.append("counter \(parsed.counter)")
        }
        return parts.joined(separator: " · ")
    }

    private var nameIsEmpty: Bool {
        editableName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let keychain: KeychainServiceProtocol

    init(
        parsed: ParsedOTPAccount,
        profileId: UUID,
        keychain: KeychainServiceProtocol = KeychainService(),
        onSaved: @escaping (Account) -> Void
    ) {
        self.parsed = parsed
        self.profileId = profileId
        self.keychain = keychain
        self.onSaved = onSaved
        _editableIssuer = State(initialValue: parsed.issuer ?? "")
        _editableName = State(initialValue: parsed.name)
        _editableWebsite = State(initialValue: parsed.website ?? "")
    }

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Issuer") {
                    TextField("Issuer", text: $editableIssuer)
                        .multilineTextAlignment(.trailing)
                }
                .sesameRowBackground()
                LabeledContent("Account Name") {
                    TextField("Account Name", text: $editableName)
                        .multilineTextAlignment(.trailing)
                }
                .sesameRowBackground()
                LabeledContent("Website") {
                    TextField("example.com", text: $editableWebsite)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                .sesameRowBackground()
            }

            Section("Details") {
                Text(detailsSummary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .sesameRowBackground()
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(.red)
                        .sesameRowBackground()
                }
            }
        }
        .sesameSheetContent()
        .navigationTitle("Confirm Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .bold()
                    .disabled(nameIsEmpty)
                    .tint(profileTint)
            }
        }
    }

    private func save() {
        let trimmedIssuer = editableIssuer.trimmingCharacters(in: .whitespaces)
        let trimmedName = editableName.trimmingCharacters(in: .whitespaces)
        let trimmedWebsite = editableWebsite.trimmingCharacters(in: .whitespaces)

        let account = Account(
            profileId: profileId,
            issuer: parsed.issuer ?? trimmedIssuer,
            displayIssuer: trimmedIssuer != (parsed.issuer ?? "") ? trimmedIssuer : nil,
            name: parsed.name,
            displayName: trimmedName != parsed.name ? trimmedName : nil,
            type: parsed.type,
            algorithm: parsed.algorithm,
            digits: parsed.digits,
            period: parsed.period,
            counter: parsed.counter,
            website: trimmedWebsite.isEmpty ? nil : trimmedWebsite
        )

        do {
            try AccountService.create(
                account: account,
                secret: parsed.secret,
                keychain: keychain,
                modelContext: modelContext,
                backupStore: backupStore
            )
            onSaved(account)
        } catch {
            saveError = error.localizedDescription
        }
    }
}
