import SwiftUI

#if !os(tvOS)
struct PlatformCardLayout {
    let density: CardDensityPreference
    let cardWidth: CGFloat
    let contentPadding: CGFloat
    let interItemSpacing: CGFloat
    let rowSpacing: CGFloat
    let verticalContentSpacing: CGFloat
    let titleFont: Font
    let metadataFont: Font
    let cornerRadius: CGFloat
    let thumbnailHeight: CGFloat

    var showsText: Bool { density.showsOnCardText }

    var thumbnailSize: CGSize {
        let width = max(cardWidth - (contentPadding * 2), 60)
        return CGSize(width: width, height: thumbnailHeight)
    }

    var thumbnailCornerRadius: CGFloat {
        max(cornerRadius - 4, 6)
    }

    var gridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: cardWidth,
                    maximum: cardWidth + interItemSpacing
                ),
                spacing: interItemSpacing,
                alignment: .top
            )
        ]
    }
}

enum PlatformCardLayoutProvider {
    static func layout(
        for itemCount: Int,
        preference: CardDensityPreference,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> PlatformCardLayout {
        let effectiveDensity = resolveDensity(for: itemCount, preference: preference)
        let spec = spec(for: effectiveDensity)

        let scale: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 1.12
            #else
            switch horizontalSizeClass {
            case .some(.regular):
                return 1.04
            case .some(.compact):
                return 0.96
            default:
                return 1.0
            }
            #endif
        }()

        func scaled(_ value: CGFloat) -> CGFloat { value * scale }

        return PlatformCardLayout(
            density: effectiveDensity,
            cardWidth: scaled(spec.cardWidth),
            contentPadding: max(8, scaled(spec.contentPadding)),
            interItemSpacing: max(8, scaled(spec.interItemSpacing)),
            rowSpacing: max(8, scaled(spec.rowSpacing)),
            verticalContentSpacing: max(4, scaled(spec.verticalContentSpacing)),
            titleFont: spec.titleFont,
            metadataFont: spec.metadataFont,
            cornerRadius: scaled(spec.cornerRadius),
            thumbnailHeight: max(80, scaled(spec.thumbnailHeight))
        )
    }

    private struct LayoutSpec {
        let cardWidth: CGFloat
        let contentPadding: CGFloat
        let interItemSpacing: CGFloat
        let rowSpacing: CGFloat
        let verticalContentSpacing: CGFloat
        let cornerRadius: CGFloat
        let thumbnailHeight: CGFloat
        let titleFont: Font
        let metadataFont: Font
    }

    private static func resolveDensity(
        for itemCount: Int,
        preference: CardDensityPreference
    ) -> CardDensityPreference {
        func minDensity(_ lhs: CardDensityPreference, _ rhs: CardDensityPreference) -> CardDensityPreference {
            lhs.sizeRank <= rhs.sizeRank ? lhs : rhs
        }

        var effective = preference
        if itemCount >= 64 {
            effective = .ultraMicro
        } else if itemCount >= 48 {
            effective = minDensity(effective, .micro)
        } else if itemCount >= 36 {
            effective = minDensity(effective, .tight)
        } else if itemCount >= 24 {
            effective = minDensity(effective, .compact)
        }
        return effective
    }

    private static func spec(for density: CardDensityPreference) -> LayoutSpec {
        switch density {
        case .ultraMicro:
            return LayoutSpec(
                cardWidth: 120,
                contentPadding: 8,
                interItemSpacing: 12,
                rowSpacing: 14,
                verticalContentSpacing: 4,
                cornerRadius: 10,
                thumbnailHeight: 135,
                titleFont: .caption.weight(.semibold),
                metadataFont: .caption2.weight(.regular)
            )
        case .micro:
            return LayoutSpec(
                cardWidth: 148,
                contentPadding: 10,
                interItemSpacing: 14,
                rowSpacing: 16,
                verticalContentSpacing: 5,
                cornerRadius: 11,
                thumbnailHeight: 160,
                titleFont: .footnote.weight(.semibold),
                metadataFont: .caption.weight(.regular)
            )
        case .tight:
            return LayoutSpec(
                cardWidth: 176,
                contentPadding: 12,
                interItemSpacing: 16,
                rowSpacing: 18,
                verticalContentSpacing: 6,
                cornerRadius: 12,
                thumbnailHeight: 188,
                titleFont: .subheadline.weight(.semibold),
                metadataFont: .footnote.weight(.regular)
            )
        case .compact:
            return LayoutSpec(
                cardWidth: 204,
                contentPadding: 14,
                interItemSpacing: 18,
                rowSpacing: 20,
                verticalContentSpacing: 7,
                cornerRadius: 14,
                thumbnailHeight: 212,
                titleFont: .callout.weight(.semibold),
                metadataFont: .footnote.weight(.regular)
            )
        case .standard:
            return LayoutSpec(
                cardWidth: 232,
                contentPadding: 16,
                interItemSpacing: 20,
                rowSpacing: 22,
                verticalContentSpacing: 8,
                cornerRadius: 16,
                thumbnailHeight: 236,
                titleFont: .title3.weight(.semibold),
                metadataFont: .callout.weight(.regular)
            )
        case .expanded:
            return LayoutSpec(
                cardWidth: 260,
                contentPadding: 18,
                interItemSpacing: 22,
                rowSpacing: 24,
                verticalContentSpacing: 9,
                cornerRadius: 18,
                thumbnailHeight: 260,
                titleFont: .title2.weight(.semibold),
                metadataFont: .headline.weight(.regular)
            )
        }
    }
}
#endif
