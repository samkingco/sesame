import Foundation
@testable import Sesame
import Testing

struct GoogleAuthMigrationParserTests {
    // MARK: - Valid payloads

    @Test func singleTOTP() throws {
        let uri =
            "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC"
        let accounts = try GoogleAuthMigrationParser.parse(uri)

        #expect(accounts.count == 1)
        let account = accounts[0]
        #expect(account.name == "alice@google.com")
        #expect(account.issuer == "Example")
        #expect(account.secret == "JBSWY3DPEHPK3PXP")
        #expect(account.algorithm == .sha1)
        #expect(account.digits == 6)
        #expect(account.type == .totp)
        #expect(account.counter == 0)
        #expect(account.period == 30)
    }

    @Test func hotpWithCounter() throws {
        let uri =
            "otpauth-migration://offline?data=CiUKEPqlBekzoNEukL7qlsjBCDYSCWhvdHAgZGVtbyABKAEwATgE"
        let accounts = try GoogleAuthMigrationParser.parse(uri)

        #expect(accounts.count == 1)
        let account = accounts[0]
        #expect(account.name == "hotp demo")
        #expect(account.issuer == nil)
        #expect(account.secret == "7KSQL2JTUDIS5EF65KLMRQIIGY")
        #expect(account.algorithm == .sha1)
        #expect(account.digits == 6)
        #expect(account.type == .hotp)
        #expect(account.counter == 4)
    }

    @Test func multipleAccounts() throws {
        let data = "CigKEPqlBekzoNEukL7qlsjBCDYSDnBpQHJhc3BiZXJyeXBpIAEoATAC"
            + "CjUKEPqlBekzoNEukL7qlsjBCDYSDnBpQHJhc3BiZXJyeXBpGgtyYXNwYmVycnlwaSABKAEwAg=="
        let uri = "otpauth-migration://offline?data=\(data)"
        let accounts = try GoogleAuthMigrationParser.parse(uri)

        #expect(accounts.count == 2)

        #expect(accounts[0].name == "pi@raspberrypi")
        #expect(accounts[0].issuer == nil)
        #expect(accounts[0].secret == "7KSQL2JTUDIS5EF65KLMRQIIGY")
        #expect(accounts[0].type == .totp)

        #expect(accounts[1].name == "pi@raspberrypi")
        #expect(accounts[1].issuer == "raspberrypi")
        #expect(accounts[1].secret == "7KSQL2JTUDIS5EF65KLMRQIIGY")
        #expect(accounts[1].type == .totp)
    }

    @Test func fourAccountsWithSpecialChars() throws {
        let data = "Cj8KFGnEpnTMQ7KDguNWnddyGyCbSVLaEhhBQ01FIENvOmpvaG5AZXhhbXBsZS5jb20"
            + "aB0FDTUUgQ28gASgBMAIKRAoUXkj+5MY2arwKjsnH2aDsbm6TAlYSG0JldGEgTHRkLjpob21l"
            + "ckBleGFtcGxlLmNvbRoJQmV0YSBMdGQuIAEoATACCkgKFDDFyzUNPgYoI3q/KGHBdcNU9ptWE"
            + "h1DYXRzICYgRG9nczptYXJnZUBleGFtcGxlLmNvbRoLQ2F0cyAmIERvZ3MgASgBMAIKSAoUun"
            + "Hzbm5h/LUO0yilLMI+dYZY1eISHURhaWx5IEJ1Z2xlOnBldGVyQGV4YW1wbGUuY29tGgtEYWl"
            + "seSBCdWdsZSABKAEwAhABGAEgACjDnb+uAg=="
        let uri = "otpauth-migration://offline?data=\(data)"
        let accounts = try GoogleAuthMigrationParser.parse(uri)

        #expect(accounts.count == 4)

        #expect(accounts[0].name == "john@example.com")
        #expect(accounts[0].issuer == "ACME Co")
        #expect(accounts[0].type == .totp)
        #expect(accounts[0].algorithm == .sha1)
        #expect(accounts[0].digits == 6)

        #expect(accounts[1].name == "homer@example.com")
        #expect(accounts[1].issuer == "Beta Ltd.")

        #expect(accounts[2].name == "marge@example.com")
        #expect(accounts[2].issuer == "Cats & Dogs")

        #expect(accounts[3].name == "peter@example.com")
        #expect(accounts[3].issuer == "Daily Bugle")
    }

    // MARK: - Algorithm and digits mapping

    @Test func algorithmMapping() throws {
        // Vector 2 has explicit SHA1(1)
        let uri =
            "otpauth-migration://offline?data=CiUKEPqlBekzoNEukL7qlsjBCDYSCWhvdHAgZGVtbyABKAEwATgE"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts[0].algorithm == .sha1)
    }

    @Test func unspecifiedDefaultsToSHA1() throws {
        // Vector 1 has UNSPECIFIED(0) algorithm
        let uri =
            "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts[0].algorithm == .sha1)
    }

    @Test func unspecifiedDigitsDefaultsToSix() throws {
        // Vector 1 has UNSPECIFIED(0) digits
        let uri =
            "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts[0].digits == 6)
    }

    @Test func sixDigitsExplicit() throws {
        // Vector 2 has SIX(1) digits
        let uri =
            "otpauth-migration://offline?data=CiUKEPqlBekzoNEukL7qlsjBCDYSCWhvdHAgZGVtbyABKAEwATgE"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts[0].digits == 6)
    }

    // MARK: - Base32 encoding

    @Test func secretBytesEncodedAsBase32() throws {
        let uri =
            "otpauth-migration://offline?data=CjEKCkhlbGxvId6tvu8SGEV4YW1wbGU6YWxpY2VAZ29vZ2xlLmNvbRoHRXhhbXBsZTAC"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts[0].secret == "JBSWY3DPEHPK3PXP")
    }

    // MARK: - Edge cases

    @Test func emptyPayload() throws {
        // Base64 of empty protobuf
        let uri = "otpauth-migration://offline?data="
        #expect(throws: GoogleAuthMigrationParseError.missingData) {
            try GoogleAuthMigrationParser.parse(uri)
        }
    }

    @Test func emptyProtobufReturnsEmptyArray() throws {
        // Protobuf with only version field (field 2, varint 1) — no otp_parameters
        let versionOnly = Data([0x10, 0x01]).base64EncodedString()
        let uri = "otpauth-migration://offline?data=\(versionOnly)"
        let accounts = try GoogleAuthMigrationParser.parse(uri)
        #expect(accounts.isEmpty)
    }

    @Test func invalidBase64() {
        let uri = "otpauth-migration://offline?data=not!valid!base64!!!"
        #expect(throws: GoogleAuthMigrationParseError.invalidBase64) {
            try GoogleAuthMigrationParser.parse(uri)
        }
    }

    @Test func malformedProtobuf() {
        // Truncated data — starts a length-delimited field but data is cut short
        let truncated = Data([0x0A, 0x20]).base64EncodedString()
        let uri = "otpauth-migration://offline?data=\(truncated)"
        #expect(throws: GoogleAuthMigrationParseError.malformedProtobuf) {
            try GoogleAuthMigrationParser.parse(uri)
        }
    }

    @Test func invalidScheme() {
        let uri = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP"
        #expect(throws: GoogleAuthMigrationParseError.invalidScheme) {
            try GoogleAuthMigrationParser.parse(uri)
        }
    }

    @Test func missingDataParameter() {
        let uri = "otpauth-migration://offline"
        #expect(throws: GoogleAuthMigrationParseError.missingData) {
            try GoogleAuthMigrationParser.parse(uri)
        }
    }
}
