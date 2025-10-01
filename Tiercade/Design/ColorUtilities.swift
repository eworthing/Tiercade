//
//  ColorUtilities.swift
//  Tiercade
//
//  Consolidated color parsing and contrast utilities
//  Eliminates duplication across DesignTokens, VibrantDesign, and TierRow
//

import SwiftUI
import CoreGraphics

/// Centralized color utilities for hex parsing, luminance calculations, and contrast ratios
enum ColorUtilities {
    /// RGBA color components
    struct RGBAComponents: Sendable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    /// Parse hex color string supporting #RGB, #RRGGBB, #RRGGBBAA formats
    /// - Parameters:
    ///   - hex: Hex color string with optional # prefix
    ///   - defaultAlpha: Alpha value to use if not specified in hex (0.0-1.0)
    /// - Returns: Normalized RGBA components (0.0-1.0 range)
    static func parseHex(_ hex: String, defaultAlpha: CGFloat = 1.0) -> RGBAComponents {
        let sanitized = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r: UInt64
        let g: UInt64
        let b: UInt64
        let a: UInt64

        switch sanitized.count {
        case 3:  // #RGB → expand to #RRGGBB
            r = (value >> 8 & 0xF) * 17
            g = (value >> 4 & 0xF) * 17
            b = (value & 0xF) * 17
            a = 255
        case 6:  // #RRGGBB
            r = value >> 16 & 0xFF
            g = value >> 8 & 0xFF
            b = value & 0xFF
            a = UInt64(defaultAlpha * 255)
        case 8:  // #RRGGBBAA
            r = value >> 24 & 0xFF
            g = value >> 16 & 0xFF
            b = value >> 8 & 0xFF
            a = value & 0xFF
        default:
            r = 255
            g = 255
            b = 255
            a = UInt64(defaultAlpha * 255)
        }

        return RGBAComponents(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }

    /// Calculate WCAG 2.1 relative luminance
    /// - Parameter components: RGBA color components
    /// - Returns: Relative luminance value (0.0-1.0)
    static func luminance(_ components: RGBAComponents) -> CGFloat {
        func linearize(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(components.red)
            + 0.7152 * linearize(components.green)
            + 0.0722 * linearize(components.blue)
    }

    /// Calculate WCAG contrast ratio between two luminance values
    /// - Parameters:
    ///   - lum1: First luminance value
    ///   - lum2: Second luminance value
    /// - Returns: Contrast ratio (1.0-21.0, where 21 is maximum contrast)
    static func contrastRatio(lum1: CGFloat, lum2: CGFloat) -> CGFloat {
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Choose white or black text color for optimal contrast on given background
    /// - Parameter backgroundHex: Background color as hex string
    /// - Returns: White or black color with 90% opacity for optimal readability
    static func accessibleTextColor(onBackground backgroundHex: String) -> Color {
        let bg = parseHex(backgroundHex)
        let bgLum = luminance(bg)
        let whiteContrast = contrastRatio(lum1: 1.0, lum2: bgLum)
        let blackContrast = contrastRatio(lum1: bgLum, lum2: 0.0)

        // Prefer white text if it has better or equal contrast
        return whiteContrast >= blackContrast
            ? Color.white.opacity(0.9)
            : Color.black.opacity(0.9)
    }

    /// Create a wide-gamut aware Color from hex string
    /// - Parameters:
    ///   - hex: Hex color string (#RRGGBB or #RRGGBBAA)
    ///   - alpha: Optional alpha override (0.0-1.0)
    /// - Returns: SwiftUI Color with Display P3 support on capable devices
    static func color(hex: String, alpha: CGFloat = 1.0) -> Color {
        let components = parseHex(hex, defaultAlpha: alpha)
        let colorComponents: [CGFloat] = [components.red, components.green, components.blue, components.alpha]

        if let displayP3 = CGColorSpace(name: CGColorSpace.displayP3),
           let cgColor = CGColor(colorSpace: displayP3, components: colorComponents) {
            return Color(cgColor: cgColor)
        }

        if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
           let cgColor = CGColor(colorSpace: srgb, components: colorComponents) {
            return Color(cgColor: cgColor)
        }

        return Color(
            red: Double(components.red),
            green: Double(components.green),
            blue: Double(components.blue),
            opacity: Double(components.alpha)
        )
    }
}

// MARK: - Color Extensions

// Note: Color(hex:) extension is defined in SharedCore.swift for backward compatibility
// This extension provides the wideGamut static method as a convenience wrapper
