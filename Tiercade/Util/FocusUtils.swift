import SwiftUI
#if os(tvOS)
import UIKit
#endif

enum FocusUtils {
    @MainActor
    static func seedFocus() {
        #if os(tvOS)
        Task { @MainActor in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
        #endif
    }
}
