import Foundation
@testable import Sesame
import Testing

struct TimeWindowTests {
    // MARK: - Window Start

    @Test func windowStartAtExactBoundary() {
        let timestamp = Date(timeIntervalSince1970: 90)
        let start = TimeWindow.windowStart(for: timestamp, period: 30)
        #expect(start.timeIntervalSince1970 == 90)
    }

    @Test func windowStartMidPeriod() {
        let timestamp = Date(timeIntervalSince1970: 105)
        let start = TimeWindow.windowStart(for: timestamp, period: 30)
        #expect(start.timeIntervalSince1970 == 90)
    }

    // MARK: - Window End

    @Test func windowEndAtExactBoundary() {
        let timestamp = Date(timeIntervalSince1970: 90)
        let end = TimeWindow.windowEnd(for: timestamp, period: 30)
        #expect(end.timeIntervalSince1970 == 120)
    }

    @Test func windowEndMidPeriod() {
        let timestamp = Date(timeIntervalSince1970: 105)
        let end = TimeWindow.windowEnd(for: timestamp, period: 30)
        #expect(end.timeIntervalSince1970 == 120)
    }

    // MARK: - Progress

    @Test func progressAtWindowStart() {
        let timestamp = Date(timeIntervalSince1970: 90)
        let progress = TimeWindow.windowProgress(for: timestamp, period: 30)
        #expect(progress == 0.0)
    }

    @Test func progressMidWindow() {
        let timestamp = Date(timeIntervalSince1970: 105)
        let progress = TimeWindow.windowProgress(for: timestamp, period: 30)
        #expect(progress == 0.5)
    }

    @Test func progressNearWindowEnd() {
        let timestamp = Date(timeIntervalSince1970: 119)
        let progress = TimeWindow.windowProgress(for: timestamp, period: 30)
        #expect(progress > 0.9)
        #expect(progress < 1.0)
    }

    // MARK: - Remaining Seconds

    @Test func remainingSecondsAtStart() {
        let timestamp = Date(timeIntervalSince1970: 90)
        let remaining = TimeWindow.remainingSeconds(for: timestamp, period: 30)
        #expect(remaining == 30.0)
    }

    @Test func remainingSecondsMidWindow() {
        let timestamp = Date(timeIntervalSince1970: 105)
        let remaining = TimeWindow.remainingSeconds(for: timestamp, period: 30)
        #expect(remaining == 15.0)
    }

    @Test func remainingSecondsDecreasesOverTime() {
        let early = Date(timeIntervalSince1970: 91)
        let late = Date(timeIntervalSince1970: 100)
        let earlyRemaining = TimeWindow.remainingSeconds(for: early, period: 30)
        let lateRemaining = TimeWindow.remainingSeconds(for: late, period: 30)
        #expect(earlyRemaining > lateRemaining)
    }

    // MARK: - Custom Period

    @Test func customPeriod60() {
        let timestamp = Date(timeIntervalSince1970: 75)
        let start = TimeWindow.windowStart(for: timestamp, period: 60)
        let end = TimeWindow.windowEnd(for: timestamp, period: 60)
        #expect(start.timeIntervalSince1970 == 60)
        #expect(end.timeIntervalSince1970 == 120)
    }
}
