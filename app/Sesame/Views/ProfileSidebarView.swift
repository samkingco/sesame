import SwiftUI

/// Profile list shown as a sidebar when there is enough width (open iPhone Duo, iPad).
/// In compact width the split view collapses and `ProfilePickerView` is used instead.
struct ProfileSidebarView: View {
    let profiles: [Profile]
    let selectedProfileId: UUID
    let onSelect: (UUID) -> Void
    let onAddProfile: () -> Void
    let onManage: () -> Void

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(profiles) { profile in
                    ProfileSidebarRow(profile: profile)
                        .tag(profile.id)
                }
            }

            Section {
                Button("Add Profile", systemImage: "plus", action: onAddProfile)
                Button("Manage Profiles", systemImage: "person.2.badge.key", action: onManage)
            }
        }
        .navigationTitle("Profiles")
    }

    private var selection: Binding<UUID?> {
        Binding(
            get: { selectedProfileId },
            set: { id in
                guard let id, id != selectedProfileId else { return }
                onSelect(id)
            }
        )
    }
}
