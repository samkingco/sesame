@testable import Sesame
import Testing

struct HOTPGeneratorTests {
    /// RFC 4226 test secret: ASCII "12345678901234567890" (20 bytes)
    let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    // MARK: - RFC 4226 Test Vectors (6-digit, SHA1)

    @Test func rfcCounter0() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 0) == "755224")
    }

    @Test func rfcCounter1() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 1) == "287082")
    }

    @Test func rfcCounter2() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 2) == "359152")
    }

    @Test func rfcCounter3() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 3) == "969429")
    }

    @Test func rfcCounter4() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 4) == "338314")
    }

    @Test func rfcCounter5() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 5) == "254676")
    }

    @Test func rfcCounter6() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 6) == "287922")
    }

    @Test func rfcCounter7() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 7) == "162583")
    }

    @Test func rfcCounter8() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 8) == "399871")
    }

    @Test func rfcCounter9() {
        #expect(HOTPGenerator.generate(secret: secret, counter: 9) == "520489")
    }

    // MARK: - Behavior

    @Test func sequentialCountersProduceDifferentCodes() {
        let code1 = HOTPGenerator.generate(secret: secret, counter: 0)
        let code2 = HOTPGenerator.generate(secret: secret, counter: 1)
        #expect(code1 != code2)
    }

    @Test func invalidSecretReturnsNil() {
        #expect(HOTPGenerator.generate(secret: "invalid!!!", counter: 0) == nil)
    }
}
