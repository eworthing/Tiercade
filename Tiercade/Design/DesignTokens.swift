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
    init(hex: String) {
        #if canImport(UIKit)
        self = Color(PlatformColor(hex: hex))
        #elseif canImport(AppKit)
        self = Color(PlatformColor(hex: hex))
        #else
        self = Color.black
        #endif
    }

    /// Create a dynamic color that adapts to light/dark appearance when running on platforms that support dynamic UIColor/NSColor.
    static func dynamic(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        let color = UIColor { trait in
            return trait.userInterfaceStyle == .light ? PlatformColor(hex: light) : PlatformColor(hex: dark)
        }
        return Color(color)
        #elseif canImport(AppKit)
        // NSColor with dynamic provider
        let dynamic = PlatformColor(name: nil, dynamicProvider: { appearance in
            // Choose a color based on appearance (aqua == light, darkAqua == dark)
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? PlatformColor(hex: light) : PlatformColor(hex: dark)
        })
        return Color(dynamic)
        #else
        return Color(hex: dark)
        #endif
    }
}

extension PlatformColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var i: UInt64 = 0
        Scanner(string: s).scanHexInt64(&i)
        let a, r, g, b: UInt64
        if s.count == 8 {
            a = (i >> 24) & 0xff
            r = (i >> 16) & 0xff
            g = (i >> 8) & 0xff
            b = i & 0xff
        } else {
            a = 255
            r = (i >> 16) & 0xff
            g = (i >> 8) & 0xff
            b = i & 0xff
        }
        #if canImport(UIKit)
        self.init(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: CGFloat(a)/255.0)
        #elseif canImport(AppKit)
        self.init(calibratedRed: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: CGFloat(a)/255.0)
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
    static let brand   = Color(hex: "#3B82F6")

    // Tier accents as Colors
    static let tierColors: [String: Color] = [
        "S": Color(hex: "#E11D48"),
        "A": Color(hex: "#F59E0B"),
        "B": Color(hex: "#22C55E"),
        "C": Color(hex: "#06B6D4"),
        "D": Color(hex: "#3B82F6"),
        "F": Color(hex: "#6B7280")
    ]

    static func tierColor(_ tier: String) -> Color {
        tierColors[tier] ?? Color(hex: "#6B7280")
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
    static let h2 = Font.title.weight(.semibold)
    static let h3 = Font.title2.weight(.semibold)
    static let body = Font.body
    static let label = Font.caption
}
