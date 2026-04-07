import Foundation

struct GeneratedCode {
    let code: String
    let type: OTPType
    let counter: Int?
    let windowStart: Date?
    let windowEnd: Date?
    let remainingSeconds: TimeInterval?
    let progress: Double?
}

enum CodeGenerationError: Error, LocalizedError {
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed: "Failed to generate code"
        }
    }
}
