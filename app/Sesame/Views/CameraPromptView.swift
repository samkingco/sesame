import SwiftUI

struct CameraPromptView: View {
    @Environment(\.profileTint) private var profileTint

    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    var isFullHeight = false
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(profileTint)
        }
        .geometryGroup()
        .safeAreaPadding(.bottom, isFullHeight ? 80 : 20)
    }
}
