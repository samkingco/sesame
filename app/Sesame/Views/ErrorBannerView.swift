import SwiftUI

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .padding()
    }
}
