// Base32 decoding per RFC 4648
// Clean-room implementation for Sesame

import Foundation

enum Base32 {
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
