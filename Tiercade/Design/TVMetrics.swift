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
    static let toolbarClusterSpacing: CGFloat = 12
    static let contentTopInset: CGFloat = max(topBarHeight, minSafeAreaVertical) + toolbarContentGap
    static let contentBottomInset: CGFloat = max(bottomBarHeight, minSafeAreaVertical)
    static let contentHorizontalPadding: CGFloat = minSafeAreaHorizontal

    // Overlay metrics
    static let overlayPadding: CGFloat = 60
    static let overlayCornerRadius: CGFloat = 24
    static let cardSpacing: CGFloat = 32
    static let buttonSpacing: CGFloat = 24

    // MARK: - Grid Density Tuning

    /// Base threshold for automatic density transitions (18 items).
    ///
    /// **Derivation:**
    /// - Apple TV 4K (3rd gen) displays approximately 4 rows × 5 cards at "standard" density
    /// - 4 × 5 = 20 cards visible without scrolling at 1920×1080 resolution
    /// - At 18+ items, the unranked tier begins requiring vertical scrolling
    /// - 10% buffer (20 → 18) provides headroom before auto-downgrade kicks in
    ///
    /// **Display context:**
    /// - 236pt card width (standard density) @ 10ft viewing distance
    /// - Content safe area: 1760×990 pts (accounting for tvOS overscan)
    /// - Card spacing: 30pts horizontal, 22pts vertical
    ///
    /// **Why 18?**
    /// - Below 18: Users can see entire tier grid without scrolling → maximize card size
    /// - At 18-35: Scrolling begins → reduce to "compact" (200pt cards) for better overview
    /// - At 36-53: Long scrolls → shift to "tight" (170pt cards) for faster navigation
    /// - At 54-71: Very large catalogs → "micro" (140pt cards) prioritizes density
    /// - At 72+: Massive collections → "ultraMicro" (110pt cards) shows maximum items
    ///
    /// **Multiplier rationale:**
    /// - 1× (18): Compact threshold — one scroll-page worth of overflow
    /// - 2× (36): Tight threshold — two screens worth, scrolling becomes tedious
    /// - 3× (54): Micro threshold — three screens, users now scanning vs. reading
    /// - 4× (72): UltraMicro threshold — four screens, information density critical
    static let denseThreshold: Int = 18

    static func cardLayout(
        for itemCount: Int,
        preference: CardDensityPreference,
    )
    -> TVCardLayout {
        func layout(for preference: CardDensityPreference) -> TVCardLayout {
            switch preference {
            case .ultraMicro: .ultraMicro
            case .micro: .micro
            case .tight: .tight
            case .compact: .compact
            case .standard: .standard
            case .expanded: .expanded
            }
        }

        func minDensity(_ lhs: CardDensityPreference, _ rhs: CardDensityPreference) -> CardDensityPreference {
            lhs.sizeRank <= rhs.sizeRank ? lhs : rhs
        }

        var effective = preference
        if itemCount >= denseThreshold * 4 {
            effective = .ultraMicro
        } else if itemCount >= denseThreshold * 3 {
            effective = minDensity(effective, .micro)
        } else if itemCount >= denseThreshold * 2 {
            effective = minDensity(effective, .tight)
        } else if itemCount >= denseThreshold {
            effective = minDensity(effective, .compact)
        }

        return layout(for: effective)
    }
}

struct TVCardLayout {
    static let ultraMicro = TVCardLayout(
        density: .ultraMicro,
        thumbnailSize: CGSize(width: 110, height: 165),
        contentPadding: 6,
        interItemSpacing: 20,
        verticalContentSpacing: 0,
        titleFont: .caption.weight(.semibold),
        metadataFont: .caption.weight(.regular),
        cornerRadius: 6,
    )

    static let micro = TVCardLayout(
        density: .micro,
        thumbnailSize: CGSize(width: 140, height: 186),
        contentPadding: 14,
        interItemSpacing: 16,
        verticalContentSpacing: 7,
        titleFont: .callout.weight(.semibold),
        metadataFont: .footnote.weight(.semibold),
        cornerRadius: 10,
    )

    static let tight = TVCardLayout(
        density: .tight,
        thumbnailSize: CGSize(width: 170, height: 226),
        contentPadding: 15,
        interItemSpacing: 18,
        verticalContentSpacing: 8,
        titleFont: .headline.weight(.semibold),
        metadataFont: .footnote.weight(.semibold),
        cornerRadius: 12,
    )

    static let compact = TVCardLayout(
        density: .compact,
        thumbnailSize: CGSize(width: 200, height: 266),
        contentPadding: 17,
        interItemSpacing: 22,
        verticalContentSpacing: 9,
        titleFont: .headline.weight(.semibold),
        metadataFont: .subheadline.weight(.semibold),
        cornerRadius: 14,
    )

    static let standard = TVCardLayout(
        density: .standard,
        thumbnailSize: CGSize(width: 236, height: 316),
        contentPadding: 22,
        interItemSpacing: 30,
        verticalContentSpacing: 11,
        titleFont: .title3.weight(.semibold),
        metadataFont: .callout.weight(.semibold),
        cornerRadius: 17,
    )

    static let expanded = TVCardLayout(
        density: .expanded,
        thumbnailSize: CGSize(width: 264, height: 354),
        contentPadding: 26,
        interItemSpacing: 36,
        verticalContentSpacing: 12,
        titleFont: .title2.weight(.semibold),
        metadataFont: .headline.weight(.regular),
        cornerRadius: 20,
    )

    let density: CardDensityPreference
    let thumbnailSize: CGSize
    let contentPadding: CGFloat
    let interItemSpacing: CGFloat
    let verticalContentSpacing: CGFloat
    let titleFont: Font
    let metadataFont: Font
    let cornerRadius: CGFloat

    var cardWidth: CGFloat { thumbnailSize.width + (contentPadding * 2) }

}
#endif
