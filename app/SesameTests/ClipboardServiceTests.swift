import Foundation
@testable import Sesame
import Testing

@Suite(.serialized)
struct ClipboardServiceTests {
    init() {
        UserDefaults.standard.removeObject(forKey: ClipboardService.clearDurationKey)
    }

    @Test("Duration reads from UserDefaults")
    func customDuration() {
        UserDefaults.standard.set(30, forKey: ClipboardService.clearDurationKey)
        #expect(ClipboardService.clearDuration == 30)
    }

    @Test("Zero means never clear")
    func zeroDuration() {
        UserDefaults.standard.set(0, forKey: ClipboardService.clearDurationKey)
        #expect(ClipboardService.clearDuration == 0)
    }

    @Test("Copy returns when the clipboard clears")
    func copyReturnsClearDate() throws {
        UserDefaults.standard.set(30, forKey: ClipboardService.clearDurationKey)
        let before = Date.now
        let clearsAt = try #require(ClipboardService.copy("123456"))
        #expect(clearsAt >= before.addingTimeInterval(30))
        #expect(clearsAt <= Date.now.addingTimeInterval(30))
    }

    @Test("Copy returns nil when the clipboard never clears")
    func copyNeverClears() {
        UserDefaults.standard.set(0, forKey: ClipboardService.clearDurationKey)
        #expect(ClipboardService.copy("123456") == nil)
    }
}
