import Foundation

enum GoogleAuthMigrationParseError: Error, LocalizedError, Equatable {
    case invalidScheme
    case missingData
    case invalidBase64
    case malformedProtobuf

    var errorDescription: String? {
        switch self {
        case .invalidScheme: "Invalid URI — expected otpauth-migration://"
        case .missingData: "Missing data parameter"
        case .invalidBase64: "Invalid base64 data"
        case .malformedProtobuf: "Malformed protobuf data"
        }
    }
}

private struct RawOtpFields {
    var secret = Data()
    var name = ""
    var issuer: String?
    var algorithm: UInt64 = 0
    var digits: UInt64 = 0
    var type: UInt64 = 0
    var counter: UInt64 = 0
}

enum GoogleAuthMigrationParser {
    static func parse(_ uri: String) throws -> [ParsedOTPAccount] {
        guard let components = URLComponents(string: uri),
              components.scheme?.lowercased() == "otpauth-migration"
        else {
            throw GoogleAuthMigrationParseError.invalidScheme
        }

        let params = Dictionary(
            (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            },
            uniquingKeysWith: { _, last in last }
        )

        guard let dataString = params["data"], !dataString.isEmpty else {
            throw GoogleAuthMigrationParseError.missingData
        }

        guard let data = Data(base64Encoded: dataString) else {
            throw GoogleAuthMigrationParseError.invalidBase64
        }

        return try decodeMigrationPayload(data)
    }

    // MARK: - Payload decoding

    private static func decodeMigrationPayload(_ data: Data) throws -> [ParsedOTPAccount] {
        var accounts: [ParsedOTPAccount] = []
        var offset = data.startIndex

        while offset < data.endIndex {
            let (fieldNumber, wireType) = try readTag(data, offset: &offset)

            switch (fieldNumber, wireType) {
            case (1, 2):
                try accounts.append(decodeOtpParameters(readBytes(data, offset: &offset)))
            case (_, 0):
                _ = try readVarint(data, offset: &offset)
            case (_, 2):
                try skipBytes(data, offset: &offset)
            default:
                throw GoogleAuthMigrationParseError.malformedProtobuf
            }
        }

        return accounts
    }

    private static func decodeOtpParameters(_ data: Data) throws -> ParsedOTPAccount {
        var fields = RawOtpFields()
        var offset = data.startIndex

        while offset < data.endIndex {
            let (fieldNumber, wireType) = try readTag(data, offset: &offset)

            switch (fieldNumber, wireType) {
            case (1, 2): fields.secret = try readBytes(data, offset: &offset)
            case (2, 2): fields.name = try readString(data, offset: &offset)
            case (3, 2):
                let value = try readString(data, offset: &offset)
                fields.issuer = value.isEmpty ? nil : value
            case (4, 0): fields.algorithm = try readVarint(data, offset: &offset)
            case (5, 0): fields.digits = try readVarint(data, offset: &offset)
            case (6, 0): fields.type = try readVarint(data, offset: &offset)
            case (7, 0): fields.counter = try readVarint(data, offset: &offset)
            case (_, 0): _ = try readVarint(data, offset: &offset)
            case (_, 2): try skipBytes(data, offset: &offset)
            default: throw GoogleAuthMigrationParseError.malformedProtobuf
            }
        }

        return mapToAccount(fields)
    }

    private static func mapToAccount(_ fields: RawOtpFields) -> ParsedOTPAccount {
        let algorithm: OTPAlgorithm = switch fields.algorithm {
        case 2: .sha256
        case 3: .sha512
        default: .sha1
        }

        let digits = switch fields.digits {
        case 2: 8
        default: 6
        }

        let type: OTPType = switch fields.type {
        case 1: .hotp
        default: .totp
        }

        // Split "issuer:name" format in the name field (same as otpauth:// labels)
        var issuer = fields.issuer
        var name = fields.name

        if let colonIdx = name.firstIndex(of: ":") {
            let prefix = String(name[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let suffix = String(name[name.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            if issuer == nil {
                // No issuer set — use the prefix
                issuer = prefix
                name = suffix
            } else if prefix.caseInsensitiveCompare(issuer!) == .orderedSame {
                // Prefix matches existing issuer — strip the redundant prefix
                name = suffix
            }
            // Otherwise keep name as-is (prefix differs from issuer)
        }

        let base32Secret = Base32.encode(fields.secret)
        let website = issuer.flatMap { IssuerDomainMap.domain(for: $0) }

        return ParsedOTPAccount(
            type: type,
            issuer: issuer,
            name: name,
            secret: base32Secret,
            algorithm: algorithm,
            digits: digits,
            period: 30,
            counter: Int(fields.counter),
            website: website
        )
    }

    // MARK: - Protobuf primitives

    private static func readTag(
        _ data: Data,
        offset: inout Int
    ) throws -> (fieldNumber: Int, wireType: Int) {
        let tag = try readVarint(data, offset: &offset)
        return (fieldNumber: Int(tag >> 3), wireType: Int(tag & 0x07))
    }

    private static func readVarint(_ data: Data, offset: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        var shift = 0

        while offset < data.endIndex {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift > 63 {
                throw GoogleAuthMigrationParseError.malformedProtobuf
            }
        }

        throw GoogleAuthMigrationParseError.malformedProtobuf
    }

    private static func readBytes(_ data: Data, offset: inout Int) throws -> Data {
        let length = try readVarint(data, offset: &offset)
        let end = offset + Int(length)
        guard end <= data.endIndex else {
            throw GoogleAuthMigrationParseError.malformedProtobuf
        }
        let value = Data(data[offset ..< end])
        offset = end
        return value
    }

    private static func skipBytes(_ data: Data, offset: inout Int) throws {
        let length = try readVarint(data, offset: &offset)
        offset += Int(length)
        guard offset <= data.endIndex else {
            throw GoogleAuthMigrationParseError.malformedProtobuf
        }
    }

    private static func readString(_ data: Data, offset: inout Int) throws -> String {
        let length = try readVarint(data, offset: &offset)
        let end = offset + Int(length)
        guard end <= data.endIndex else {
            throw GoogleAuthMigrationParseError.malformedProtobuf
        }
        let value = String(data: Data(data[offset ..< end]), encoding: .utf8) ?? ""
        offset = end
        return value
    }
}
