import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore

    let profile: Profile
    var accountCount = 0
    var onDelete: ((_ moveAccounts: Bool) -> Void)?

    @State private var name: String
    @State private var selectedColor: String?
    @State private var showDeleteConfirmation = false

    init(
        profile: Profile,
        accountCount: Int = 0,
        onDelete: ((_ moveAccounts: Bool) -> Void)? = nil
    ) {
        self.profile = profile
        self.accountCount = accountCount
        self.onDelete = onDelete
        _name = State(initialValue: profile.name)
        _selectedColor = State(initialValue: profile.color)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Work", text: $name)
                    .sesameRowBackground()
            }

            Section("Color") {
                ColorPaletteView(selectedColor: $selectedColor)
                    .sesameRowBackground()
            }

            if !profile.isDefault, onDelete != nil {
                Section {
                    Button("Delete Profile", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .sesameRowBackground()
                }
            }
        }
        .sesameSheetContent()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .labelStyle(.iconOnly)
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(profileTint)
            }
        }
        .alert("Delete Profile?", isPresented: $showDeleteConfirmation) {
            if accountCount > 0 {
                Button("Move to Personal") {
                    onDelete?(true)
                    dismiss()
                }
                Button("Delete Accounts Too", role: .destructive) {
                    onDelete?(false)
                    dismiss()
                }
            } else {
                Button("Delete", role: .destructive) {
                    onDelete?(false)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if accountCount > 0 {
                // swiftlint:disable:next line_length
                Text(
                    "\"\(profile.name)\" has ^[\(accountCount) account](inflect: true). What would you like to do with them?"
                )
            } else {
                Text("\"\(profile.name)\" will be permanently deleted.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profile.name = trimmed
        profile.color = selectedColor
        ProfileService.update(backupStore: backupStore)
        dismiss()
    }
}
