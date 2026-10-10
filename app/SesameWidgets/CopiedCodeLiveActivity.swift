import ActivityKit
import SwiftUI
import WidgetKit

struct CopiedCodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CopiedCodeAttributes.self) { context in
            // Never show the code on the Lock Screen
            CopiedCodeLockScreenView(issuer: context.attributes.issuer)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    CopiedCodeExpandedView(
                        attributes: context.attributes,
                        state: context.state,
                        isStale: context.isStale
                    )
                }
            } compactLeading: {
                SeedsIcon()
            } compactTrailing: {
                Text(CodeFormatting.formatted(context.isStale ? nil : context.state.code))
                    .font(.caption.monospacedDigit())
                    .bold()
                    .foregroundStyle(context.isStale ? CodeColorState.empty.color : context.state.colorState.color)
                    .padding(.trailing, 2)
            } minimal: {
                SeedsIcon()
            }
        }
    }
}
