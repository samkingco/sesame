import ActivityKit
import Foundation
import os
import UIKit

@MainActor
enum LiveActivityService {
    typealias State = CopiedCodeAttributes.ContentState

    static let enabledKey = UserDefaultsKey.liveActivityEnabled

    private static let staleGracePeriod: TimeInterval = 1

    private static var refreshTask: Task<Void, Never>?
    private static var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private static var lockObserver: (any NSObjectProtocol)?
    private static let logger = Logger(subsystem: Logger.appSubsystem, category: "LiveActivityService")

    private(set) static var activeAccountId: UUID?

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var areSystemActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    /// Keeps the activity current with `makeState` until `dismissAt`, the device locks, or the
    /// app runs out of background time, whichever is first. A suspended app can't end it later.
    static func start(
        accountId: UUID,
        attributes: CopiedCodeAttributes,
        dismissAt: Date?,
        makeState: @escaping @MainActor (Date) -> State?
    ) {
        guard isEnabled, areSystemActivitiesEnabled, let state = makeState(.now) else { return }

        end()

        let activity: Activity<CopiedCodeAttributes>
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content(for: state, dismissAt: dismissAt),
                pushType: nil
            )
        } catch {
            logger.error("Failed to start live activity: \(error)")
            return
        }

        activeAccountId = accountId
        beginBackgroundTask()
        observeDeviceLock()

        refreshTask = Task {
            await keepCurrent(activity, from: state, dismissAt: dismissAt, makeState: makeState)
        }
    }

    /// Also ends activities left over from a previous launch.
    static func end() {
        refreshTask?.cancel()
        refreshTask = nil
        activeAccountId = nil
        stopObservingDeviceLock()

        let activities = Activity<CopiedCodeAttributes>.activities
        let task = backgroundTask
        backgroundTask = .invalid

        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
            }
        }
    }

    static func nextRefresh(after state: State, dismissAt: Date?, now: Date = .now) -> Date {
        let next = CodeColorState.nextChange(after: now, expiresAt: state.expiresAt)
        guard let dismissAt else { return next }
        return min(next, dismissAt)
    }

    /// If the app is suspended before it can update or end the activity, the
    /// widget hides the code from this date.
    static func staleDate(for state: State, dismissAt: Date?) -> Date {
        min(state.expiresAt, dismissAt ?? .distantFuture)
            .addingTimeInterval(staleGracePeriod)
    }

    // MARK: - Private

    private static func keepCurrent(
        _ activity: Activity<CopiedCodeAttributes>,
        from initial: State,
        dismissAt: Date?,
        makeState: @MainActor (Date) -> State?
    ) async {
        var state = initial
        while true {
            let wake = nextRefresh(after: state, dismissAt: dismissAt)
            try? await Task.sleep(for: .seconds(max(0, wake.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }

            let isDismissed = dismissAt.map { wake >= $0 } ?? false
            guard !isDismissed, activity.activityState == .active,
                  let next = makeState(max(.now, wake))
            else {
                end()
                return
            }

            state = next
            await activity.update(content(for: state, dismissAt: dismissAt))
        }
    }

    private static func content(for state: State, dismissAt: Date?) -> ActivityContent<State> {
        ActivityContent(state: state, staleDate: staleDate(for: state, dismissAt: dismissAt))
    }

    private static func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Copied code Live Activity") {
            end()
        }
    }

    private static func observeDeviceLock() {
        guard lockObserver == nil else { return }
        lockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main,
            using: { _ in MainActor.assumeIsolated { end() } }
        )
    }

    private static func stopObservingDeviceLock() {
        guard let lockObserver else { return }
        NotificationCenter.default.removeObserver(lockObserver)
        self.lockObserver = nil
    }
}
