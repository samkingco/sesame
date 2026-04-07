import Foundation

enum AddAccountPath: Hashable {
    case manualEntry
    case confirmation(ParsedOTPAccount)
    case saved(Account)
    case importReview([ParsedOTPAccount])
}
