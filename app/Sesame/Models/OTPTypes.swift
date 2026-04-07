import Foundation

enum OTPType: String, Codable, CaseIterable {
    case totp
    case hotp
}

enum OTPAlgorithm: String, Codable, CaseIterable {
    case sha1
    case sha256
    case sha512
}
