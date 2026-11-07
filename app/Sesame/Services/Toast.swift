import SwiftUI

// MARK: - State

@MainActor @Observable
final class ToastState {
    var isVisible = false
    var message = ""
    var showCount = 0
    var pillFrame: CGRect = .zero
    var topInset: Double = 0
}

// MARK: - Manager

@MainActor
enum Toast {
    private static var window: PassThroughWindow?
    private static let displayDuration: Double = 2
    private static let state = ToastState()
    private static var dismissTask: Task<Void, Never>?

    static func show(_ message: String) {
        dismissTask?.cancel()

        state.message = message

        let isFirstShow = window == nil
        ensureWindow()
        state.topInset = navigationBarTop()

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

    /// Convenience for the copy action — builds the duration-aware message.
    static func showCopied() {
        let duration = ClipboardService.ClearDuration(
            rawValue: ClipboardService.clearDuration
        )

        let message = if let duration {
            switch duration {
            case .never: "Copied"
            case .thirtySeconds: "Copied for 30s"
            case .oneMinute: "Copied for 1m"
            case .fiveMinutes: "Copied for 5m"
            }
        } else {
            "Copied"
        }

        show(message)
    }

    static func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        state.isVisible = false
    }

    /// The top of the app's navigation bar, so the toast lines up with it. This is
    /// not always the safe-area top: on iPhone Duo the status bar is at the side,
    /// the safe area has no top inset, and the navigation bar starts 24 pt down.
    private static func navigationBarTop() -> Double {
        guard let window else { return 0 }
        let appWindow = window.windowScene?.keyWindow ?? window
        guard let bar = firstNavigationBar(in: appWindow) else {
            return appWindow.safeAreaInsets.top
        }
        return bar.convert(bar.bounds, to: appWindow).minY
    }

    /// Depth-first search that skips hidden and transparent views.
    private static func firstNavigationBar(in view: UIView) -> UINavigationBar? {
        guard !view.isHidden, view.alpha > 0 else { return nil }
        if let bar = view as? UINavigationBar {
            return bar
        }
        for subview in view.subviews {
            if let bar = firstNavigationBar(in: subview) {
                return bar
            }
        }
        return nil
    }

    private static func ensureWindow() {
        guard window == nil else { return }

        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first
        else { return }

        let toastView = ToastView(state: state) {
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
    var toastState: ToastState?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let toastState, toastState.isVisible,
              toastState.pillFrame.contains(point)
        else { return nil }
        return super.hitTest(point, with: event)
    }
}
