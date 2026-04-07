import Foundation

enum HOTPGenerator {
    static func generate(
        secret: String,
        counter: Int,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6
    ) -> String? {
        guard let secretData = Base32.decode(secret) else { return nil }
        let counter64 = UInt64(counter)
        return OTPGenerator.generate(secret: secretData, algorithm: algorithm, counter: counter64, digits: digits)
    }
}
