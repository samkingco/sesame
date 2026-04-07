import Foundation

enum TOTPGenerator {
    struct Result {
        let code: String
        let windowStart: Date
        let windowEnd: Date
        let remainingSeconds: TimeInterval
        let progress: Double
    }

    static func generate(
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        timestamp: Date = .now
    ) -> Result? {
        guard let secretData = Base32.decode(secret) else { return nil }

        guard let code = OTPGenerator.generate(
            secret: secretData,
            algorithm: algorithm,
            digits: digits,
            period: period,
            timestamp: timestamp
        ) else { return nil }

        return Result(
            code: code,
            windowStart: TimeWindow.windowStart(for: timestamp, period: period),
            windowEnd: TimeWindow.windowEnd(for: timestamp, period: period),
            remainingSeconds: TimeWindow.remainingSeconds(for: timestamp, period: period),
            progress: TimeWindow.windowProgress(for: timestamp, period: period)
        )
    }
}
