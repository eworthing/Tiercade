import SwiftUI

// MARK: - DynamicDesignColor

private struct DynamicDesignColor: ShapeStyle, Hashable {
    fileprivate typealias Resolved = Color.Resolved

    fileprivate let lightHex: String
    fileprivate let darkHex: String

    fileprivate func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let preferredHex = environment.colorScheme == .dark ? darkHex : lightHex
        return ColorUtilities.color(hex: preferredHex).resolve(in: environment)
    }
}

extension Color {
    init(designHex: String) {
        self = ColorUtilities.color(hex: designHex)
    }

    /// Create a dynamic color that adapts to appearance changes using SwiftUI's shape style system.
    static func dynamic(light: String, dark: String) -> Color {
        Color(DynamicDesignColor(lightHex: light, darkHex: dark))
    }
}

// MARK: - Palette

// Design tokens
enum Palette {

    // MARK: Internal

    // Use dynamic tokens so ThemePreference / ColorScheme toggles map correctly
    static let bg = Color.dynamic(light: "#FFFFFF", dark: "#0B0F14")
    static let surface = Color.dynamic(light: "#F8FAFC", dark: "#0F141A")
    static let surfHi = Color.dynamic(light: "#00000008", dark: "#FFFFFF14")
    static let appBackground = Color.dynamic(light: "#F5F7FA", dark: "#0E1114")
    static let cardBackground = Color.dynamic(light: "#FFFFFF", dark: "#192028")
    static let stroke = Color.dynamic(light: "#00000010", dark: "#FFFFFF14")
    static let text = Color.dynamic(light: "#111827", dark: "#E8EDF2")
    static let textDim = Color.dynamic(light: "#6B7280", dark: "#FFFFFFB8")
    static let cardText = Color.dynamic(light: "#0E1114", dark: "#FFFFFFE6")
    static let cardTextDim = Color.dynamic(light: "#4B5563", dark: "#FFFFFFA6")
    static let textDisabled = Color.dynamic(light: "#9CA3AF", dark: "#FFFFFF66")
    static let textOnAccent = Color.dynamic(light: "#FFFFFF", dark: "#FFFFFFD6")
    static let brand = Color(designHex: "#3B82F6")
    // Tier accents as Colors
    static let tierColors: [String: Color] = [
        "S": Color(designHex: "#E11D48"),
        "A": Color(designHex: "#F59E0B"),
        "B": Color(designHex: "#22C55E"),
        "C": Color(designHex: "#06B6D4"),
        "D": Color(designHex: "#3B82F6"),
        "F": defaultTierColor,
        "UNRANKED": unrankedTierColor,
    ]

    static func tierColor(_ tier: String) -> Color {
        let normalized = tier.lowercased()
        if normalized == "unranked" {
            return unrankedTierColor
        }
        return tierColors[tier.uppercased()] ?? defaultTierColor
    }

    /// State-driven tier color lookup with fallback to static colors
    /// Enables custom tier colors while maintaining SABCDF defaults
    static func tierColor(_ tier: String, from stateColors: [String: String]) -> Color {
        // Check state colors first (custom tier colors)
        if let hex = stateColors[tier] {
            return ColorUtilities.color(hex: hex)
        }

        // Fallback to static colors (SABCDF defaults)
        if tier.lowercased() == "unranked" {
            return unrankedTierColor
        }
        return tierColors[tier.uppercased()] ?? defaultTierColor
    }

    // MARK: Private

    private static let defaultTierColor = Color(designHex: "#6B7280")
    private static let unrankedTierColor = Color(designHex: "#94A3B8")

}

// MARK: - Metrics

enum Metrics {
    static let grid: CGFloat = 8
    static let rSm: CGFloat = 8
    static let rMd: CGFloat = 12
    static let rLg: CGFloat = 16
    static let cardMin = CGSize(width: 140, height: 180)
    static let paneLeft: CGFloat = 280
    static let paneRight: CGFloat = 320
    static let toolbarH: CGFloat = 56

    // Semantic spacing tokens (grid multipliers)
    static let spacingXS: CGFloat = grid // 8pt
    static let spacingSm: CGFloat = grid * 2 // 16pt
    static let spacingMd: CGFloat = grid * 3 // 24pt
    static let spacingLg: CGFloat = grid * 4 // 32pt
    static let spacingXL: CGFloat = grid * 5 // 40pt

    // Component-specific spacing
    static let cardPadding: CGFloat = grid * 3 // 24pt
    static let sectionSpacing: CGFloat = grid * 4 // 32pt
    static let overlayPadding: CGFloat = grid * 5 // 40pt (iOS/macOS)

    // Toolbar button & icon sizing
    #if os(tvOS)
    static let toolbarButtonSize: CGFloat = 48
    static let toolbarIconSize: CGFloat = 36
    #else
    static let toolbarButtonSize: CGFloat = 44
    static let toolbarIconSize: CGFloat = 24
    #endif
}

// MARK: - ScaledDimensions

enum ScaledDimensions {
    #if os(tvOS)
    // HeadToHead candidate cards
    static let progressDialSize: CGFloat = 150
    static let candidateCardWidth: CGFloat = 260
    static let candidateThumbnailHeight: CGFloat = 340
    static let candidateCardMinWidth: CGFloat = 360
    static let candidateCardMaxWidth: CGFloat = 520
    static let candidateCardMinHeight: CGFloat = 280
    static let passTileSize: CGFloat = 240
    static let buttonMinWidthSmall: CGFloat = 220
    static let buttonMinWidthLarge: CGFloat = 260
    static let textContentMaxWidth: CGFloat = 520

    // Overlay dimensions
    static let overlayMaxWidth: CGFloat = 1200
    static let overlayMaxHeight: CGFloat = 900
    static let sheetMaxWidth: CGFloat = 800
    static let formFieldWidth: CGFloat = 360
    static let colorPreviewWidth: CGFloat = 480
    static let actionButtonWidth: CGFloat = 280
    #else
    // HeadToHead candidate cards
    static let progressDialSize: CGFloat = 100
    static let candidateCardWidth: CGFloat = 200
    static let candidateThumbnailHeight: CGFloat = 260
    static let candidateCardMinWidth: CGFloat = 280
    static let candidateCardMaxWidth: CGFloat = 400
    static let candidateCardMinHeight: CGFloat = 220
    static let passTileSize: CGFloat = 200
    static let buttonMinWidthSmall: CGFloat = 180
    static let buttonMinWidthLarge: CGFloat = 210
    static let textContentMaxWidth: CGFloat = 420

    // Overlay dimensions
    static let overlayMaxWidth: CGFloat = 700
    static let overlayMaxHeight: CGFloat = 720
    static let sheetMaxWidth: CGFloat = 600
    static let formFieldWidth: CGFloat = 280
    static let colorPreviewWidth: CGFloat = 320
    static let actionButtonWidth: CGFloat = 200
    #endif
}

// MARK: - TypeScale

enum TypeScale {
    #if os(tvOS)
    static let h1 = Font.system(size: 96, design: .default).weight(.heavy)
    static let h2 = Font.largeTitle.weight(.bold)
    static let h3 = Font.title.weight(.semibold)
    static let body = Font.title3
    static let bodySmall = Font.callout
    static let label = Font.body
    static let caption = Font.caption
    static let footnote = Font.footnote
    static let metadata = Font.title3.weight(.semibold)

    enum IconScale {
        static let small: Image.Scale = .medium
        static let medium: Image.Scale = .large
        static let large: Image.Scale = .large
    }
    #else
    static let h1 = Font.system(size: 48, design: .default).weight(.heavy)
    static let h2 = Font.title.weight(.semibold)
    static let h3 = Font.title2.weight(.semibold)
    static let body = Font.body
    static let bodySmall = Font.callout
    static let label = Font.caption
    static let caption = Font.caption2.weight(.medium)
    static let footnote = Font.footnote.weight(.regular)
    static let metadata = Font.subheadline.weight(.semibold)

    enum IconScale {
        static let small: Image.Scale = .small
        static let medium: Image.Scale = .medium
        static let large: Image.Scale = .large
    }
    #endif
}

// MARK: - Motion

enum Motion {
    static let fast = Animation.easeOut(duration: 0.12)
    static let focus = Animation.easeOut(duration: 0.15)
    static let emphasis = Animation.easeOut(duration: 0.20)
    static let spring = Animation.spring(response: 0.30, dampingFraction: 0.8)
}

// MARK: - Extended Typography Tokens

extension TypeScale {
    // Platform-aware size helper
    private static func platformSize(tv: CGFloat, other: CGFloat) -> CGFloat {
        #if os(tvOS)
        return tv
        #else
        return other
        #endif
    }

    // Analytics typography
    static let analyticsHero = Font.system(size: platformSize(tv: 72, other: 48), weight: .bold)
    static let analyticsTitle = Font.system(size: platformSize(tv: 48, other: 32), weight: .bold)
    static let analyticsSubtitle = Font.system(size: platformSize(tv: 36, other: 24), weight: .regular)
    static let analyticsSection = Font.system(size: platformSize(tv: 32, other: 22), weight: .semibold)
    static let analyticsBody = Font.system(size: platformSize(tv: 28, other: 18), weight: .regular)
    static let analyticsCaption = Font.system(size: platformSize(tv: 24, other: 16), weight: .regular)
    static let analyticsBadge = Font.system(size: platformSize(tv: 22, other: 14), weight: .semibold)

    // Wizard/overlay typography
    static let wizardIcon = Font.system(size: platformSize(tv: 60, other: 40))
    static let wizardTitle = Font.system(size: platformSize(tv: 48, other: 32))

    // Detail view typography
    static let detailHero = Font.system(size: platformSize(tv: 54, other: 36), weight: .semibold)
    static let detailTitle = Font.system(size: platformSize(tv: 44, other: 28), weight: .bold)

    // Card/list typography
    static let cardTitle = Font.system(size: platformSize(tv: 32, other: 22), weight: .medium)
    static let cardBody = Font.system(size: platformSize(tv: 24, other: 16), weight: .semibold)

    // Monospaced typography (color pickers, hex values)
    static let monoLarge = Font.system(
        size: platformSize(tv: 32, other: 18), weight: .semibold, design: .monospaced,
    )
    static let monoBody = Font.system(size: platformSize(tv: 32, other: 16), design: .monospaced)

    // Empty state typography
    static let emptyStateIcon = Font.system(size: platformSize(tv: 56, other: 40))

    // Menu typography
    static let menuTitle = Font.system(size: platformSize(tv: 22, other: 16), weight: .semibold)
}
