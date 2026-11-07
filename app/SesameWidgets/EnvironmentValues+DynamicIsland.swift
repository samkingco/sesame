import SwiftUI
import WidgetKit

extension EnvironmentValues {
    /// True when the compact Dynamic Island views are narrow. On the iPhone Duo
    /// outer display, the Dynamic Island runs down the side of the screen.
    var isDynamicIslandNarrow: Bool {
        if #available(iOS 27.0, *) {
            return isDynamicIslandLimitedInWidth
        }
        return false
    }
}
