import SwiftUI
#if os(tvOS)
import UIKit
#endif

enum FocusUtils {
    static func seedFocus() {
#if os(tvOS)
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
#endif
    }
}
