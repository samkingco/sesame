import SwiftUI

// MARK: - State

@MainActor @Observable
final class CopyToastState {
    var isVisible = false
    var clearDuration: ClipboardService.ClearDuration?
    var showCount = 0
    var pillFrame: CGRect = .zero
}

// MARK: - Manager

@MainActor
enum CopyToast {
    private static var window: PassThroughWindow?
    private static let displayDuration: Double = 2
    private static let state = CopyToastState()
    private static var dismissTask: Task<Void, Never>?

    static func show() {
        dismissTask?.cancel()

        state.clearDuration = ClipboardService.ClearDuration(
            rawValue: ClipboardService.clearDuration
        )

        let isFirstShow = window == nil
        ensureWindow()

        if isFirstShow {
            // Flush the run loop so the hosting controller renders the hidden
            // state before we animate to visible. Without this the first show
            // has no slide-in animation.
            RunLoop.main.run(until: .now)
        }

        state.isVisible = true
        state.showCount += 1

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(displayDuration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    static func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        state.isVisible = false
    }

    private static func ensureWindow() {
        guard window == nil else { return }

        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first
        else { return }

        let toastView = CopyToastView(state: state) {
            dismiss()
        }
        let hosting = UIHostingController(rootView: toastView)
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false

        let win = PassThroughWindow(windowScene: scene)
        win.toastState = state
        win.windowLevel = .alert + 1
        win.backgroundColor = .clear
        win.rootViewController = hosting
        win.isHidden = false

        window = win
    }
}

// MARK: - Pass-through window

/// UIWindow that only intercepts touches within the toast pill's frame.
private final class PassThroughWindow: UIWindow {
    var toastState: CopyToastState?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let toastState, toastState.isVisible,
              toastState.pillFrame.contains(point)
        else { return nil }
        return super.hitTest(point, with: event)
    }
}
