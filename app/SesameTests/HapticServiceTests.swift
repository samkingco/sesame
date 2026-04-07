import Foundation
@testable import Sesame
import Testing

@Suite(.serialized)
struct HapticServiceTests {
    init() {
        UserDefaults.standard.removeObject(forKey: HapticService.enabledKey)
    }

    @Test("Disabled when set to false")
    func disabledWhenFalse() {
        UserDefaults.standard.set(false, forKey: HapticService.enabledKey)
        #expect(HapticService.isEnabled == false)
    }

    @Test("Enabled when set to true")
    func enabledWhenTrue() {
        UserDefaults.standard.set(true, forKey: HapticService.enabledKey)
        #expect(HapticService.isEnabled == true)
    }
}
