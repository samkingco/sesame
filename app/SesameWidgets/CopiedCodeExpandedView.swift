import SwiftUI

struct CopiedCodeExpandedView: View {
    let attributes: CopiedCodeAttributes
    let state: CopiedCodeAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(CodeFormatting.formatted(isStale ? nil : state.code))
                .font(.title.monospaced())
                .foregroundStyle(colorState.color)
                .contentTransition(.numericText())

            Text(attributes.issuer)
                .font(.headline)
                .padding(.top, 6)

            Text(attributes.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var colorState: CodeColorState {
        isStale ? .empty : state.colorState
    }
}
