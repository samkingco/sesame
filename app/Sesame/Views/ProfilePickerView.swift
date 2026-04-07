import SwiftUI

struct ProfilePickerView: View {
    let profiles: [Profile]
    let selectedProfileId: UUID
    let onSelect: (UUID) -> Void
    let onAddProfile: () -> Void
    let onManage: () -> Void

    var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Button {
                    onSelect(profile.id)
                } label: {
                    Label {
                        Text(profile.name)
                    } icon: {
                        coloredIcon(
                            for: profile,
                            selected: profile.id == selectedProfileId
                        )
                    }
                }
            }

            Divider()

            Button(action: onAddProfile) {
                Label("Add Profile", systemImage: "plus")
            }

            Button(action: onManage) {
                Label("Manage Profiles", systemImage: "person.2.badge.key")
            }
        } label: {
            Label("Profiles", systemImage: "face.smiling")
                .labelStyle(.iconOnly)
        }
    }

    private func coloredIcon(for profile: Profile, selected: Bool) -> Image {
        let name = selected ? "checkmark.circle.fill" : "circle.fill"
        let uiColor = UIColor(Color(hex: profile.color ?? Profile.defaultColor))
        let uiImage = UIImage(systemName: name)?
            .withTintColor(uiColor, renderingMode: .alwaysOriginal)
        return Image(uiImage: uiImage ?? UIImage())
    }
}
