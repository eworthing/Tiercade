import SwiftUI
#if os(tvOS)
import Accessibility
#endif

enum FocusUtils {
    @MainActor
    static func seedFocus() {
        #if os(tvOS)
        Task { @MainActor in
            AccessibilityNotification.ScreenChanged().post()
        }
        #endif
    }
}
