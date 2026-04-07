import SwiftUI

@MainActor
enum PrivacyWindowService {
    private static var window: UIWindow?
    private static var retryHosting: UIHostingController<RetryView>?

    static func start() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main,
            using: { _ in MainActor.assumeIsolated { show() } }
        )
    }

    static func show() {
        guard AppLockService.isEnabled, window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }

        let vc = UIViewController()
        vc.view.backgroundColor = .clear

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.frame = vc.view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(blur)

        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.rootViewController = vc
        w.isHidden = false
        window = w
    }

    static func showRetry(onRetry: @escaping () -> Void) {
        guard let vc = window?.rootViewController else { return }

        retryHosting?.willMove(toParent: nil)
        retryHosting?.view.removeFromSuperview()
        retryHosting?.removeFromParent()

        let hc = UIHostingController(rootView: RetryView(onUnlock: onRetry))
        hc.view.backgroundColor = .clear
        hc.view.frame = vc.view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        vc.addChild(hc)
        vc.view.addSubview(hc.view)
        hc.didMove(toParent: vc)
        retryHosting = hc
    }

    static func hide() {
        retryHosting?.willMove(toParent: nil)
        retryHosting?.view.removeFromSuperview()
        retryHosting?.removeFromParent()
        retryHosting = nil
        window?.isHidden = true
        window = nil
    }
}

private struct RetryView: View {
    let onUnlock: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Locked", systemImage: AppLockService.lockIcon)
        } description: {
            Text("Sesame is locked. Authenticate to continue.")
        } actions: {
            Button("Unlock", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}
