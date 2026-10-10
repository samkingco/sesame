import SwiftUI

struct CopiedCodeLockScreenView: View {
    let issuer: String

    var body: some View {
        HStack(spacing: 12) {
            Image("seeds")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(issuer)
                    .font(.headline)
                Text("Code copied")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
                .accessibilityLabel("Code hidden on Lock Screen")
        }
        .padding()
    }
}
