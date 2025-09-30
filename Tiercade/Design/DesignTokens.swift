//
//  DesignTokens.swift
//  Tiercade
//
//  Created automatically by tooling
//

import SwiftUI

// Cross-platform platform color alias
#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#else
public typealias PlatformColor = Color
#endif

extension Color {
    init(designHex: String) {
        #if canImport(UIKit)
        self = Color(PlatformColor(hex: designHex))
        #elseif canImport(AppKit)
        self = Color(PlatformColor(hex: designHex))
        #else
        self = Color.black
        #endif
    }

    /// Create a dynamic color that adapts to appearance changes on platforms
    /// that support dynamic UIColor/NSColor.
    static func dynamic(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        let color = UIColor { trait in
            let provider = trait.userInterfaceStyle == .light
                ? PlatformColor(hex: light)
                : PlatformColor(hex: dark)
            return provider
        }
        return Color(color)
        #elseif canImport(AppKit)
        // NSColor with dynamic provider
        let dynamic = PlatformColor(name: nil, dynamicProvider: { appearance in
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? PlatformColor(hex: light) : PlatformColor(hex: dark)
        })
        return Color(dynamic)
        #else
        // On platforms without dynamic providers, prefer dark by default
        return Color(hex: dark) ?? .black
        #endif
    }
}

extension PlatformColor {
    /// Convenience initializer for hex colors (uses ColorUtilities for consistency)
    convenience init(hex: String) {
        let components = ColorUtilities.parseHex(hex)
        #if canImport(UIKit)
        self.init(
            red: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
        #elseif canImport(AppKit)
        self.init(
            calibratedRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
        #else
        self.init()
        #endif
    }
}

// Design tokens
enum Palette {
    // Use dynamic tokens so ThemePreference / ColorScheme toggles map correctly
    static let bg      = Color.dynamic(light: "#FFFFFF", dark: "#0B0F14")
    static let surface = Color.dynamic(light: "#F8FAFC", dark: "#0F141A")
    static let surfHi  = Color.dynamic(light: "#00000008", dark: "#FFFFFF14")
    static let text    = Color.dynamic(light: "#111827", dark: "#E8EDF2")
    static let textDim = Color.dynamic(light: "#6B7280", dark: "#FFFFFFB8")
    static let brand   = Color(designHex: "#3B82F6")
    private static let defaultTierColor = Color(designHex: "#6B7280")
    private static let unrankedTierColor = Color(designHex: "#94A3B8")

    // Tier accents as Colors
    static let tierColors: [String: Color] = [
        "S": Color(designHex: "#E11D48"),
        "A": Color(designHex: "#F59E0B"),
        "B": Color(designHex: "#22C55E"),
        "C": Color(designHex: "#06B6D4"),
        "D": Color(designHex: "#3B82F6"),
        "F": defaultTierColor,
        "UNRANKED": unrankedTierColor
    ]

    static func tierColor(_ tier: String) -> Color {
        let normalized = tier.lowercased()
        if normalized == "unranked" { return unrankedTierColor }
        return tierColors[tier.uppercased()] ?? defaultTierColor
    }
}

enum Metrics {
    static let grid: CGFloat = 8
    static let rSm: CGFloat = 8
    static let rMd: CGFloat = 12
    static let rLg: CGFloat = 16
    static let cardMin = CGSize(width: 140, height: 180)
    static let paneLeft: CGFloat = 280
    static let paneRight: CGFloat = 320
    static let toolbarH: CGFloat = 56
}

enum TypeScale {
    // Use dynamic, semantic text styles so SwiftUI can scale them for Accessibility / Dynamic Type
    #if os(tvOS)
    static let h2 = Font.largeTitle.weight(.bold)
    static let h3 = Font.title.weight(.semibold)
    static let body = Font.title3
    static let label = Font.body
    #else
    static let h2 = Font.title.weight(.semibold)
    static let h3 = Font.title2.weight(.semibold)
    static let body = Font.body
    static let label = Font.caption
    #endif
}
