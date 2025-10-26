//
//  Styles.swift
//  Tiercade
//

import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Metrics.grid * 1.5)
            .background(Palette.surface)
            .cornerRadius(Metrics.rLg)
            .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
            .overlay(RoundedRectangle(cornerRadius: Metrics.rLg).stroke(Color.white.opacity(0.06)))
    }
}

extension View { func card() -> some View { modifier(CardStyle()) } }

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Metrics.grid * 2)
            .background(Palette.surface)
            .cornerRadius(Metrics.rMd)
            .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
    }
}

extension View { func panel() -> some View { modifier(PanelStyle()) } }

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.label)
            .padding(.horizontal, Metrics.grid * 2).padding(.vertical, Metrics.grid * 1.25)
            .background(Palette.brand.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundColor(get(configuration.isPressed))
            .cornerRadius(Metrics.rSm)
            .shadow(color: Palette.brand.opacity(0.6), radius: 10, x: 0, y: 6)
            .animation(reduceMotion ? nil : Motion.fast, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.label)
            .padding(.horizontal, Metrics.grid * 2).padding(.vertical, Metrics.grid * 1.25)
            .background(
                isFocused
                    ? Palette.brand.opacity(0.32)
                    : Palette.surfHi.opacity(0.85)
            )
            .foregroundColor(.white)
            .cornerRadius(Metrics.rSm)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : Motion.emphasis, value: isFocused)
    }
}

struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((configuration.isPressed || isFocused) ? 1.15 : 1.0)
            .shadow(
                color: (configuration.isPressed || isFocused) ? Palette.brand.opacity(0.55) : Color.black.opacity(0.1),
                radius: (configuration.isPressed || isFocused) ? 20 : 6,
                x: 0,
                y: (configuration.isPressed || isFocused) ? 12 : 4
            )
            .animation(reduceMotion ? nil : Motion.emphasis, value: configuration.isPressed || isFocused)
    }
}

private func get(_ isPressed: Bool) -> Color {
    #if os(tvOS)
    return isPressed ? .black : .white
    #else
    return .white
    #endif
}

struct TVRemoteButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case list
    }

    var role: Role = .primary
    @Environment(\.isFocused) private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let palette = palette(for: role, isPressed: configuration.isPressed, isFocused: isFocused)
        let scale = scale(for: configuration.isPressed, isFocused: isFocused)
        let borderWidth = isFocused ? palette.focusedBorderWidth : palette.baseBorderWidth
        let animationFocus = reduceMotion ? nil : Motion.focus
        let animationPress = reduceMotion ? nil : Motion.fast

        let baseView = configuration.label
            .font(font(for: role))
            .frame(maxWidth: role == .list ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, horizontalPadding(for: role))
            .padding(.vertical, verticalPadding(for: role))
            .foregroundStyle(palette.foreground)
            .contentShape(Capsule())

        return baseView
            .glassEffect(Glass.regular.tint(palette.tint).interactive(), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(palette.border, lineWidth: borderWidth)
            )
            .shadow(
                color: palette.shadow,
                radius: palette.shadowRadius(isFocused: isFocused),
                x: 0,
                y: palette.shadowYOffset(isFocused: isFocused)
            )
            .scaleEffect(scale)
            .animation(animationFocus, value: isFocused)
            .animation(animationPress, value: configuration.isPressed)
    }

    private func font(for role: Role) -> Font {
        switch role {
        case .primary: return .title3.weight(.semibold)
        case .secondary: return .headline.weight(.semibold)
        case .list: return .body.weight(.semibold)
        }
    }

    private func horizontalPadding(for role: Role) -> CGFloat {
        switch role {
        case .primary: return 26
        case .secondary: return 22
        case .list: return 20
        }
    }

    private func verticalPadding(for role: Role) -> CGFloat {
        switch role {
        case .primary: return 14
        case .secondary: return 12
        case .list: return 10
        }
    }

    private func palette(for role: Role, isPressed: Bool, isFocused: Bool) -> TVGlassButtonPalette {
        switch role {
        case .primary:
            return TVGlassButtonPalette(
                tint: Color.white.opacity(min(0.26 + boost(isPressed, isFocused), 0.48)),
                border: Color.white.opacity(isFocused ? 0.92 : 0.5),
                foreground: .white,
                shadow: Color.white.opacity(isFocused ? 0.32 : 0.0),
                baseBorderWidth: 1.6,
                focusedBorderWidth: 3.0,
                shadowRadiusFocused: 18,
                shadowYOffsetFocused: 4
            )
        case .secondary:
            return TVGlassButtonPalette(
                tint: Color.white.opacity(min(0.18 + boost(isPressed, isFocused) * 0.85, 0.34)),
                border: Color.white.opacity(isFocused ? 0.7 : 0.38),
                foreground: .white,
                shadow: Color.white.opacity(isFocused ? 0.24 : 0.0),
                baseBorderWidth: 1.4,
                focusedBorderWidth: 2.6,
                shadowRadiusFocused: 14,
                shadowYOffsetFocused: 3
            )
        case .list:
            return TVGlassButtonPalette(
                tint: Color.white.opacity(min(0.16 + boost(isPressed, isFocused) * 0.75, 0.28)),
                border: Color.white.opacity(isFocused ? 0.52 : 0.28),
                foreground: .white,
                shadow: Color.white.opacity(isFocused ? 0.18 : 0.0),
                baseBorderWidth: 1.2,
                focusedBorderWidth: 2.4,
                shadowRadiusFocused: 10,
                shadowYOffsetFocused: 2
            )
        }
    }

    private func scale(for isPressed: Bool, isFocused: Bool) -> CGFloat {
        if isPressed { return 0.97 }
        if isFocused { return 1.06 }
        return 1.0
    }

    private func boost(_ isPressed: Bool, _ isFocused: Bool) -> Double {
        (isFocused ? 0.12 : 0.0) + (isPressed ? 0.08 : 0.0)
    }
}

extension ButtonStyle where Self == TVRemoteButtonStyle {
    static func tvRemote(_ role: TVRemoteButtonStyle.Role = .primary) -> TVRemoteButtonStyle {
        TVRemoteButtonStyle(role: role)
    }
}

private struct TVGlassButtonPalette {
    let tint: Color
    let border: Color
    let foreground: Color
    let shadow: Color
    let baseBorderWidth: CGFloat
    let focusedBorderWidth: CGFloat
    let shadowRadiusFocused: CGFloat
    let shadowYOffsetFocused: CGFloat

    func shadowRadius(isFocused: Bool) -> CGFloat {
        isFocused ? shadowRadiusFocused : 0
    }

    func shadowYOffset(isFocused: Bool) -> CGFloat {
        isFocused ? shadowYOffsetFocused : 0
    }
}
