import CArgon2
import CryptoKit
import Foundation

enum BackupCryptoError: Error {
    case invalidBlob
    case unsupportedVersion
    case decryptionFailed
    case encryptionFailed
    case randomGenerationFailed
}

enum BackupCrypto {
    // MARK: - Constants

    private static let magicBytes: [UInt8] = Array("SESAME".utf8) // 6 bytes
    private static let currentVersion: UInt8 = 0x01
    private static let saltLength = 16
    private static let nonceLength = 12
    private static let keyLength = 32
    private static let headerLength = magicBytes.count + 1 + saltLength + nonceLength // 35 bytes

    // Argon2id parameters
    private static let argon2Iterations: UInt32 = 3
    private static let argon2Memory: UInt32 = 65536 // 64 MB in KiB
    private static let argon2Parallelism: UInt32 = 4

    // MARK: - Public API

    static func encrypt(payload: Data, password: String) throws -> Data {
        let salt = try generateRandomBytes(count: saltLength)
        let key = try deriveKey(password: password, salt: salt)

        let nonce = try AES.GCM.Nonce(data: generateRandomBytes(count: nonceLength))
        let symmetricKey = SymmetricKey(data: key)

        guard let sealed = try? AES.GCM.seal(payload, using: symmetricKey, nonce: nonce) else {
            throw BackupCryptoError.encryptionFailed
        }

        // Assemble blob: magic(6) + version(1) + salt(16) + nonce(12) + ciphertext + tag(16)
        var blob = Data()
        blob.append(contentsOf: magicBytes)
        blob.append(currentVersion)
        blob.append(contentsOf: salt)
        blob.append(contentsOf: nonce.withUnsafeBytes { Array($0) })
        blob.append(sealed.ciphertext)
        blob.append(sealed.tag)

        return blob
    }

    static func decrypt(blob: Data, password: String) throws -> Data {
        let tagLength = 16
        guard blob.count >= headerLength + tagLength else {
            throw BackupCryptoError.invalidBlob
        }

        var offset = 0

        // Verify magic bytes
        let magic = Array(blob[offset ..< offset + magicBytes.count])
        guard magic == magicBytes else {
            throw BackupCryptoError.invalidBlob
        }
        offset += magicBytes.count

        // Check version
        let version = blob[offset]
        guard version == currentVersion else {
            throw BackupCryptoError.unsupportedVersion
        }
        offset += 1

        // Extract salt, nonce, ciphertext, tag
        let salt = Array(blob[offset ..< offset + saltLength])
        offset += saltLength

        let nonceBytes = blob[offset ..< offset + nonceLength]
        offset += nonceLength

        let ciphertextEnd = blob.count - tagLength
        let ciphertext = blob[offset ..< ciphertextEnd]
        let tag = blob[ciphertextEnd ..< blob.count]

        // Derive key
        let key = try deriveKey(password: password, salt: salt)
        let symmetricKey = SymmetricKey(data: key)

        // Decrypt
        let nonce = try AES.GCM.Nonce(data: nonceBytes)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )

        do {
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw BackupCryptoError.decryptionFailed
        }
    }

    // MARK: - Key Derivation

    private static func deriveKey(password: String, salt: [UInt8]) throws -> [UInt8] {
        let passwordBytes = Array(password.utf8)
        var hash = [UInt8](repeating: 0, count: keyLength)

        let result = passwordBytes.withUnsafeBufferPointer { pwdPtr in
            salt.withUnsafeBufferPointer { saltPtr in
                argon2id_hash_raw(
                    argon2Iterations,
                    argon2Memory,
                    argon2Parallelism,
                    pwdPtr.baseAddress,
                    passwordBytes.count,
                    saltPtr.baseAddress,
                    saltPtr.count,
                    &hash,
                    keyLength
                )
            }
        }

        guard result == ARGON2_OK.rawValue else {
            throw BackupCryptoError.encryptionFailed
        }

        return hash
    }

    // MARK: - Random Bytes

    private static func generateRandomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw BackupCryptoError.randomGenerationFailed
        }
        return bytes
    }
}
