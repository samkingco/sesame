// Base32 decoding per RFC 4648
// Clean-room implementation for Sesame

import Foundation

enum Base32 {
    static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }

        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var result = ""
        result.reserveCapacity((data.count * 8 + 4) / 5)

        var bits = 0
        var accumulator: UInt32 = 0

        for byte in data {
            accumulator = (accumulator << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                result.append(alphabet[Int((accumulator >> bits) & 0x1F)])
            }
        }

        if bits > 0 {
            result.append(alphabet[Int((accumulator << (5 - bits)) & 0x1F)])
        }

        return result
    }

    static func decode(_ input: String) -> Data? {
        let stripped = input
            .uppercased()
            .replacing("=", with: "")
            .filter { !$0.isWhitespace }

        guard !stripped.isEmpty else { return Data() }

        var bits = 0
        var accumulator: UInt32 = 0
        var output = Data()
        output.reserveCapacity(stripped.count * 5 / 8)

        for char in stripped {
            guard let value = alphabetValue(char) else { return nil }
            accumulator = (accumulator << 5) | UInt32(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }

        return output
    }

    /// Safe to force-unwrap: switch cases guarantee ASCII range
    private static func alphabetValue(_ char: Character) -> UInt8? {
        switch char {
        case "A" ... "Z":
            UInt8(char.asciiValue! - Character("A").asciiValue!)
        case "2" ... "7":
            UInt8(char.asciiValue! - Character("2").asciiValue! + 26)
        default:
            nil
        }
    }
}
