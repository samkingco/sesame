import SwiftUI

// MARK: - Code color state

enum CodeColorState: Codable {
    case empty
    case normal
    case warning
    case critical
    case copied

    static let warningThreshold = 10
    static let criticalThreshold = 5

    init(code: String?, isCopied: Bool, type: OTPType, remainingSeconds: Int) {
        guard code != nil else {
            self = .empty
            return
        }
        if isCopied {
            self = .copied
            return
        }
        guard type == .totp else {
            self = .normal
            return
        }
        if remainingSeconds <= Self.criticalThreshold {
            self = .critical
        } else if remainingSeconds <= Self.warningThreshold {
            self = .warning
        } else {
            self = .normal
        }
    }

    /// Next time a TOTP code's state changes on its way to `expiresAt`.
    static func nextChange(after date: Date, expiresAt: Date) -> Date {
        [warningThreshold, criticalThreshold, 0]
            .map { expiresAt.addingTimeInterval(-Double($0)) }
            .first { $0 > date } ?? expiresAt
    }

    var color: AnyShapeStyle {
        switch self {
        case .empty: AnyShapeStyle(.tertiary)
        case .copied: AnyShapeStyle(.green)
        case .critical: AnyShapeStyle(.red)
        case .warning: AnyShapeStyle(.orange)
        case .normal: AnyShapeStyle(.primary)
        }
    }
}

// MARK: - Code formatting

enum CodeFormatting {
    static func formatted(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "••• •••" }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(code[..<mid]) + " " + String(code[mid...])
    }

    static func spoken(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "" }
        return code.map(String.init).joined(separator: " ")
    }
}

// MARK: - Animation constants

enum CodeAnimation {
    static let duration: Double = 0.3
    static let copiedResetDelay: Double = 2
}
