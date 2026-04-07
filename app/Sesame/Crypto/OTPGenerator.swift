// HMAC-based OTP generation per RFC 4226 (HOTP) and RFC 6238 (TOTP)
// Clean-room implementation for Sesame using CryptoKit

import CryptoKit
import Foundation

enum OTPGenerator {
    /// RFC 4226: Generate HOTP from secret and counter
    static func generate(
        secret: Data,
        algorithm: OTPAlgorithm,
        counter: UInt64,
        digits: Int
    ) -> String? {
        guard (6 ... 8).contains(digits) else { return nil }
        guard !secret.isEmpty else { return nil }

        let key = SymmetricKey(data: secret)
        let message = withUnsafeBytes(of: counter.bigEndian) { Data($0) }

        let hmac = switch algorithm {
        case .sha1:
            Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256:
            Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512:
            Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }

        // Dynamic truncation (RFC 4226 Section 5.4)
        let offset = Int(hmac[hmac.count - 1] & 0x0F)
        let byte0 = UInt32(hmac[offset] & 0x7F) << 24
        let byte1 = UInt32(hmac[offset + 1]) << 16
        let byte2 = UInt32(hmac[offset + 2]) << 8
        let byte3 = UInt32(hmac[offset + 3])
        let truncated = byte0 | byte1 | byte2 | byte3

        let modulo = UInt32(pow(10.0, Double(digits)))
        let code = truncated % modulo

        return String(format: "%0\(digits)d", code)
    }

    /// RFC 6238: Generate TOTP from secret and timestamp
    static func generate(
        secret: Data,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int,
        timestamp: Date
    ) -> String? {
        guard period > 0 else { return nil }
        let seconds = Int(floor(timestamp.timeIntervalSince1970))
        guard seconds >= 0 else { return nil }
        let counter = UInt64(seconds / period)
        return generate(secret: secret, algorithm: algorithm, counter: counter, digits: digits)
    }
}
