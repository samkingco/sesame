@testable import Sesame
import Testing

struct OTPAuthParserTests {
    // MARK: - Valid TOTP URIs

    @Test func basicTOTP() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        )
        #expect(result.type == .totp)
        #expect(result.issuer == "Example")
        #expect(result.name == "alice@google.com")
        #expect(result.secret == "JBSWY3DPEHPK3PXP")
        #expect(result.algorithm == .sha1)
        #expect(result.digits == 6)
        #expect(result.period == 30)
    }

    @Test func totpWithAllParameters() throws {
        let result = try OTPAuthParser.parse(
            // swiftlint:disable:next line_length
            "otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60"
        )
        #expect(result.type == .totp)
        #expect(result.issuer == "ACME Co")
        #expect(result.name == "john.doe@email.com")
        #expect(result.secret == "HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ")
        #expect(result.algorithm == .sha256)
        #expect(result.digits == 8)
        #expect(result.period == 60)
    }

    @Test func sha512Algorithm() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&algorithm=SHA512"
        )
        #expect(result.algorithm == .sha512)
    }

    // MARK: - Valid HOTP URIs

    @Test func basicHOTP() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&counter=0"
        )
        #expect(result.type == .hotp)
        #expect(result.issuer == "Example")
        #expect(result.name == "alice@google.com")
        #expect(result.counter == 0)
    }

    @Test func hotpWithCounter() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://hotp/test?secret=JBSWY3DPEHPK3PXP&counter=42"
        )
        #expect(result.type == .hotp)
        #expect(result.counter == 42)
    }

    // MARK: - Issuer handling

    @Test func issuerFromParameterOnly() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        )
        #expect(result.name == "alice@google.com")
        #expect(result.issuer == "Example")
    }

    @Test func issuerParameterOverridesLabel() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/LabelIssuer:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=ParamIssuer"
        )
        #expect(result.issuer == "ParamIssuer")
        #expect(result.name == "alice@google.com")
    }

    @Test func noIssuerAnywhere() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/alice@google.com?secret=JBSWY3DPEHPK3PXP"
        )
        #expect(result.issuer == nil)
        #expect(result.name == "alice@google.com")
    }

    // MARK: - URL encoding

    @Test func urlEncodedCharacters() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/My%20Company:user%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=My%20Company"
        )
        #expect(result.issuer == "My Company")
        #expect(result.name == "user@example.com")
    }

    // MARK: - Validation errors

    @Test func invalidProtocol() {
        #expect(throws: OTPAuthParseError.invalidProtocol) {
            try OTPAuthParser.parse("http://totp/test?secret=JBSWY3DPEHPK3PXP")
        }
    }

    @Test func invalidOTPType() {
        #expect(throws: OTPAuthParseError.invalidOTPType("invalid")) {
            try OTPAuthParser.parse("otpauth://invalid/test?secret=JBSWY3DPEHPK3PXP")
        }
    }

    @Test func missingLabel() {
        #expect(throws: OTPAuthParseError.missingLabel) {
            try OTPAuthParser.parse("otpauth://totp/?secret=JBSWY3DPEHPK3PXP")
        }
    }

    @Test func missingSecret() {
        #expect(throws: OTPAuthParseError.missingSecret) {
            try OTPAuthParser.parse("otpauth://totp/test")
        }
    }

    @Test func digitsTooLow() {
        #expect(throws: OTPAuthParseError.invalidDigits(5)) {
            try OTPAuthParser.parse("otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&digits=5")
        }
    }

    @Test func digitsTooHigh() {
        #expect(throws: OTPAuthParseError.invalidDigits(9)) {
            try OTPAuthParser.parse("otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&digits=9")
        }
    }

    @Test func nonNumericDigits() {
        #expect(throws: OTPAuthParseError.invalidDigits(0)) {
            try OTPAuthParser.parse("otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&digits=abc")
        }
    }

    @Test func periodZero() {
        #expect(throws: OTPAuthParseError.invalidPeriod(0)) {
            try OTPAuthParser.parse("otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&period=0")
        }
    }

    @Test func negativePeriod() {
        #expect(throws: OTPAuthParseError.invalidPeriod(-30)) {
            try OTPAuthParser.parse("otpauth://totp/test?secret=JBSWY3DPEHPK3PXP&period=-30")
        }
    }

    @Test func negativeCounter() {
        #expect(throws: OTPAuthParseError.invalidCounter(-1)) {
            try OTPAuthParser.parse("otpauth://hotp/test?secret=JBSWY3DPEHPK3PXP&counter=-1")
        }
    }

    // MARK: - Raw base32 secret

    @Test func rawBase32Secret() throws {
        let result = try OTPAuthParser.parse("JBSWY3DPEHPK3PXP")
        #expect(result.type == .totp)
        #expect(result.secret == "JBSWY3DPEHPK3PXP")
        #expect(result.name == "Account")
        #expect(result.issuer == nil)
        #expect(result.algorithm == .sha1)
        #expect(result.digits == 6)
        #expect(result.period == 30)
    }

    @Test func rawBase32WithSpacesAndLowercase() throws {
        let result = try OTPAuthParser.parse("jbsw y3dp ehpk 3pxp")
        #expect(result.secret == "JBSWY3DPEHPK3PXP")
    }

    @Test func rawBase32TooShort() {
        #expect(throws: OTPAuthParseError.invalidSecret) {
            try OTPAuthParser.parse("JBSWY3D")
        }
    }

    @Test func invalidBase32Characters() {
        #expect(throws: OTPAuthParseError.invalidSecret) {
            try OTPAuthParser.parse("INVALID!@#SECRET890")
        }
    }

    // MARK: - Edge cases

    @Test func multipleColonsInLabel() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/Service:Name:user@example.com?secret=JBSWY3DPEHPK3PXP"
        )
        #expect(result.issuer == "Service")
        #expect(result.name == "Name:user@example.com")
    }

    @Test func realWorldGitHubURI() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/GitHub:username?secret=ABCDEFGHIJKLMNOP&issuer=GitHub"
        )
        #expect(result.issuer == "GitHub")
        #expect(result.name == "username")
        #expect(result.type == .totp)
    }

    @Test func realWorldGoogleURI() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/Google%3Auser%40gmail.com?secret=ABCDEFGHIJKLMNOP&issuer=Google"
        )
        #expect(result.issuer == "Google")
        #expect(result.name == "user@gmail.com")
    }

    @Test func veryLongSecret() throws {
        let longSecret = String(repeating: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", count: 2)
        let result = try OTPAuthParser.parse(
            "otpauth://totp/test?secret=\(longSecret)"
        )
        #expect(result.secret == longSecret)
    }
}
