import SwiftUI

/// The code on one line. A narrow Dynamic Island stacks the two halves.
struct CopiedCodeCompactTrailingView: View {
    let code: String?
    let color: AnyShapeStyle

    @Environment(\.isDynamicIslandNarrow) private var isNarrow

    var body: some View {
        Group {
            if isNarrow {
                let halves = CodeFormatting.halves(code)
                VStack(spacing: 0) {
                    Text(halves.first)
                    Text(halves.second)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityElement(children: .combine)
            } else {
                Text(CodeFormatting.formatted(code))
                    .padding(.trailing, 2)
            }
        }
        .font(.caption.monospacedDigit())
        .bold()
        .foregroundStyle(color)
    }
}
