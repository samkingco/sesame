import Foundation

enum TimeWindow {
    static func windowStart(for timestamp: Date, period: Int) -> Date {
        precondition(period > 0, "period must be positive")
        let seconds = timestamp.timeIntervalSince1970
        let windowNumber = floor(seconds / Double(period))
        return Date(timeIntervalSince1970: windowNumber * Double(period))
    }

    static func windowEnd(for timestamp: Date, period: Int) -> Date {
        let start = windowStart(for: timestamp, period: period)
        return start.addingTimeInterval(Double(period))
    }

    static func windowProgress(for timestamp: Date, period: Int) -> Double {
        precondition(period > 0, "period must be positive")
        let seconds = timestamp.timeIntervalSince1970
        let elapsed = seconds.truncatingRemainder(dividingBy: Double(period))
        return elapsed / Double(period)
    }

    static func remainingSeconds(for timestamp: Date, period: Int) -> TimeInterval {
        precondition(period > 0, "period must be positive")
        let seconds = timestamp.timeIntervalSince1970
        let elapsed = seconds.truncatingRemainder(dividingBy: Double(period))
        return Double(period) - elapsed
    }
}
