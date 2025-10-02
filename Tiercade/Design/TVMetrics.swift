import SwiftUI

#if os(tvOS)
enum TVMetrics {
    static let minSafeAreaVertical: CGFloat = 60
    static let minSafeAreaHorizontal: CGFloat = 80

    static let topBarHeight: CGFloat = 60
    static let bottomBarHeight: CGFloat = 60
    static let barHorizontalPadding: CGFloat = minSafeAreaHorizontal
    static let barVerticalPadding: CGFloat = 8
    static let toolbarContentGap: CGFloat = 12
    static let contentTopInset: CGFloat = max(topBarHeight, minSafeAreaVertical) + toolbarContentGap
    static let contentBottomInset: CGFloat = max(bottomBarHeight, minSafeAreaVertical)
    static let contentHorizontalPadding: CGFloat = minSafeAreaHorizontal

    // Overlay metrics
    static let overlayPadding: CGFloat = 60
    static let overlayCornerRadius: CGFloat = 24
    static let cardSpacing: CGFloat = 32
    static let buttonSpacing: CGFloat = 24
}
#endif
