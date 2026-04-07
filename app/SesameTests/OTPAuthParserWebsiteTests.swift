@testable import Sesame
import Testing

struct OTPAuthParserWebsiteTests {
    @Test func knownIssuerAutoPopulatesWebsite() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/GitHub:user?secret=JBSWY3DPEHPK3PXP&issuer=GitHub"
        )
        #expect(result.website == "github.com")
    }

    @Test func unknownIssuerLeavesWebsiteNil() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/CustomApp:user?secret=JBSWY3DPEHPK3PXP&issuer=CustomApp"
        )
        #expect(result.website == nil)
    }

    @Test func noIssuerLeavesWebsiteNil() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/user?secret=JBSWY3DPEHPK3PXP"
        )
        #expect(result.website == nil)
    }

    @Test func rawSecretLeavesWebsiteNil() throws {
        let result = try OTPAuthParser.parse("JBSWY3DPEHPK3PXP")
        #expect(result.website == nil)
    }

    @Test func caseInsensitiveIssuerMatchesWebsite() throws {
        let result = try OTPAuthParser.parse(
            "otpauth://totp/google:user@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=google"
        )
        #expect(result.website == "google.com")
    }
}
