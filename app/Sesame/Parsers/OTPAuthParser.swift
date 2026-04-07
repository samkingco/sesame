import Foundation

struct ParsedOTPAccount: Hashable {
    var type: OTPType
    var issuer: String?
    var name: String
    var secret: String
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int
    var counter: Int
    var website: String?
}

enum OTPAuthParseError: Error, LocalizedError, Equatable {
    case invalidFormat
    case invalidProtocol
    case invalidOTPType(String)
    case missingLabel
    case missingSecret
    case invalidSecret
    case invalidDigits(Int)
    case invalidPeriod(Int)
    case invalidCounter(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "Invalid otpauth URI format"
        case .invalidProtocol: "Invalid protocol — expected otpauth://"
        case let .invalidOTPType(t): "Invalid OTP type: \(t)"
        case .missingLabel: "Missing label"
        case .missingSecret: "Missing secret parameter"
        case .invalidSecret: "Invalid base32 secret"
        case let .invalidDigits(d): "Invalid digits: \(d) — must be 6-8"
        case let .invalidPeriod(p): "Invalid period: \(p) — must be > 0"
        case let .invalidCounter(c): "Invalid counter: \(c) — must be >= 0"
        }
    }
}

enum OTPAuthParser {
    // MARK: - Public

    /// Parse an otpauth:// URI or raw base32 secret string.
    static func parse(_ input: String) throws -> ParsedOTPAccount {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("://") {
            return try parseURI(trimmed)
        }

        return try parseRawSecret(trimmed)
    }

    // MARK: - URI parsing

    private static func parseURI(_ uri: String) throws -> ParsedOTPAccount {
        guard let components = URLComponents(string: uri) else {
            throw OTPAuthParseError.invalidFormat
        }

        guard components.scheme?.lowercased() == "otpauth" else {
            throw OTPAuthParseError.invalidProtocol
        }

        let host = components.host ?? ""
        guard let type = OTPType(rawValue: host.lowercased()) else {
            throw OTPAuthParseError.invalidOTPType(host)
        }

        // Label from path (strip leading /)
        let rawPath = components.path.hasPrefix("/")
            ? String(components.path.dropFirst())
            : components.path
        let label = rawPath.removingPercentEncoding ?? rawPath

        guard !label.isEmpty else {
            throw OTPAuthParseError.missingLabel
        }

        // Split label into issuer:name
        var issuer: String?
        let name: String

        if let colonIdx = label.firstIndex(of: ":") {
            issuer = String(label[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        } else {
            name = label.trimmingCharacters(in: .whitespaces)
        }

        // Query parameters
        let params = paramDict(from: components.queryItems)

        // Issuer: parameter wins over label prefix
        if let paramIssuer = params["issuer"], !paramIssuer.isEmpty {
            issuer = paramIssuer
        }

        // Secret (required)
        guard let secret = params["secret"], !secret.isEmpty else {
            throw OTPAuthParseError.missingSecret
        }

        // Algorithm
        let algorithm: OTPAlgorithm = if let raw = params["algorithm"] {
            OTPAlgorithm(rawValue: raw.lowercased()) ?? .sha1
        } else {
            .sha1
        }

        // Digits
        let digits: Int
        if let raw = params["digits"] {
            guard let d = Int(raw), (6 ... 8).contains(d) else {
                throw OTPAuthParseError.invalidDigits(Int(raw) ?? 0)
            }
            digits = d
        } else {
            digits = 6
        }

        // Period
        let period: Int
        if let raw = params["period"], let p = Int(raw) {
            guard p > 0 else {
                throw OTPAuthParseError.invalidPeriod(p)
            }
            period = p
        } else {
            period = 30
        }

        // Counter
        let counter: Int
        if let raw = params["counter"], let c = Int(raw) {
            guard c >= 0 else {
                throw OTPAuthParseError.invalidCounter(c)
            }
            counter = c
        } else {
            counter = 0
        }

        let website = issuer.flatMap { IssuerDomainMap.domain(for: $0) }

        return ParsedOTPAccount(
            type: type,
            issuer: issuer,
            name: name,
            secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter,
            website: website
        )
    }

    // MARK: - Raw base32 secret

    private static func parseRawSecret(_ input: String) throws -> ParsedOTPAccount {
        let cleaned = input
            .replacing(" ", with: "")
            .uppercased()

        guard isValidBase32(cleaned) else {
            throw OTPAuthParseError.invalidSecret
        }

        guard cleaned.count >= 16 else {
            throw OTPAuthParseError.invalidSecret
        }

        return ParsedOTPAccount(
            type: .totp,
            issuer: nil,
            name: "Account",
            secret: cleaned,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            counter: 0
        )
    }

    // MARK: - Helpers

    private static func paramDict(from items: [URLQueryItem]?) -> [String: String] {
        guard let items else { return [:] }
        return Dictionary(items.compactMap { item in
            item.value.map { (item.name, $0) }
        }, uniquingKeysWith: { _, last in last })
    }

    private static func isValidBase32(_ string: String) -> Bool {
        let base32 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=")
        return !string.isEmpty
            && string.unicodeScalars.allSatisfy { base32.contains($0) }
    }
}
