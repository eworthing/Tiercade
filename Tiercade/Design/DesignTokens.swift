//
//  DesignTokens.swift
//  Tiercade
//
//  Created automatically by tooling
//

import SwiftUI

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
    internal init(designHex: String) {
        self = ColorUtilities.color(hex: designHex)
    }

    /// Create a dynamic color that adapts to appearance changes using SwiftUI's shape style system.
    internal static func dynamic(light: String, dark: String) -> Color {
        Color(DynamicDesignColor(lightHex: light, darkHex: dark))
    }
}

// Design tokens
internal enum Palette {
    // Use dynamic tokens so ThemePreference / ColorScheme toggles map correctly
    internal static let bg      = Color.dynamic(light: "#FFFFFF", dark: "#0B0F14")
    internal static let surface = Color.dynamic(light: "#F8FAFC", dark: "#0F141A")
    internal static let surfHi  = Color.dynamic(light: "#00000008", dark: "#FFFFFF14")
    internal static let appBackground = Color.dynamic(light: "#F5F7FA", dark: "#0E1114")
    internal static let cardBackground = Color.dynamic(light: "#FFFFFF", dark: "#192028")
    internal static let stroke = Color.dynamic(light: "#00000010", dark: "#FFFFFF14")
    internal static let text    = Color.dynamic(light: "#111827", dark: "#E8EDF2")
    internal static let textDim = Color.dynamic(light: "#6B7280", dark: "#FFFFFFB8")
    internal static let cardText = Color.dynamic(light: "#0E1114", dark: "#FFFFFFE6")
    internal static let cardTextDim = Color.dynamic(light: "#4B5563", dark: "#FFFFFFA6")
    internal static let textDisabled = Color.dynamic(light: "#9CA3AF", dark: "#FFFFFF66")
    internal static let textOnAccent = Color.dynamic(light: "#FFFFFF", dark: "#FFFFFFD6")
    internal static let brand   = Color(designHex: "#3B82F6")
    private static let defaultTierColor = Color(designHex: "#6B7280")
    private static let unrankedTierColor = Color(designHex: "#94A3B8")

    // Tier accents as Colors
    internal static let tierColors: [String: Color] = [
        "S": Color(designHex: "#E11D48"),
        "A": Color(designHex: "#F59E0B"),
        "B": Color(designHex: "#22C55E"),
        "C": Color(designHex: "#06B6D4"),
        "D": Color(designHex: "#3B82F6"),
        "F": defaultTierColor,
        "UNRANKED": unrankedTierColor
    ]

    internal static func tierColor(_ tier: String) -> Color {
        let normalized = tier.lowercased()
        if normalized == "unranked" { return unrankedTierColor }
        return tierColors[tier.uppercased()] ?? defaultTierColor
    }

    /// State-driven tier color lookup with fallback to static colors
    /// Enables custom tier colors while maintaining SABCDF defaults
    internal static func tierColor(_ tier: String, from stateColors: [String: String]) -> Color {
        // Check state colors first (custom tier colors)
        if let hex = stateColors[tier] {
            return ColorUtilities.color(hex: hex)
        }

        // Fallback to static colors (SABCDF defaults)
        if tier.lowercased() == "unranked" { return unrankedTierColor }
        return tierColors[tier.uppercased()] ?? defaultTierColor
    }
}

internal enum Metrics {
    internal static let grid: CGFloat = 8
    internal static let rSm: CGFloat = 8
    internal static let rMd: CGFloat = 12
    internal static let rLg: CGFloat = 16
    internal static let cardMin = CGSize(width: 140, height: 180)
    internal static let paneLeft: CGFloat = 280
    internal static let paneRight: CGFloat = 320
    internal static let toolbarH: CGFloat = 56

    // Semantic spacing tokens (grid multipliers)
    internal static let spacingXS: CGFloat = grid       // 8pt
    internal static let spacingSm: CGFloat = grid * 2   // 16pt
    internal static let spacingMd: CGFloat = grid * 3   // 24pt
    internal static let spacingLg: CGFloat = grid * 4   // 32pt
    internal static let spacingXL: CGFloat = grid * 5   // 40pt

    // Component-specific spacing
    internal static let cardPadding: CGFloat = grid * 3         // 24pt
    internal static let sectionSpacing: CGFloat = grid * 4      // 32pt
    internal static let overlayPadding: CGFloat = grid * 5      // 40pt (iOS/macOS)

    // Toolbar button & icon sizing
    #if os(tvOS)
    internal static let toolbarButtonSize: CGFloat = 48
    internal static let toolbarIconSize: CGFloat = 36
    #else
    internal static let toolbarButtonSize: CGFloat = 44
    internal static let toolbarIconSize: CGFloat = 24
    #endif
}

// MARK: - Scaled Layout Dimensions

internal enum ScaledDimensions {
    #if os(tvOS)
    // HeadToHead candidate cards
    internal static let progressDialSize: CGFloat = 150
    internal static let candidateCardWidth: CGFloat = 260
    internal static let candidateThumbnailHeight: CGFloat = 340
    internal static let candidateCardMinWidth: CGFloat = 360
    internal static let candidateCardMaxWidth: CGFloat = 520
    internal static let candidateCardMinHeight: CGFloat = 280
    internal static let passTileSize: CGFloat = 240
    internal static let buttonMinWidthSmall: CGFloat = 220
    internal static let buttonMinWidthLarge: CGFloat = 260
    internal static let textContentMaxWidth: CGFloat = 520

    // Overlay dimensions
    internal static let overlayMaxWidth: CGFloat = 1200
    internal static let overlayMaxHeight: CGFloat = 900
    internal static let sheetMaxWidth: CGFloat = 800
    internal static let formFieldWidth: CGFloat = 360
    internal static let colorPreviewWidth: CGFloat = 480
    internal static let actionButtonWidth: CGFloat = 280
    #else
    // HeadToHead candidate cards
    internal static let progressDialSize: CGFloat = 100
    internal static let candidateCardWidth: CGFloat = 200
    internal static let candidateThumbnailHeight: CGFloat = 260
    internal static let candidateCardMinWidth: CGFloat = 280
    internal static let candidateCardMaxWidth: CGFloat = 400
    internal static let candidateCardMinHeight: CGFloat = 220
    internal static let passTileSize: CGFloat = 200
    internal static let buttonMinWidthSmall: CGFloat = 180
    internal static let buttonMinWidthLarge: CGFloat = 210
    internal static let textContentMaxWidth: CGFloat = 420

    // Overlay dimensions
    internal static let overlayMaxWidth: CGFloat = 700
    internal static let overlayMaxHeight: CGFloat = 720
    internal static let sheetMaxWidth: CGFloat = 600
    internal static let formFieldWidth: CGFloat = 280
    internal static let colorPreviewWidth: CGFloat = 320
    internal static let actionButtonWidth: CGFloat = 200
    #endif
}

internal enum TypeScale {
    #if os(tvOS)
    internal static let h1 = Font.system(size: 96, design: .default).weight(.heavy)
    internal static let h2 = Font.largeTitle.weight(.bold)
    internal static let h3 = Font.title.weight(.semibold)
    internal static let body = Font.title3
    internal static let bodySmall = Font.callout
    internal static let label = Font.body
    internal static let caption = Font.caption
    internal static let footnote = Font.footnote
    internal static let metadata = Font.title3.weight(.semibold)

    internal enum IconScale {
        internal static let small: Image.Scale = .medium
        internal static let medium: Image.Scale = .large
        internal static let large: Image.Scale = .large
    }
    #else
    internal static let h1 = Font.system(size: 48, design: .default).weight(.heavy)
    internal static let h2 = Font.title.weight(.semibold)
    internal static let h3 = Font.title2.weight(.semibold)
    internal static let body = Font.body
    internal static let bodySmall = Font.callout
    internal static let label = Font.caption
    internal static let caption = Font.caption2.weight(.medium)
    internal static let footnote = Font.footnote.weight(.regular)
    internal static let metadata = Font.subheadline.weight(.semibold)

    internal enum IconScale {
        internal static let small: Image.Scale = .small
        internal static let medium: Image.Scale = .medium
        internal static let large: Image.Scale = .large
    }
    #endif
}

internal enum Motion {
    internal static let fast = Animation.easeOut(duration: 0.12)
    internal static let focus = Animation.easeOut(duration: 0.15)
    internal static let emphasis = Animation.easeOut(duration: 0.20)
    internal static let spring = Animation.spring(response: 0.30, dampingFraction: 0.8)
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
    internal static let analyticsHero = Font.system(size: platformSize(tv: 72, other: 48), weight: .bold)
    internal static let analyticsTitle = Font.system(size: platformSize(tv: 48, other: 32), weight: .bold)
    internal static let analyticsSubtitle = Font.system(size: platformSize(tv: 36, other: 24), weight: .regular)
    internal static let analyticsSection = Font.system(size: platformSize(tv: 32, other: 22), weight: .semibold)
    internal static let analyticsBody = Font.system(size: platformSize(tv: 28, other: 18), weight: .regular)
    internal static let analyticsCaption = Font.system(size: platformSize(tv: 24, other: 16), weight: .regular)
    internal static let analyticsBadge = Font.system(size: platformSize(tv: 22, other: 14), weight: .semibold)

    // Wizard/overlay typography
    internal static let wizardIcon = Font.system(size: platformSize(tv: 60, other: 40))
    internal static let wizardTitle = Font.system(size: platformSize(tv: 48, other: 32))

    // Detail view typography
    internal static let detailHero = Font.system(size: platformSize(tv: 54, other: 36), weight: .semibold)
    internal static let detailTitle = Font.system(size: platformSize(tv: 44, other: 28), weight: .bold)

    // Card/list typography
    internal static let cardTitle = Font.system(size: platformSize(tv: 32, other: 22), weight: .medium)
    internal static let cardBody = Font.system(size: platformSize(tv: 24, other: 16), weight: .semibold)

    // Monospaced typography (color pickers, hex values)
    internal static let monoLarge = Font.system(
        size: platformSize(tv: 32, other: 18), weight: .semibold, design: .monospaced
    )
    internal static let monoBody = Font.system(size: platformSize(tv: 32, other: 16), design: .monospaced)

    // Empty state typography
    internal static let emptyStateIcon = Font.system(size: platformSize(tv: 56, other: 40))

    // Menu typography
    internal static let menuTitle = Font.system(size: platformSize(tv: 22, other: 16), weight: .semibold)
}
