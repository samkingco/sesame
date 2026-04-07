import CArgon2
import CryptoKit
import Foundation

// MARK: - Constants (must match BackupCrypto.swift)

private let magicBytes: [UInt8] = Array("SESAME".utf8) // 6 bytes
private let currentVersion: UInt8 = 0x01
private let saltLength = 16
private let nonceLength = 12
private let keyLength = 32
private let headerLength = magicBytes.count + 1 + saltLength + nonceLength // 35 bytes
private let tagLength = 16

private let argon2Iterations: UInt32 = 3
private let argon2Memory: UInt32 = 65_536 // 64 MB in KiB
private let argon2Parallelism: UInt32 = 4

// MARK: - Key Derivation

private func deriveKey(password: String, salt: [UInt8]) -> [UInt8] {
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
        fputs("Error: key derivation failed (argon2 error \(result))\n", stderr)
        exit(1)
    }

    return hash
}

// MARK: - Decryption

private func decrypt(blob: Data, password: String) -> Data {
    guard blob.count >= headerLength + tagLength else {
        fputs("Error: file too small to be a valid .sesame backup\n", stderr)
        exit(1)
    }

    var offset = 0

    // Verify magic bytes
    let magic = Array(blob[offset..<offset + magicBytes.count])
    guard magic == magicBytes else {
        fputs("Error: not a .sesame backup file (invalid magic bytes)\n", stderr)
        exit(1)
    }
    offset += magicBytes.count

    // Check version
    let version = blob[offset]
    guard version == currentVersion else {
        fputs("Error: unsupported backup version \(version)\n", stderr)
        exit(1)
    }
    offset += 1

    // Extract salt, nonce, ciphertext, tag
    let salt = Array(blob[offset..<offset + saltLength])
    offset += saltLength

    let nonceBytes = blob[offset..<offset + nonceLength]
    offset += nonceLength

    let ciphertextEnd = blob.count - tagLength
    let ciphertext = blob[offset..<ciphertextEnd]
    let tag = blob[ciphertextEnd..<blob.count]

    // Derive key and decrypt
    let key = deriveKey(password: password, salt: salt)
    let symmetricKey = SymmetricKey(data: key)

    guard let nonce = try? AES.GCM.Nonce(data: nonceBytes),
          let sealedBox = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag),
          let plaintext = try? AES.GCM.open(sealedBox, using: symmetricKey)
    else {
        fputs("Error: decryption failed — wrong password or corrupt file\n", stderr)
        exit(1)
    }

    return plaintext
}

// MARK: - Password Input

private func readPassword() -> String {
    if isatty(STDIN_FILENO) != 0 {
        fputs("Password: ", stderr)

        // Disable echo
        var original = termios()
        tcgetattr(STDIN_FILENO, &original)
        var noEcho = original
        noEcho.c_lflag &= ~tcflag_t(ECHO)
        tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)

        let password = readLine(strippingNewline: true) ?? ""

        tcsetattr(STDIN_FILENO, TCSANOW, &original)
        fputs("\n", stderr)

        return password
    } else {
        // stdin is piped — read without prompt
        return readLine(strippingNewline: true) ?? ""
    }
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.contains("-h") || args.contains("--help") {
    fputs("""
    Usage: sesame-decrypt <file.sesame>

    Decrypts a .sesame backup file and prints the JSON payload to stdout.
    Password is read from stdin (interactive prompt with hidden input,
    or piped: echo 'pw' | sesame-decrypt backup.sesame).

    """, stderr)
    exit(args.isEmpty ? 1 : 0)
}

guard args.count == 1 else {
    fputs("Usage: sesame-decrypt <file.sesame>\n", stderr)
    exit(1)
}

let filePath = args[0]

guard FileManager.default.fileExists(atPath: filePath) else {
    fputs("Error: file not found: \(filePath)\n", stderr)
    exit(1)
}

guard let blob = FileManager.default.contents(atPath: filePath) else {
    fputs("Error: could not read file: \(filePath)\n", stderr)
    exit(1)
}

let password = readPassword()

guard !password.isEmpty else {
    fputs("Error: password cannot be empty\n", stderr)
    exit(1)
}

let plaintext = decrypt(blob: blob, password: password)

// Pretty-print JSON to stdout
if let json = try? JSONSerialization.jsonObject(with: plaintext),
   let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
   let output = String(data: pretty, encoding: .utf8)
{
    print(output)
} else if let raw = String(data: plaintext, encoding: .utf8) {
    print(raw)
} else {
    fputs("Error: decrypted payload is not valid UTF-8\n", stderr)
    exit(1)
}
