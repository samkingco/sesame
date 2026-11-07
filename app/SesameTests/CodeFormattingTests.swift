@testable import Sesame
import Testing

struct CodeFormattingTests {
    @Test("Six digits split into two groups of three")
    func sixDigits() {
        #expect(CodeFormatting.halves("123456") == ("123", "456"))
    }

    @Test("Eight digits split into two groups of four")
    func eightDigits() {
        #expect(CodeFormatting.halves("12345678") == ("1234", "5678"))
    }

    @Test("Odd length puts the extra digit in the second group")
    func oddLength() {
        #expect(CodeFormatting.halves("1234567") == ("123", "4567"))
    }

    @Test("No code shows placeholder groups")
    func noCode() {
        #expect(CodeFormatting.halves(nil) == ("•••", "•••"))
        #expect(CodeFormatting.halves("") == ("•••", "•••"))
    }

    @Test("Formatted code joins the groups with a space")
    func formattedMatchesHalves() {
        #expect(CodeFormatting.formatted("123456") == "123 456")
        #expect(CodeFormatting.formatted(nil) == "••• •••")
    }
}
