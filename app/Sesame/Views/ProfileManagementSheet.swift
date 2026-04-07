import SwiftData
import SwiftUI

struct ProfileManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BackupStore.self) private var backupStore
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    @Query private var allAccounts: [Account]

    @State private var showingAddProfile = false
    @State private var profileToDelete: Profile?
    @State private var showDeleteConfirmation = false
    @State private var editMode: EditMode = .inactive
    @State private var currentDetent: PresentationDetent = .medium

    private let keychain: KeychainServiceProtocol
    private let onAdd: ((UUID) -> Void)?

    init(
        keychain: KeychainServiceProtocol = KeychainService(),
        onAdd: ((UUID) -> Void)? = nil
    ) {
        self.keychain = keychain
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Profiles") {
                    ForEach(profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            color: profileColor(profile),
                            onDelete: {
                                profileToDelete = profile
                                showDeleteConfirmation = true
                            }
                        )
                        .sesameRowBackground()
                    }
                    .onMove(perform: moveProfiles)
                    .onDelete(perform: deleteProfiles)
                }

                if !editMode.isEditing {
                    Section {
                        Button {
                            showingAddProfile = true
                        } label: {
                            Label("Add Profile", systemImage: "plus")
                        }
                        .foregroundStyle(.primary)
                        .sesameRowBackground()
                    } footer: {
                        Text("Group your accounts by context — personal, work, freelance, whatever fits.")
                    }
                }
            }
            .sesameSheetContent()
            .environment(\.editMode, $editMode)
            .navigationTitle("Manage Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingAddProfile) {
                AddProfileView(onAdd: onAdd)
            }
            .navigationDestination(for: Profile.self) { profile in
                EditProfileView(
                    profile: profile,
                    accountCount: accountCount(for: profile),
                    onDelete: { moveAccounts in
                        deleteProfile(profile, moveAccounts: moveAccounts)
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
            }
            .alert(
                "Delete Profile?",
                isPresented: $showDeleteConfirmation,
                presenting: profileToDelete
            ) { profile in
                deleteActions(for: profile)
            } message: { profile in
                deleteMessage(for: profile)
            }
        }
        .sesameSheet(currentDetent: $currentDetent)
    }

    // MARK: - Reorder

    private func moveProfiles(from source: IndexSet, to destination: Int) {
        var ordered = Array(profiles)
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, profile) in ordered.enumerated() {
            profile.sortOrder = index
        }
        ProfileService.update(backupStore: backupStore)
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            let profile = profiles[index]
            guard !profile.isDefault else { return }
            profileToDelete = profile
            showDeleteConfirmation = true
        }
    }

    // MARK: - Delete

    @ViewBuilder
    private func deleteActions(for profile: Profile) -> some View {
        let count = accountCount(for: profile)
        if count > 0 {
            Button("Move Accounts to Personal") {
                deleteProfile(profile, moveAccounts: true)
            }
            Button("Delete Accounts Too", role: .destructive) {
                deleteProfile(profile, moveAccounts: false)
            }
        } else {
            Button("Delete", role: .destructive) {
                deleteProfile(profile, moveAccounts: false)
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private func deleteMessage(for profile: Profile) -> some View {
        let count = accountCount(for: profile)
        if count > 0 {
            Text("\"\(profile.name)\" has ^[\(count) account](inflect: true). What would you like to do with them?")
        } else {
            Text("\"\(profile.name)\" will be permanently deleted.")
        }
    }

    private func deleteProfile(_ profile: Profile, moveAccounts: Bool) {
        let accounts = allAccounts.filter { $0.profileId == profile.id }
        ProfileService.delete(
            profile: profile,
            accounts: accounts,
            moveAccounts: moveAccounts,
            keychain: keychain,
            modelContext: modelContext,
            backupStore: backupStore
        )
    }

    // MARK: - Helpers

    private func accountCount(for profile: Profile) -> Int {
        allAccounts.count(where: { $0.profileId == profile.id })
    }

    private func profileColor(_ profile: Profile) -> Color {
        if let hex = profile.color {
            return Color(hex: hex)
        }
        return .gray
    }
}

private struct ProfileRow: View {
    let profile: Profile
    let color: Color
    let onDelete: () -> Void

    @Environment(\.editMode) private var editMode

    var body: some View {
        NavigationLink(value: profile) {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(profile.name)
            }
        }
        .disabled(editMode?.wrappedValue.isEditing ?? false)
        .deleteDisabled(profile.isDefault)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !profile.isDefault {
                Button {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }
}
