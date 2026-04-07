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
}
