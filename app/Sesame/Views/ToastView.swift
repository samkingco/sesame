import SwiftUI

struct ToastView: View {
    let state: ToastState
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            pill
                .frame(height: 44)
                .offset(y: state.isVisible && !reduceMotion ? 0 : -60)
                .blur(radius: state.isVisible ? 0 : 10)
                .opacity(state.isVisible ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.15), value: state.isVisible)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    state.pillFrame = state.isVisible ? frame : .zero
                }
            Spacer()
        }
        .sensoryFeedback(.success, trigger: state.showCount) { _, _ in
            HapticService.isEnabled
        }
        .onChange(of: state.showCount) {
            AccessibilityNotification.Announcement(state.message).post()
        }
    }

    private var pill: some View {
        Button(action: onDismiss) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(state.message)
            }
            .font(.subheadline)
            .bold()
            .foregroundStyle(.black)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(.green, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.message)
    }
}
