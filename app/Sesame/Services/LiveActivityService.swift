import ActivityKit
import Foundation
import os

@MainActor
enum LiveActivityService {
    static let enabledKey = UserDefaultsKey.liveActivityEnabled

    private static var currentActivity: Activity<CopiedCodeAttributes>?
    private static var dismissTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: Logger.appSubsystem, category: "LiveActivityService")

    private(set) static var activeAccountId: UUID?

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var areSystemActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    static func start(
        accountId: UUID,
        code: String,
        nextCode: String?,
        expiresAt: Date,
        issuer: String,
        dismissAfter: TimeInterval?
    ) {
        guard isEnabled, areSystemActivitiesEnabled else { return }

        endCurrent()

        let attributes = CopiedCodeAttributes(issuer: issuer)
        let state = CopiedCodeAttributes.ContentState(
            code: code,
            nextCode: nextCode,
            expiresAt: expiresAt
        )
        let content = ActivityContent(state: state, staleDate: expiresAt)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeAccountId = accountId
        } catch {
            logger.error("Failed to start live activity: \(error)")
            return
        }

        if let dismissAfter, dismissAfter > 0 {
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(dismissAfter))
                guard !Task.isCancelled else { return }
                endCurrent()
            }
        }
    }

    static func update(code: String, nextCode: String?, expiresAt: Date) {
        guard let activity = currentActivity else { return }

        let state = CopiedCodeAttributes.ContentState(
            code: code,
            nextCode: nextCode,
            expiresAt: expiresAt
        )
        let content = ActivityContent(state: state, staleDate: expiresAt)

        Task {
            await activity.update(content)
        }
    }

    static func end() {
        endCurrent()
    }

    // MARK: - Private

    private static func endCurrent() {
        dismissTask?.cancel()
        dismissTask = nil
        activeAccountId = nil

        guard let activity = currentActivity else { return }
        currentActivity = nil

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
