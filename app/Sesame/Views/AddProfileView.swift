import SwiftData
import SwiftUI

struct AddProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.profileTint) private var profileTint
    @Environment(BackupStore.self) private var backupStore

    var showCancel = false
    var onAdd: ((UUID) -> Void)?

    @Query private var profiles: [Profile]
    @State private var name = ""
    @State private var selectedColor: String?

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
        }
        .sesameSheetContent()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Add Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: save)
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(profileTint)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let maxSortOrder = profiles.map(\.sortOrder).max() ?? 0
        let profile = Profile(name: trimmed, color: selectedColor, sortOrder: maxSortOrder + 1)
        ProfileService.create(profile: profile, modelContext: modelContext, backupStore: backupStore)
        onAdd?(profile.id)
        dismiss()
    }
}
