//
//  VibrantDesign.swift
//  Tiercade
//
//  A vibrant, punchy HDR-friendly design system for tvOS and all targets.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color helpers (Display P3 aware)

private struct RGBA {
    let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
}

private func parseHexRGBA(_ hex: String, defaultAlpha: CGFloat = 1.0) -> RGBA {
    // Supports #RRGGBB and #RRGGBBAA
    let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var i: UInt64 = 0
    Scanner(string: s).scanHexInt64(&i)
    let r, g, b, a: UInt64
    switch s.count {
    case 8: // RRGGBBAA
        r = (i >> 24) & 0xff
        g = (i >> 16) & 0xff
        b = (i >> 8) & 0xff
        a = i & 0xff
    case 6: // RRGGBB
        r = (i >> 16) & 0xff
        g = (i >> 8) & 0xff
        b = i & 0xff
        a = UInt64(defaultAlpha * 255.0)
    default:
        return .init(r: 1, g: 1, b: 1, a: defaultAlpha)
    }
    return .init(r: CGFloat(r)/255.0, g: CGFloat(g)/255.0, b: CGFloat(b)/255.0, a: CGFloat(a)/255.0)
}

extension Color {
    /// Wide-gamut aware color from hex string in RGBA format (#RRGGBB or #RRGGBBAA).
    static func wideGamut(_ rgbaHex: String) -> Color {
        let c = parseHexRGBA(rgbaHex)
        #if canImport(UIKit)
        let dyn = UIColor { trait in
            if trait.displayGamut == .P3 {
                return UIColor(displayP3Red: c.r, green: c.g, blue: c.b, alpha: c.a)
            } else {
                return UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
            }
        }
        return Color(dyn)
        #elseif canImport(AppKit)
        if #available(macOS 10.12, *) {
            return Color(NSColor(displayP3Red: c.r, green: c.g, blue: c.b, alpha: c.a))
        } else {
            return Color(NSColor(calibratedRed: c.r, green: c.g, blue: c.b, alpha: c.a))
        }
        #else
        return Color(red: c.r, green: c.g, blue: c.b).opacity(Double(c.a))
        #endif
    }
}

// MARK: - Contrast utilities for chip text

private func srgbToLinear(_ c: CGFloat) -> CGFloat {
    return c <= 0.04045 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
}

private func relativeLuminance(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
    let R = srgbToLinear(r)
    let G = srgbToLinear(g)
    let B = srgbToLinear(b)
    return 0.2126 * R + 0.7152 * G + 0.0722 * B
}

private func contrastRatio(lumA: CGFloat, lumB: CGFloat) -> CGFloat {
    let L1 = max(lumA, lumB)
    let L2 = min(lumA, lumB)
    return (L1 + 0.05) / (L2 + 0.05)
}

private func chipTextColor(forHex hex: String) -> Color {
    // Compute luminance of the chip color (assume sRGB for contrast calc)
    let rgba = parseHexRGBA(hex)
    let lumChip = relativeLuminance(r: rgba.r, g: rgba.g, b: rgba.b)
    // White and black luminances
    let lumWhite: CGFloat = 1.0
    let lumBlack: CGFloat = 0.0
    let crWhite = contrastRatio(lumA: lumWhite, lumB: lumChip)
    let crBlack = contrastRatio(lumA: lumChip, lumB: lumBlack)
    // Choose the text color that meets >= 4.5:1; if both, prefer higher contrast
    let whiteMeets = crWhite >= 4.5
    let blackMeets = crBlack >= 4.5
    if whiteMeets && (!blackMeets || crWhite >= crBlack) {
        return Color.wideGamut("#FFFFFFE6")
    } else if blackMeets && (!whiteMeets || crBlack > crWhite) {
        return Color.wideGamut("#000000E6")
    }
    // Neither meets: fallback to better of the two
    return crWhite >= crBlack ? Color.wideGamut("#FFFFFFE6") : Color.wideGamut("#000000E6")
}

// MARK: - Vibrant Color Tokens

extension Color {
    // Surfaces
    // Defaults baked in (OLED/HDR priority)
    static let appBackground = Color.wideGamut("#0E1114")
    static let bgElevated    = Color.wideGamut("#14181D")
    static let cardBackground = Color.wideGamut("#192028")
    static let stroke        = Color.wideGamut("#FFFFFF14")
    static let overlay       = Color.wideGamut("#0A0C10CC")

    // Content
    static let textPrimary   = Color.wideGamut("#FFFFFFE6")
    static let textSecondary = Color.wideGamut("#FFFFFFA6")
    static let textDisabled  = Color.wideGamut("#FFFFFF66")
    static let textIcon      = Color.wideGamut("#FFFFFFD6")
    static let iconBrand     = Color.wideGamut("#FFFFFFFF")

    // Tiers (Vibrant)
    static let tierS = Color.wideGamut("#FF0037")
    static let tierA = Color.wideGamut("#FFA000")
    static let tierB = Color.wideGamut("#00EC57")
    static let tierC = Color.wideGamut("#00D9FE")
    static let tierD = Color.wideGamut("#1E3A8A")
    static let tierF = Color.wideGamut("#808080")

    // Vibrant accents
    static let accentPrimary = Color.wideGamut("#2E8EFF")
    static let accentSuccess = Color.wideGamut("#34D181")
    static let accentWarning = Color.wideGamut("#FDC239")
    static let accentError   = Color.wideGamut("#E82E4E")
}

// MARK: - Tier enum

enum Tier: String, CaseIterable, Identifiable {
    case s, a, b, c, d, f

    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }
    var hex: String {
        switch self {
        case .s: return "#FF0037"
        case .a: return "#FFA000"
        case .b: return "#00EC57"
        case .c: return "#00D9FE"
        case .d: return "#1E3A8A"
        case .f: return "#808080"
        }
    }
    var color: Color {
        Color.wideGamut(hex)
    }
}

// MARK: - Tier Badge View

struct TierBadgeView: View {
    let tier: Tier
    var body: some View {
        Text(tier.letter)
            .font(.headline.weight(.bold))
            .foregroundStyle(chipTextColor(forHex: tier.hex))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tier.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel("Tier \(tier.letter)")
    }
}

// MARK: - Punchy Focus Effect

struct PunchyFocusStyle: ViewModifier {
    let tier: Tier
    var cornerRadius: CGFloat = 12
    @Environment(\.isFocused) private var isFocused: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
        // Strong, TV-friendly focus treatment: larger scale, bright dual ring, and accent glow
        let outerRing = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(tier.color.opacity(isFocused ? 0.95 : 0.0), lineWidth: 5)
        let innerRing = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 4), style: .continuous)
            .inset(by: 1)
            .stroke(Color.white.opacity(isFocused ? 0.85 : 0.0), lineWidth: 2.5)

        return content
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .shadow(color: tier.color.opacity(isFocused ? 0.55 : 0.0), radius: isFocused ? 36 : 0, x: 0, y: 0)
            .shadow(color: tier.color.opacity(isFocused ? 0.70 : 0.0), radius: isFocused ? 64 : 0, x: 0, y: 0)
            .overlay(outerRing.blur(radius: isFocused ? 0.5 : 0))
            .overlay(innerRing)
            .zIndex(isFocused ? 10 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.85, blendDuration: 0.08), value: isFocused)
        #else
        return content
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: tier.color.opacity(isFocused ? 0.22 : 0.0), radius: isFocused ? 24 : 0, x: 0, y: 0)
            .shadow(color: tier.color.opacity(isFocused ? 0.30 : 0.0), radius: isFocused ? 30 : 0, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.16 : 0.0), lineWidth: 2)
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.08), value: isFocused)
        #endif
    }
}

extension View {
    func punchyFocus(tier: Tier, cornerRadius: CGFloat = 12) -> some View {
        modifier(PunchyFocusStyle(tier: tier, cornerRadius: cornerRadius))
    }
}

// MARK: - Example Card (for previews and adoption reference)

struct VibrantCardView: View {
    var tier: Tier = .s

    var body: some View {
        Button(action: {}) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardBackground)
                    .frame(width: 180, height: 260)
                    .overlay(
                        // Poster placeholder
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 160, height: 200)
                    )

                TierBadgeView(tier: tier)
                    .padding(8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(true)
        .punchyFocus(tier: tier, cornerRadius: 12)
    }
}

#Preview("VibrantCard iOS") {
    ZStack { Color.appBackground.ignoresSafeArea(); VibrantCardView(tier: .s) }
}

#if os(tvOS)
#Preview("VibrantCard tvOS") {
    ZStack { Color.appBackground.ignoresSafeArea(); VibrantCardView(tier: .a) }
}
#endif
