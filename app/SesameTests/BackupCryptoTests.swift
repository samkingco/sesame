import CArgon2
import Foundation
@testable import Sesame
import Testing

struct BackupCryptoTests {
    private let testPassword = "correct-horse-battery-staple"
    private let testPayload = Data("hello world".utf8)

    // MARK: - Round-trip

    @Test("Encrypt then decrypt returns original payload")
    func roundTrip() throws {
        let blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        let decrypted = try BackupCrypto.decrypt(blob: blob, password: testPassword)
        #expect(decrypted == testPayload)
    }

    @Test("Round-trip with empty payload")
    func roundTripEmptyPayload() throws {
        let empty = Data()
        let blob = try BackupCrypto.encrypt(payload: empty, password: testPassword)
        let decrypted = try BackupCrypto.decrypt(blob: blob, password: testPassword)
        #expect(decrypted == empty)
    }

    @Test("Round-trip with realistic JSON payload")
    func roundTripJSON() throws {
        let json = Data("""
        {"payloadVersion":1,"accounts":[{"issuer":"GitHub","secret":"JBSWY3DPEHPK3PXP"}]}
        """.utf8)
        let blob = try BackupCrypto.encrypt(payload: json, password: testPassword)
        let decrypted = try BackupCrypto.decrypt(blob: blob, password: testPassword)
        #expect(decrypted == json)
    }

    // MARK: - Wrong password

    @Test("Decrypt with wrong password throws decryptionFailed")
    func wrongPassword() throws {
        let blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        #expect(throws: BackupCryptoError.decryptionFailed) {
            try BackupCrypto.decrypt(blob: blob, password: "wrong-password")
        }
    }

    // MARK: - Invalid blobs

    @Test("Decrypt with truncated blob throws invalidBlob")
    func truncatedBlob() {
        let tooShort = Data(repeating: 0, count: 10)
        #expect(throws: BackupCryptoError.invalidBlob) {
            try BackupCrypto.decrypt(blob: tooShort, password: testPassword)
        }
    }

    @Test("Decrypt with bad magic bytes throws invalidBlob")
    func badMagicBytes() throws {
        var blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        // Overwrite magic bytes
        blob[0] = 0xFF
        blob[1] = 0xFF
        #expect(throws: BackupCryptoError.invalidBlob) {
            try BackupCrypto.decrypt(blob: blob, password: testPassword)
        }
    }

    @Test("Decrypt with unsupported version throws unsupportedVersion")
    func unsupportedVersion() throws {
        var blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        // Set version to 0x99
        blob[6] = 0x99
        #expect(throws: BackupCryptoError.unsupportedVersion) {
            try BackupCrypto.decrypt(blob: blob, password: testPassword)
        }
    }

    @Test("Decrypt with empty data throws invalidBlob")
    func emptyBlob() {
        #expect(throws: BackupCryptoError.invalidBlob) {
            try BackupCrypto.decrypt(blob: Data(), password: testPassword)
        }
    }

    // MARK: - Blob structure

    @Test("Blob starts with ASCII SESAME followed by version 0x01")
    func blobHeader() throws {
        let blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        let magic = String(data: blob[0 ..< 6], encoding: .utf8)
        #expect(magic == "SESAME")
        #expect(blob[6] == 0x01)
    }

    @Test("Blob size matches expected layout")
    func blobSize() throws {
        let blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        // magic(6) + version(1) + salt(16) + nonce(12) + ciphertext(payload.count) + tag(16)
        let expected = 6 + 1 + 16 + 12 + testPayload.count + 16
        #expect(blob.count == expected)
    }

    // MARK: - Non-determinism

    @Test("Salt and nonce differ between encryptions of same payload and password")
    func nonDeterministic() throws {
        let blob1 = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        let blob2 = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)

        // Extract salt (bytes 7-22) and nonce (bytes 23-34)
        let salt1 = blob1[7 ..< 23]
        let salt2 = blob2[7 ..< 23]
        let nonce1 = blob1[23 ..< 35]
        let nonce2 = blob2[23 ..< 35]

        #expect(salt1 != salt2)
        #expect(nonce1 != nonce2)

        // Both should still decrypt correctly
        let d1 = try BackupCrypto.decrypt(blob: blob1, password: testPassword)
        let d2 = try BackupCrypto.decrypt(blob: blob2, password: testPassword)
        #expect(d1 == testPayload)
        #expect(d2 == testPayload)
    }

    // MARK: - Argon2id known-answer tests (from reference implementation)

    @Test("Argon2id produces correct hash for reference test vector")
    func argon2idKAT() {
        // From P-H-C/phc-winner-argon2 test.c: version=19, t=2, m=256, p=1
        let password = Array("password".utf8)
        let salt = Array("somesalt".utf8)
        var hash = [UInt8](repeating: 0, count: 32)

        let result = password.withUnsafeBufferPointer { pwdPtr in
            salt.withUnsafeBufferPointer { saltPtr in
                argon2id_hash_raw(2, 256, 1,
                                  pwdPtr.baseAddress, password.count,
                                  saltPtr.baseAddress, salt.count,
                                  &hash, 32)
            }
        }

        #expect(result == ARGON2_OK.rawValue)

        let expected = "9dfeb910e80bad0311fee20f9c0e2b12c17987b4cac90c2ef54d5b3021c68bfe"
        let actual = hash.map { String(format: "%02x", $0) }.joined()
        #expect(actual == expected)
    }

    @Test("Argon2id produces correct hash with parallelism 2")
    func argon2idKATParallel() {
        // From P-H-C/phc-winner-argon2 test.c: version=19, t=2, m=256, p=2
        let password = Array("password".utf8)
        let salt = Array("somesalt".utf8)
        var hash = [UInt8](repeating: 0, count: 32)

        let result = password.withUnsafeBufferPointer { pwdPtr in
            salt.withUnsafeBufferPointer { saltPtr in
                argon2id_hash_raw(2, 256, 2,
                                  pwdPtr.baseAddress, password.count,
                                  saltPtr.baseAddress, salt.count,
                                  &hash, 32)
            }
        }

        #expect(result == ARGON2_OK.rawValue)

        let expected = "6d093c501fd5999645e0ea3bf620d7b8be7fd2db59c20d9fff9539da2bf57037"
        let actual = hash.map { String(format: "%02x", $0) }.joined()
        #expect(actual == expected)
    }

    @Test("Argon2id produces correct hash with different password")
    func argon2idKATDifferentPassword() {
        // From P-H-C/phc-winner-argon2 test.c: version=19, t=2, m=65536, p=1
        let password = Array("differentpassword".utf8)
        let salt = Array("somesalt".utf8)
        var hash = [UInt8](repeating: 0, count: 32)

        let result = password.withUnsafeBufferPointer { pwdPtr in
            salt.withUnsafeBufferPointer { saltPtr in
                argon2id_hash_raw(2, 65536, 1,
                                  pwdPtr.baseAddress, password.count,
                                  saltPtr.baseAddress, salt.count,
                                  &hash, 32)
            }
        }

        #expect(result == ARGON2_OK.rawValue)

        let expected = "0b84d652cf6b0c4beaef0dfe278ba6a80df6696281d7e0d2891b817d8c458fde"
        let actual = hash.map { String(format: "%02x", $0) }.joined()
        #expect(actual == expected)
    }

    // MARK: - Corrupted ciphertext

    @Test("Decrypt with corrupted ciphertext throws decryptionFailed")
    func corruptedCiphertext() throws {
        var blob = try BackupCrypto.encrypt(payload: testPayload, password: testPassword)
        // Flip a byte in the ciphertext region (after header, before tag)
        let ciphertextStart = 6 + 1 + 16 + 12
        blob[ciphertextStart] ^= 0xFF
        #expect(throws: BackupCryptoError.decryptionFailed) {
            try BackupCrypto.decrypt(blob: blob, password: testPassword)
        }
    }
}
