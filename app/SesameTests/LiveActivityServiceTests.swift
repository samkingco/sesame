import Foundation
@testable import Sesame
import Testing

@MainActor
struct LiveActivityServiceTests {
    private let testSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    private let windowStart = Date(timeIntervalSince1970: 1_700_000_010)
    private var expiresAt: Date {
        windowStart.addingTimeInterval(30)
    }

    private func makeState() -> CopiedCodeAttributes.ContentState {
        CopiedCodeAttributes.ContentState(code: "123456", colorState: .normal, expiresAt: expiresAt)
    }

    // MARK: - Refresh schedule

    @Test("Refreshes at the warning threshold, then critical, then expiry")
    func refreshesAtColorThresholds() {
        let warning = expiresAt.addingTimeInterval(-Double(CodeColorState.warningThreshold))
        let critical = expiresAt.addingTimeInterval(-Double(CodeColorState.criticalThreshold))

        #expect(CodeColorState.nextChange(after: windowStart, expiresAt: expiresAt) == warning)
        #expect(CodeColorState.nextChange(after: warning, expiresAt: expiresAt) == critical)
        #expect(CodeColorState.nextChange(after: critical, expiresAt: expiresAt) == expiresAt)
    }

    @Test("Refreshes at expiry when running late")
    func refreshesAtExpiryWhenLate() {
        let late = expiresAt.addingTimeInterval(1)
        #expect(CodeColorState.nextChange(after: late, expiresAt: expiresAt) == expiresAt)
    }

    @Test("Refreshes at dismissal when that comes first")
    func refreshesAtDismissal() {
        let dismissAt = windowStart.addingTimeInterval(3)
        let wake = LiveActivityService.nextRefresh(after: makeState(), dismissAt: dismissAt, now: windowStart)
        #expect(wake == dismissAt)
    }

    @Test("Ignores dismissal after the next change")
    func ignoresLaterDismissal() {
        let dismissAt = expiresAt.addingTimeInterval(60)
        let wake = LiveActivityService.nextRefresh(after: makeState(), dismissAt: dismissAt, now: windowStart)
        #expect(wake == expiresAt.addingTimeInterval(-Double(CodeColorState.warningThreshold)))
    }

    // MARK: - State

    @Test("State matches the app's color for the time remaining")
    func stateMatchesAppColor() throws {
        func colorState(secondsBeforeExpiry: TimeInterval) throws -> CodeColorState {
            let state = try #require(CodeService.liveActivityState(
                secret: testSecret,
                algorithm: .sha1,
                digits: 6,
                period: 30,
                at: expiresAt.addingTimeInterval(-secondsBeforeExpiry)
            ))
            #expect(state.expiresAt == expiresAt)
            return state.colorState
        }

        #expect(try colorState(secondsBeforeExpiry: 20) == .normal)
        #expect(try colorState(secondsBeforeExpiry: 10) == .warning)
        #expect(try colorState(secondsBeforeExpiry: 5) == .critical)
    }

    @Test("No state for an invalid secret")
    func noStateForInvalidSecret() {
        let state = CodeService.liveActivityState(
            secret: "not base32!",
            algorithm: .sha1,
            digits: 6,
            period: 30,
            at: windowStart
        )
        #expect(state == nil)
    }

    // MARK: - Stale date

    @Test("Goes stale just after the code expires")
    func staleAfterExpiry() {
        let stale = LiveActivityService.staleDate(for: makeState(), dismissAt: nil)
        #expect(stale > expiresAt)
        #expect(stale.timeIntervalSince(expiresAt) <= 1)
    }

    @Test("Goes stale at dismissal when that comes first")
    func staleAtDismissal() {
        let dismissAt = windowStart.addingTimeInterval(10)
        let stale = LiveActivityService.staleDate(for: makeState(), dismissAt: dismissAt)
        #expect(stale > dismissAt)
        #expect(stale < expiresAt)
    }
}
