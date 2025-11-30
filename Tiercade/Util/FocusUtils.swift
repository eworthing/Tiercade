import SwiftUI
#if os(tvOS)
import Accessibility
#endif

// MARK: - FocusUtils

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
