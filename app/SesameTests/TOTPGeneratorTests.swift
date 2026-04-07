import Foundation
@testable import Sesame
import Testing

struct TOTPGeneratorTests {
    // RFC 6238 test secrets (base32-encoded ASCII "1234567890..." at required lengths)
    let sha1Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    let sha256Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA===="
    // swiftlint:disable:next line_length
    let sha512Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA="

    // MARK: - RFC 6238 Test Vectors (8-digit, 30s period)

    @Test func rfcSHA1_time59() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code == "94287082")
    }

    @Test func rfcSHA256_time59() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code == "46119246")
    }

    @Test func rfcSHA512_time59() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code == "90693936")
    }

    @Test func rfcSHA1_time1111111109() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_109)
        )
        #expect(result?.code == "07081804")
    }

    @Test func rfcSHA256_time1111111109() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_109)
        )
        #expect(result?.code == "68084774")
    }

    @Test func rfcSHA512_time1111111109() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_109)
        )
        #expect(result?.code == "25091201")
    }

    @Test func rfcSHA1_time1234567890() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_234_567_890)
        )
        #expect(result?.code == "89005924")
    }

    @Test func rfcSHA256_time1234567890() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_234_567_890)
        )
        #expect(result?.code == "91819424")
    }

    @Test func rfcSHA512_time1234567890() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_234_567_890)
        )
        #expect(result?.code == "93441116")
    }

    @Test func rfcSHA1_time1111111111() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_111)
        )
        #expect(result?.code == "14050471")
    }

    @Test func rfcSHA256_time1111111111() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_111)
        )
        #expect(result?.code == "67062674")
    }

    @Test func rfcSHA512_time1111111111() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 1_111_111_111)
        )
        #expect(result?.code == "99943326")
    }

    @Test func rfcSHA1_time2000000000() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 2_000_000_000)
        )
        #expect(result?.code == "69279037")
    }

    @Test func rfcSHA256_time2000000000() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 2_000_000_000)
        )
        #expect(result?.code == "90698825")
    }

    @Test func rfcSHA512_time2000000000() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 2_000_000_000)
        )
        #expect(result?.code == "38618901")
    }

    @Test func rfcSHA1_time20000000000() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, algorithm: .sha1, digits: 8,
            timestamp: Date(timeIntervalSince1970: 20_000_000_000)
        )
        #expect(result?.code == "65353130")
    }

    @Test func rfcSHA256_time20000000000() {
        let result = TOTPGenerator.generate(
            secret: sha256Secret, algorithm: .sha256, digits: 8,
            timestamp: Date(timeIntervalSince1970: 20_000_000_000)
        )
        #expect(result?.code == "77737706")
    }

    @Test func rfcSHA512_time20000000000() {
        let result = TOTPGenerator.generate(
            secret: sha512Secret, algorithm: .sha512, digits: 8,
            timestamp: Date(timeIntervalSince1970: 20_000_000_000)
        )
        #expect(result?.code == "47863826")
    }

    // MARK: - Consistency

    @Test func sameInputProducesSameCode() {
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let result1 = TOTPGenerator.generate(secret: sha1Secret, timestamp: timestamp)
        let result2 = TOTPGenerator.generate(secret: sha1Secret, timestamp: timestamp)
        #expect(result1?.code == result2?.code)
    }

    @Test func differentSecretsProduceDifferentCodes() {
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let result1 = TOTPGenerator.generate(secret: sha1Secret, timestamp: timestamp)
        let result2 = TOTPGenerator.generate(secret: "JBSWY3DPEHPK3PXP", timestamp: timestamp)
        #expect(result1?.code != result2?.code)
    }

    // MARK: - Custom Digits

    @Test func sixDigitCode() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, digits: 6,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code.count == 6)
    }

    @Test func sevenDigitCode() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, digits: 7,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code.count == 7)
    }

    @Test func eightDigitCode() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, digits: 8,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result?.code.count == 8)
    }

    // MARK: - Custom Period

    @Test func customPeriod60() {
        let result = TOTPGenerator.generate(
            secret: sha1Secret, period: 60,
            timestamp: Date(timeIntervalSince1970: 59)
        )
        #expect(result != nil)
        #expect(result?.windowEnd.timeIntervalSince1970 == 60)
    }

    // MARK: - Time Window Metadata

    @Test func resultIncludesTimeWindowMetadata() {
        let timestamp = Date(timeIntervalSince1970: 105)
        let result = TOTPGenerator.generate(
            secret: sha1Secret, period: 30, timestamp: timestamp
        )
        #expect(result != nil)
        #expect(result?.windowStart.timeIntervalSince1970 == 90)
        #expect(result?.windowEnd.timeIntervalSince1970 == 120)
        #expect(result?.remainingSeconds == 15.0)
        #expect(result?.progress == 0.5)
    }

    // MARK: - Invalid Input

    @Test func invalidSecretReturnsNil() {
        let result = TOTPGenerator.generate(
            secret: "not-valid-base32!!!",
            timestamp: Date()
        )
        #expect(result == nil)
    }
}
