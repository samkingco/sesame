import Foundation

/// Single source of time for the app. All views read `clock.now`.
///
/// - **Production**: real `Date.now`, ticks every 1s
/// - **Screenshots**: frozen at `demoDate`, never ticks
/// - **UI tests**: starts at `demoDate`, ticks every 1s with virtual elapsed time
/// - **Video**: driven by `VideoDateControl`, ticks every 0.1s
///
/// Control methods (`setDate`, `pause`, `resume`) are no-ops in production.
@MainActor @Observable
final class AppClock {
    private(set) var now: Date

    /// The starting date for demo modes. Use instead of accessing
    /// `LaunchMode.demoDate` directly from views.
    let referenceDate: Date

    private var timer: Timer?
    private var isPaused = false
    private let launchRealDate: Date

    init() {
        let realNow = Date.now
        launchRealDate = realNow

        #if DEMO_ENABLED
            if LaunchMode.isDemoData {
                referenceDate = LaunchMode.demoDate
                now = LaunchMode.demoDate
            } else {
                referenceDate = realNow
                now = realNow
            }
        #else
            referenceDate = realNow
            now = realNow
        #endif

        startTimer()
    }

    // MARK: - Control API (no-ops in production)

    func setDate(_ date: Date) {
        #if DEMO_ENABLED
            guard LaunchMode.isDemoData else { return }
            now = date
        #endif
    }

    func pause() {
        #if DEMO_ENABLED
            guard LaunchMode.isDemoData else { return }
            isPaused = true
        #endif
    }

    func resume() {
        #if DEMO_ENABLED
            guard LaunchMode.isDemoData else { return }
            isPaused = false
        #endif
    }

    // MARK: - Timer

    private func startTimer() {
        #if DEMO_ENABLED
            if LaunchMode.demo == .screenshots { return }
        #endif
        scheduleTimer(interval: 1)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard !isPaused else { return }

        #if DEMO_ENABLED
            switch LaunchMode.demo {
            case .video:
                now = VideoDateControl.shared.currentDate
            case .uiTests:
                let elapsed = Date.now.timeIntervalSince(launchRealDate)
                now = referenceDate.addingTimeInterval(elapsed)
            case .screenshots:
                break
            case nil:
                now = Date.now
            }
        #else
            now = Date.now
        #endif
    }

    deinit {
        // Timer is scheduled on the main run loop and will be
        // deallocated along with this object.
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }
}
