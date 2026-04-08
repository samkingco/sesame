import SwiftUI

struct AccountRowButton: View {
    @Environment(\.profileTint) private var profileTint

    let account: Account
    let code: GeneratedCode?
    let currentDate: Date
    let isCopied: Bool
    var issuerHighlight: SearchHit.Highlight?
    var nameHighlight: SearchHit.Highlight?
    var onCopy: () -> Void
    var onIncrement: (() -> Void)?
    var onViewLarger: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        rowContent
            .foregroundStyle(.primary)
            .swipeActions(edge: .trailing) {
                Button("Delete", action: onDelete)
                    .tint(.red)
            }
            .swipeActions(edge: .leading) {
                Button("Edit", action: onEdit)
                    .tint(profileTint)
            }
            .contextMenu {
                Button(action: onViewLarger) {
                    Label("View Larger", systemImage: "rectangle.expand.diagonal")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil.line")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Button(action: onCopy) {
                AccountRowView(
                    account: account,
                    code: code,
                    currentDate: currentDate,
                    isCopied: isCopied,
                    issuerHighlight: issuerHighlight,
                    nameHighlight: nameHighlight
                )
            }

            if let onIncrement {
                Button(
                    "Next Code",
                    systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill",
                    action: onIncrement
                )
                .labelStyle(.iconOnly)
                .font(.title)
                .foregroundStyle(profileTint)
                .accessibilityLabel("Generate next code")
            }
        }
        .buttonStyle(.borderless)
    }
}
