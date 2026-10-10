import SwiftUI

struct SeedsIcon: View {
    var body: some View {
        Image("seeds")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }
}
