@testable import Sesame
import Testing

struct IssuerDomainMapTests {
    @Test func knownIssuerReturnsCorrectDomain() {
        #expect(IssuerDomainMap.domain(for: "GitHub") == "github.com")
        #expect(IssuerDomainMap.domain(for: "Google") == "google.com")
        #expect(IssuerDomainMap.domain(for: "AWS") == "aws.amazon.com")
        #expect(IssuerDomainMap.domain(for: "Stripe") == "stripe.com")
    }

    @Test func caseInsensitiveLookup() {
        #expect(IssuerDomainMap.domain(for: "github") == "github.com")
        #expect(IssuerDomainMap.domain(for: "GITHUB") == "github.com")
        #expect(IssuerDomainMap.domain(for: "GitHub") == "github.com")
    }

    @Test func unknownIssuerReturnsNil() {
        #expect(IssuerDomainMap.domain(for: "UnknownService") == nil)
        #expect(IssuerDomainMap.domain(for: "") == nil)
        #expect(IssuerDomainMap.domain(for: "My Custom App") == nil)
    }
}
