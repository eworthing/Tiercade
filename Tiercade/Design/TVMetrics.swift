import SwiftUI

#if os(tvOS)
enum TVMetrics {
    static let minSafeAreaVertical: CGFloat = 60
    static let minSafeAreaHorizontal: CGFloat = 80

    static let topBarHeight: CGFloat = 60
    static let bottomBarHeight: CGFloat = 60
    static let barHorizontalPadding: CGFloat = minSafeAreaHorizontal
    static let barVerticalPadding: CGFloat = 8
    static let contentTopInset: CGFloat = max(topBarHeight, minSafeAreaVertical)
    static let contentBottomInset: CGFloat = max(bottomBarHeight, minSafeAreaVertical)
    static let contentHorizontalPadding: CGFloat = minSafeAreaHorizontal
}
#endif
