import SwiftUI

struct EditAccountResult {
    let displayIssuer: String?
    let displayName: String?
    let profileId: UUID?
    let website: String?
}

struct EditAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint

    let account: Account
    let profiles: [Profile]
    var onSave: (EditAccountResult) -> Void

    @State private var editableIssuer: String
    @State private var editableName: String
    @State private var editableWebsite: String
    @State private var selectedProfileId: UUID
    @State private var currentDetent: PresentationDetent = .medium

    init(
        account: Account,
        profiles: [Profile],
        onSave: @escaping (EditAccountResult) -> Void
    ) {
        self.account = account
        self.profiles = profiles
        self.onSave = onSave
        _editableIssuer = State(initialValue: account.effectiveIssuer)
        _editableName = State(initialValue: account.effectiveName)
        _editableWebsite = State(initialValue: account.website ?? "")
        _selectedProfileId = State(initialValue: account.profileId)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Issuer") {
                        TextField(account.issuer, text: $editableIssuer)
                            .multilineTextAlignment(.trailing)
                    }
                    .sesameRowBackground()
                    LabeledContent("Account") {
                        TextField(account.name, text: $editableName)
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

                if profiles.count >= 2 {
                    Section {
                        Picker("Profile", selection: $selectedProfileId) {
                            ForEach(profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        .sesameRowBackground()
                    }
                }
            }
            .sesameSheetContent()
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .bold()
                        .tint(profileTint)
                }
            }
        }
        .sesameSheet(currentDetent: $currentDetent)
    }

    private func save() {
        let trimmedIssuer = editableIssuer.trimmingCharacters(in: .whitespaces)
        let trimmedName = editableName.trimmingCharacters(in: .whitespaces)
        let trimmedWebsite = editableWebsite.trimmingCharacters(in: .whitespaces)

        // nil means "no override, use original"
        let newDisplayIssuer: String? = trimmedIssuer == account.issuer || trimmedIssuer.isEmpty
            ? nil : trimmedIssuer
        let newDisplayName: String? = trimmedName == account.name || trimmedName.isEmpty
            ? nil : trimmedName
        let newProfileId: UUID? = selectedProfileId != account.profileId
            ? selectedProfileId : nil
        let newWebsite: String? = trimmedWebsite.isEmpty ? nil : trimmedWebsite

        onSave(EditAccountResult(
            displayIssuer: newDisplayIssuer,
            displayName: newDisplayName,
            profileId: newProfileId,
            website: newWebsite
        ))
        dismiss()
    }
}
