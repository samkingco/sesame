import SwiftUI

struct ProfileSidebarRow: View {
    let profile: Profile

    var body: some View {
        Label {
            Text(profile.name)
        } icon: {
            Image(systemName: "circle.fill")
                .foregroundStyle(Color(hex: profile.color ?? Profile.defaultColor))
        }
    }
}
