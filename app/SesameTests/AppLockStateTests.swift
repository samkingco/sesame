import Foundation
import LocalAuthentication
@testable import Sesame
import Testing

// MARK: - Stub

/// Test-only stub. Properties are only mutated from @MainActor test code.
final class StubAuthContext: AuthenticationContext, @unchecked Sendable {
    nonisolated(unsafe) var canEvaluateResult = true
    nonisolated(unsafe) var evaluateResult = true
    nonisolated(unsafe) var biometryTypeValue: LABiometryType = .faceID

    func canEvaluatePolicy(_: LAPolicy, error _: NSErrorPointer) -> Bool {
        canEvaluateResult
    }

    func evaluatePolicy(
        _: LAPolicy,
        localizedReason _: String
    ) async throws -> Bool {
        if evaluateResult { return true }
        throw NSError(domain: LAErrorDomain, code: LAError.userCancel.rawValue)
    }

    var biometryType: LABiometryType {
        biometryTypeValue
    }
}

/// Simulates slow biometric evaluation for concurrency testing.
final class SlowAuthContext: AuthenticationContext, @unchecked Sendable {
    nonisolated(unsafe) var evaluateCallCount = 0

    func canEvaluatePolicy(_: LAPolicy, error _: NSErrorPointer) -> Bool {
        true
    }

    func evaluatePolicy(_: LAPolicy, localizedReason _: String) async throws -> Bool {
        evaluateCallCount += 1
        try await Task.sleep(for: .milliseconds(200))
        return true
    }

    var biometryType: LABiometryType {
        .faceID
    }
}

/// Tracks which LAPolicy was requested.
final class PolicyTrackingAuthContext: AuthenticationContext, @unchecked Sendable {
    nonisolated(unsafe) var lastPolicy: LAPolicy?

    func canEvaluatePolicy(_: LAPolicy, error _: NSErrorPointer) -> Bool {
        true
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason _: String) async throws -> Bool {
        lastPolicy = policy
        return true
    }

    var biometryType: LABiometryType {
        .faceID
    }
}

// MARK: - Helpers

@MainActor
private func makeLockState(
    authContext: StubAuthContext = StubAuthContext(),
    isEnabled: Bool = true,
    delay: Int = 0
) -> (AppLockState, StubAuthContext) {
    let state = AppLockState(
        authContext: authContext,
        isEnabled: { isEnabled },
        lockDelay: { delay }
    )
    return (state, authContext)
}

// MARK: - Init

@MainActor
@Suite(.serialized)
struct AppLockStateInitTests {
    @Test("Starts locked when enabled")
    func startsLockedWhenEnabled() {
        let (state, _) = makeLockState(isEnabled: true)
        #expect(state.isLocked == true)
    }

    @Test("Starts unlocked when disabled")
    func startsUnlockedWhenDisabled() {
        let (state, _) = makeLockState(isEnabled: false)
        #expect(state.isLocked == false)
    }
}

// MARK: - Lock timing

@MainActor
@Suite(.serialized)
struct AppLockStateTimingTests {
    @Test("Immediate delay locks on return from background")
    func immediateDelayLocks() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 0 }
        )

        // Unlock first so we can test the re-lock path
        await state.attemptUnlock()
        #expect(state.isLocked == false)

        // Simulate background then return after 1 second (>= 0 delay)
        state.backgroundedAt = Date.now.addingTimeInterval(-1)
        state.handleScenePhase(.active)

        #expect(state.isLocked == true)
    }

    @Test("Returns within delay — stays unlocked")
    func withinDelayStaysUnlocked() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 60 }
        )

        // Unlock first
        await state.attemptUnlock()
        #expect(state.isLocked == false)

        // Simulate background then return within delay
        state.backgroundedAt = Date.now.addingTimeInterval(-30)
        state.handleScenePhase(.active)

        // Should stay unlocked (30s < 60s delay)
        #expect(state.isLocked == false)
    }

    @Test("Returns past delay — locks")
    func pastDelayLocks() {
        let auth = StubAuthContext()
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 60 }
        )

        // Simulate background then return past delay
        state.backgroundedAt = Date.now.addingTimeInterval(-61)
        state.handleScenePhase(.active)

        // Should lock (61s >= 60s delay)
        #expect(state.isLocked == true)
    }
}

// MARK: - Authentication flow

@MainActor
@Suite(.serialized)
struct AppLockStateAuthTests {
    @Test("Successful biometric unlocks")
    func successfulBiometricUnlocks() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 0 }
        )

        #expect(state.isLocked == true)
        await state.attemptUnlock()
        #expect(state.isLocked == false)
    }

    @Test("Failed biometric stays locked")
    func failedBiometricStaysLocked() async {
        let auth = StubAuthContext()
        auth.evaluateResult = false
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 0 }
        )

        #expect(state.isLocked == true)
        await state.attemptUnlock()
        #expect(state.isLocked == true)
    }

    @Test("isAuthenticating prevents concurrent unlock attempts")
    func concurrentAuthPrevented() async {
        let slowAuth = SlowAuthContext()
        let state = AppLockState(
            authContext: slowAuth,
            isEnabled: { true },
            lockDelay: { 0 }
        )

        // Start first unlock (will be slow)
        let firstUnlock = Task { await state.attemptUnlock() }

        // Give it a moment to enter the authenticating state
        try? await Task.sleep(for: .milliseconds(50))

        // Start second unlock — should be blocked by isAuthenticating guard
        await state.attemptUnlock()

        // Let the first one finish
        await firstUnlock.value

        // Should have only evaluated once despite two attempts
        #expect(slowAuth.evaluateCallCount == 1)
    }

    @Test("Uses deviceOwnerAuthentication policy")
    func usesCorrectPolicy() async {
        let policyTracker = PolicyTrackingAuthContext()
        let state = AppLockState(
            authContext: policyTracker,
            isEnabled: { true },
            lockDelay: { 0 }
        )

        await state.attemptUnlock()

        #expect(policyTracker.lastPolicy == .deviceOwnerAuthentication)
    }
}

// MARK: - Scene phase transitions

@MainActor
@Suite(.serialized)
struct AppLockStateScenePhaseTests {
    @Test("Background records timestamp")
    func backgroundRecordsTimestamp() {
        let (state, _) = makeLockState(isEnabled: true)
        #expect(state.backgroundedAt == nil)

        state.handleScenePhase(.background)
        #expect(state.backgroundedAt != nil)
    }

    @Test("Active within delay does not lock")
    func activeWithinDelayDoesNotLock() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 60 }
        )

        // Unlock first
        await state.attemptUnlock()
        #expect(state.isLocked == false)

        // Simulate short background
        state.backgroundedAt = Date.now.addingTimeInterval(-10)
        state.handleScenePhase(.active)

        #expect(state.isLocked == false)
    }

    @Test("Active past delay locks")
    func activePastDelayLocks() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 60 }
        )

        // Unlock first
        await state.attemptUnlock()
        #expect(state.isLocked == false)

        // Simulate long background
        state.backgroundedAt = Date.now.addingTimeInterval(-120)
        state.handleScenePhase(.active)

        #expect(state.isLocked == true)
    }

    @Test("Active clears backgroundedAt when within delay")
    func activeClearsTimestamp() async {
        let auth = StubAuthContext()
        auth.evaluateResult = true
        let state = AppLockState(
            authContext: auth,
            isEnabled: { true },
            lockDelay: { 60 }
        )

        await state.attemptUnlock()
        state.backgroundedAt = Date.now.addingTimeInterval(-5)
        state.handleScenePhase(.active)

        #expect(state.backgroundedAt == nil)
    }

    @Test("Disabled clears lock state")
    func disabledClearsLockState() {
        let state = AppLockState(
            authContext: StubAuthContext(),
            isEnabled: { false },
            lockDelay: { 0 }
        )

        state.handleScenePhase(.active)
        #expect(state.isLocked == false)
    }
}
