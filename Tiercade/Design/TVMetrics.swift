import SwiftUI

#if os(tvOS)
enum TVMetrics {
    static let topBarHeight: CGFloat = 76
    static let bottomBarHeight: CGFloat = 76
    static let barHorizontalPadding: CGFloat = 24
    static let barVerticalPadding: CGFloat = 8
    static let contentTopInset: CGFloat = topBarHeight + 8
    static let contentBottomInset: CGFloat = bottomBarHeight + 8
}
#endif
