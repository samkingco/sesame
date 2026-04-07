import ActivityKit
import SwiftUI
import WidgetKit

struct CopiedCodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CopiedCodeAttributes.self) { _ in
            // No Lock Screen presentation
            EmptyView()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(state: context.state, issuer: context.attributes.issuer)
                }
            } compactLeading: {
                Image("seeds")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(CodeFormatting.formatted(context.state.code))
                    .font(.caption.monospacedDigit())
                    .bold()
                    .padding(.trailing, 2)
            } minimal: {
                Image("seeds")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Expanded view

private struct ExpandedView: View {
    let state: CopiedCodeAttributes.ContentState
    let issuer: String

    var body: some View {
        VStack(spacing: 4) {
            Text(issuer)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(CodeFormatting.formatted(state.code))
                .font(.title.monospacedDigit())
                .bold()
                .contentTransition(.numericText())

            Text(timerInterval: Date.now...state.expiresAt, countsDown: true)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let nextCode = state.nextCode {
                HStack(spacing: 4) {
                    Text("Next:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CodeFormatting.formatted(nextCode))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
