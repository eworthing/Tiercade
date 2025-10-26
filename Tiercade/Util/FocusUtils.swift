import SwiftUI
#if os(tvOS)
import Accessibility
#endif

internal enum FocusUtils {
    @MainActor
    internal static func seedFocus() {
        #if os(tvOS)
        Task { @MainActor in
            AccessibilityNotification.ScreenChanged().post()
        }
        #endif
    }
}
