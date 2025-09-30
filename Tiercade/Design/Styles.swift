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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.label)
            .padding(.horizontal, Metrics.grid * 2).padding(.vertical, Metrics.grid * 1.25)
            .background(Palette.brand.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundColor(get(configuration.isPressed))
            .cornerRadius(Metrics.rSm)
            .shadow(color: Palette.brand.opacity(0.6), radius: 10, x: 0, y: 6)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.label)
            .padding(.horizontal, Metrics.grid * 2).padding(.vertical, Metrics.grid * 1.25)
            .background(isFocused ? Color.blue.opacity(0.3) : Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(Metrics.rSm)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect((configuration.isPressed || isFocused) ? 1.15 : 1.0)
            .shadow(
                color: (configuration.isPressed || isFocused) ? .blue.opacity(0.6) : .black.opacity(0.1),
                radius: (configuration.isPressed || isFocused) ? 20 : 6,
                x: 0,
                y: (configuration.isPressed || isFocused) ? 12 : 4
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed || isFocused)
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

    func makeBody(configuration: Configuration) -> some View {
        let colors = palette(for: role, isPressed: configuration.isPressed, isFocused: isFocused)
        let cornerRadius: CGFloat = role == .list ? 22 : 18

        return configuration.label
            .font(font(for: role))
            .frame(maxWidth: role == .list ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, horizontalPadding(for: role))
            .padding(.vertical, verticalPadding(for: role))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(colors.border, lineWidth: isFocused ? 3 : 1.5)
                    )
            )
            .foregroundColor(colors.foreground)
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

    private func palette(for role: Role, isPressed: Bool, isFocused: Bool) -> TVRemoteButtonColors {
        let baseOpacity: Double = isFocused ? 0.35 : 0.25
        switch role {
        case .primary:
            return TVRemoteButtonColors(
                background: Color.white.opacity(isPressed ? 0.45 : baseOpacity),
                border: Color.white.opacity(isFocused ? 0.9 : 0.55),
                foreground: .white
            )
        case .secondary:
            return TVRemoteButtonColors(
                background: Color.white.opacity(isPressed ? 0.25 : 0.18),
                border: Color.white.opacity(isFocused ? 0.65 : 0.4),
                foreground: .white
            )
        case .list:
            return TVRemoteButtonColors(
                background: Color.white.opacity(isPressed ? 0.22 : 0.15),
                border: Color.white.opacity(isFocused ? 0.5 : 0.25),
                foreground: .white
            )
        }
    }
}

extension ButtonStyle where Self == TVRemoteButtonStyle {
    static func tvRemote(_ role: TVRemoteButtonStyle.Role = .primary) -> TVRemoteButtonStyle {
        TVRemoteButtonStyle(role: role)
    }
}

private struct TVRemoteButtonColors {
    let background: Color
    let border: Color
    let foreground: Color
}
