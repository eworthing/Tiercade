//
//  VibrantDesign.swift
//  Tiercade
//
//  A vibrant, punchy HDR-friendly design system for tvOS and all targets.
//  Core surface and text colors now live in `Palette` (DesignTokens.swift); this file
//  focuses on focus effects and tier-specific helpers.
//

import SwiftUI

// MARK: - Color helpers (Display P3 aware)
// Note: Using consolidated ColorUtilities for hex parsing and contrast calculations

extension Color {
    /// Wide-gamut aware color from hex string in RGBA format (#RRGGBB or #RRGGBBAA).
    /// This is a convenience wrapper around ColorUtilities for backward compatibility.
    internal static func wideGamut(_ rgbaHex: String) -> Color {
        ColorUtilities.color(hex: rgbaHex)
    }
}

// MARK: - Contrast utilities for chip text

private func chipTextColor(forHex hex: String) -> Color {
    // Use consolidated ColorUtilities instead of duplicated logic
    ColorUtilities.accessibleTextColor(onBackground: hex)
}

// MARK: - Tier enum

internal enum Tier: String, CaseIterable, Identifiable {
    case s, a, b, c, d, f, unranked

    internal var id: String { rawValue }
    internal var letter: String { rawValue.uppercased() }
    internal var hex: String {
        switch self {
        case .s: return "#FF0037"
        case .a: return "#FFA000"
        case .b: return "#00EC57"
        case .c: return "#00D9FE"
        case .d: return "#1E3A8A"
        case .f: return "#808080"
        case .unranked: return "#6B7280"
        }
    }
    internal var color: Color {
        Color.wideGamut(hex)
    }
}

// MARK: - Tier Badge View

/// Legacy tier badge using hardcoded Tier enum (SABCDF only)
/// Prefer DynamicTierBadgeView for custom tier color support
internal struct TierBadgeView: View {
    internal let tier: Tier
    internal var body: some View {
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

/// Dynamic tier badge that respects custom tier colors and labels
internal struct DynamicTierBadgeView: View {
    internal let label: String
    internal let colorHex: String

    internal var body: some View {
        Text(label)
            .font(.headline.weight(.bold))
            .foregroundStyle(chipTextColor(forHex: colorHex))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.wideGamut(colorHex))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel("Tier \(label)")
    }
}

// MARK: - Punchy Focus Effect

internal struct PunchyFocusStyle: ViewModifier {
    internal let tier: Tier
    internal var cornerRadius: CGFloat = 12
    @Environment(\.isFocused) private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal func body(content: Content) -> some View {
        #if os(tvOS)
        // Strong, TV-friendly focus treatment: larger scale, bright dual ring, and accent glow
        let outerRing = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(tier.color.opacity(isFocused ? 0.95 : 0.0), lineWidth: 4)
        let innerRing = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 4), style: .continuous)
            .inset(by: 1)
            .stroke(Color.white.opacity(isFocused ? 0.85 : 0.0), lineWidth: 2)

        return content
            .scaleEffect(isFocused ? 1.07 : 1.0)
            .shadow(color: tier.color.opacity(isFocused ? 0.55 : 0.0), radius: isFocused ? 28 : 0, x: 0, y: 0)
            .shadow(color: tier.color.opacity(isFocused ? 0.70 : 0.0), radius: isFocused ? 52 : 0, x: 0, y: 0)
            .overlay(outerRing.blur(radius: isFocused ? 0.5 : 0))
            .overlay(innerRing)
            .zIndex(isFocused ? 10 : 0)
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #else
        return content
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: tier.color.opacity(isFocused ? 0.22 : 0.0), radius: isFocused ? 24 : 0, x: 0, y: 0)
            .shadow(color: tier.color.opacity(isFocused ? 0.30 : 0.0), radius: isFocused ? 30 : 0, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.16 : 0.0), lineWidth: 2)
            )
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #endif
    }
}

internal extension View {
    internal func punchyFocus(tier: Tier, cornerRadius: CGFloat = 12) -> some View {
        modifier(PunchyFocusStyle(tier: tier, cornerRadius: cornerRadius))
    }
}

// MARK: - Color-Based Punchy Focus Effect (for custom tier colors)

internal struct PunchyFocusStyleDynamic: ViewModifier {
    internal let color: Color
    internal var cornerRadius: CGFloat = 12
    @Environment(\.isFocused) private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal func body(content: Content) -> some View {
        #if os(tvOS)
        // Strong, TV-friendly focus treatment matching PunchyFocusStyle but with dynamic color
        let outerRing = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(color.opacity(isFocused ? 0.95 : 0.0), lineWidth: 4)
        let innerRing = RoundedRectangle(cornerRadius: max(cornerRadius - 2, 4), style: .continuous)
            .inset(by: 1)
            .stroke(Color.white.opacity(isFocused ? 0.85 : 0.0), lineWidth: 2)

        return content
            .scaleEffect(isFocused ? 1.07 : 1.0)
            .shadow(color: color.opacity(isFocused ? 0.55 : 0.0), radius: isFocused ? 28 : 0, x: 0, y: 0)
            .shadow(color: color.opacity(isFocused ? 0.70 : 0.0), radius: isFocused ? 52 : 0, x: 0, y: 0)
            .overlay(outerRing.blur(radius: isFocused ? 0.5 : 0))
            .overlay(innerRing)
            .zIndex(isFocused ? 10 : 0)
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #else
        return content
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: color.opacity(isFocused ? 0.22 : 0.0), radius: isFocused ? 24 : 0, x: 0, y: 0)
            .shadow(color: color.opacity(isFocused ? 0.30 : 0.0), radius: isFocused ? 30 : 0, x: 0, y: 0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.16 : 0.0), lineWidth: 2)
            )
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #endif
    }
}

internal extension View {
    /// Apply focus effect with a dynamic color (supports custom tier colors)
    internal func punchyFocus(color: Color, cornerRadius: CGFloat = 12) -> some View {
        modifier(PunchyFocusStyleDynamic(color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Example Card (for previews and adoption reference)

internal struct VibrantCardView: View {
    internal var tier: Tier = .s

    internal var body: some View {
        Button(action: {}, label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardBackground)
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
        })
        .buttonStyle(.plain)
        .punchyFocus(tier: tier, cornerRadius: 12)
    }
}

#Preview("VibrantCard iOS") {
    ZStack { Palette.appBackground.ignoresSafeArea(); VibrantCardView(tier: .s) }
}

#if os(tvOS)
#Preview("VibrantCard tvOS") {
    ZStack { Palette.appBackground.ignoresSafeArea(); VibrantCardView(tier: .a) }
}
#endif
