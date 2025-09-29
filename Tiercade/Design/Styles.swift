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
