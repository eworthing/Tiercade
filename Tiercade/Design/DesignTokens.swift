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
    internal static let progressDialSize: CGFloat = 150
    internal static let candidateCardMinWidth: CGFloat = 360
    internal static let candidateCardMaxWidth: CGFloat = 520
    internal static let candidateCardMinHeight: CGFloat = 280
    internal static let passTileSize: CGFloat = 240
    internal static let buttonMinWidthSmall: CGFloat = 220
    internal static let buttonMinWidthLarge: CGFloat = 260
    internal static let textContentMaxWidth: CGFloat = 520
    #else
    internal static let progressDialSize: CGFloat = 100
    internal static let candidateCardMinWidth: CGFloat = 280
    internal static let candidateCardMaxWidth: CGFloat = 400
    internal static let candidateCardMinHeight: CGFloat = 220
    internal static let passTileSize: CGFloat = 200
    internal static let buttonMinWidthSmall: CGFloat = 180
    internal static let buttonMinWidthLarge: CGFloat = 210
    internal static let textContentMaxWidth: CGFloat = 420
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
