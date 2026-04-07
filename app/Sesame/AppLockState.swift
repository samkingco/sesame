import LocalAuthentication
import SwiftUI

// MARK: - AuthenticationContext

protocol AuthenticationContext: Sendable {
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool
    var biometryType: LABiometryType { get }
}

extension LAContext: AuthenticationContext {}

// MARK: - AppLockState

@MainActor @Observable
final class AppLockState {
    private(set) var isLocked: Bool
    var backgroundedAt: Date?
    private var isAuthenticating = false

    private let authContext: AuthenticationContext
    private let isEnabled: @Sendable () -> Bool
    private let lockDelay: @Sendable () -> Int

    init(
        authContext: AuthenticationContext = LAContext(),
        isEnabled: @escaping @Sendable () -> Bool = { AppLockService.isEnabled },
        lockDelay: @escaping @Sendable () -> Int = { AppLockService.delay }
    ) {
        self.authContext = authContext
        self.isEnabled = isEnabled
        self.lockDelay = lockDelay
        isLocked = isEnabled()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isEnabled() else {
            isLocked = false
            PrivacyWindowService.hide()
            return
        }

        switch phase {
        case .inactive:
            PrivacyWindowService.show()
        case .background:
            backgroundedAt = .now
        case .active:
            if isLocked {
                PrivacyWindowService.show()
                Task { await attemptUnlock() }
            } else if let backgroundedAt {
                let elapsed = Date.now.timeIntervalSince(backgroundedAt)
                self.backgroundedAt = nil
                if elapsed >= Double(lockDelay()) {
                    isLocked = true
                    Task { await attemptUnlock() }
                } else {
                    PrivacyWindowService.hide()
                }
            } else {
                PrivacyWindowService.hide()
            }
        @unknown default:
            break
        }
    }

    func attemptUnlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let success: Bool
        do {
            success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Sesame"
            )
        } catch {
            success = false
        }

        if success {
            isLocked = false
            backgroundedAt = nil
            PrivacyWindowService.hide()
        } else {
            PrivacyWindowService.showRetry { [weak self] in
                Task { await self?.attemptUnlock() }
            }
        }
    }
}
