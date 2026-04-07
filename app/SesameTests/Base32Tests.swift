import Foundation
@testable import Sesame
import Testing

struct Base32Tests {
    // MARK: - RFC 4648 Test Vectors

    @Test func decodesEmpty() {
        #expect(Base32.decode("") == Data())
    }

    @Test func decodes_f() {
        #expect(Base32.decode("MY======") == Data("f".utf8))
    }

    @Test func decodes_fo() {
        #expect(Base32.decode("MZXQ====") == Data("fo".utf8))
    }

    @Test func decodes_foo() {
        #expect(Base32.decode("MZXW6===") == Data("foo".utf8))
    }

    @Test func decodes_foob() {
        #expect(Base32.decode("MZXW6YQ=") == Data("foob".utf8))
    }

    @Test func decodes_fooba() {
        #expect(Base32.decode("MZXW6YTB") == Data("fooba".utf8))
    }

    @Test func decodes_foobar() {
        #expect(Base32.decode("MZXW6YTBOI======") == Data("foobar".utf8))
    }

    // MARK: - Padding tolerance

    @Test func decodesWithoutPadding() {
        #expect(Base32.decode("MZXW6YTB") == Data("fooba".utf8))
        #expect(Base32.decode("MZXW6YTBOI") == Data("foobar".utf8))
    }

    // MARK: - Case insensitivity

    @Test func decodesLowercase() {
        #expect(Base32.decode("mzxw6ytb") == Data("fooba".utf8))
    }

    @Test func decodesMixedCase() {
        #expect(Base32.decode("MzXw6YtB") == Data("fooba".utf8))
    }

    // MARK: - Invalid input

    @Test func invalidCharactersReturnNil() {
        #expect(Base32.decode("!!!") == nil)
        #expect(Base32.decode("MZXW6===!") == nil)
    }

    // MARK: - OTP secret round-trip

    @Test func decodesRFC4226Secret() {
        // "12345678901234567890" base32-encoded
        let encoded = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        let decoded = Base32.decode(encoded)
        #expect(decoded == Data("12345678901234567890".utf8))
    }
}
