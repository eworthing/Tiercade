import SwiftUI

// MARK: - Liquid Glass helpers (tvOS 26+)

#if swift(>=6.0)

/// Applies rounded Liquid Glass effect with accessibility fallback
@available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *)
private struct GlassRounded: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

/// Applies capsule Liquid Glass effect with accessibility fallback
@available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *)
private struct GlassCapsule: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: Capsule())
        } else {
            content.glassEffect(.regular.interactive(), in: Capsule())
        }
    }
}

/// tvOS-optimized button style with Liquid Glass and focus effects
@available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *)
struct TVGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused && !reduceMotion ? 1.05 : 1.0)
            .glassEffect(
                isFocused
                    ? Glass.regular.tint(.white.opacity(0.25)).interactive()
                    : Glass.regular.interactive(),
                in: Capsule()
            )
            .shadow(
                color: isFocused ? .white.opacity(0.28) : .clear,
                radius: isFocused ? 12 : 0,
                x: 0,
                y: isFocused ? 4 : 0
            )
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.22), value: isFocused)
    }
}

@available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *)
extension View {
    /// Applies a rounded Liquid Glass effect (default 24pt radius)
    func tvGlassRounded(_ radius: CGFloat = 24) -> some View {
        modifier(GlassRounded(radius: radius))
    }

    /// Applies a capsule Liquid Glass effect
    func tvGlassCapsule() -> some View {
        modifier(GlassCapsule())
    }
}

@available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *)
extension ButtonStyle where Self == TVGlassButtonStyle {
    /// tvOS button style with Liquid Glass and focus effects
    static var tvGlass: TVGlassButtonStyle { TVGlassButtonStyle() }
}

#else

// Fallback for pre-Swift 6.0
extension View {
    func tvGlassRounded(_ radius: CGFloat = 24) -> some View { self }
    func tvGlassCapsule() -> some View { self }
}

#endif
