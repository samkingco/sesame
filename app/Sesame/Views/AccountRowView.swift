import SwiftUI

struct AccountRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.profileTint) private var profileTint

    let account: Account
    let code: GeneratedCode?
    let currentDate: Date
    var isCopied = false
    var issuerHighlight: SearchHit.Highlight?
    var nameHighlight: SearchHit.Highlight?

    private var issuerText: String {
        account.effectiveIssuer
    }

    private var nameText: String {
        account.effectiveName
    }

    private var remainingSeconds: Int {
        guard account.type == .totp, let end = code?.windowEnd else { return 0 }
        return max(0, Int(ceil(end.timeIntervalSince(currentDate))))
    }

    private var colorState: CodeColorState {
        CodeColorState(code: code?.code, isCopied: isCopied, type: account.type, remainingSeconds: remainingSeconds)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(highlighted(issuerText, highlight: issuerHighlight))
                    .font(.headline)
                    .lineLimit(1)
                Text(highlighted(nameText, highlight: nameHighlight))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(CodeFormatting.formatted(code?.code))
                .font(.title2.monospaced())
                .foregroundStyle(colorState.color)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeInOut(duration: CodeAnimation.duration), value: colorState)
                .animation(reduceMotion ? nil : .easeInOut(duration: CodeAnimation.duration), value: code?.code)
                .accessibilityLabel("Verification code: \(CodeFormatting.spoken(code?.code))")
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func highlighted(_ text: String, highlight: SearchHit.Highlight?) -> AttributedString {
        var str = AttributedString(text)
        guard let highlight else { return str }
        let chars = str.characters
        let start = chars.index(chars.startIndex, offsetBy: highlight.offset)
        let end = chars.index(start, offsetBy: highlight.length)
        str[start ..< end].backgroundColor = profileTint.opacity(colorScheme == .dark ? 0.35 : 0.2)
        return str
    }
}
