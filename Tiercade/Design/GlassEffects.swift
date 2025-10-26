import SwiftUI

// MARK: - Liquid Glass helpers with graceful fallbacks

private struct TVGlassRoundedModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    internal let radius: CGFloat

    @ViewBuilder
    internal func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: shape)
        } else {
            #if os(tvOS)
            content.glassEffect(.regular.interactive(), in: shape)
            #else
            content.background(.ultraThinMaterial, in: shape)
            #endif
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

private struct TVGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    internal func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: Capsule())
        } else {
            #if os(tvOS)
            content.glassEffect(.regular.interactive(), in: Capsule())
            #else
            content.background(.ultraThinMaterial, in: Capsule())
            #endif
        }
    }
}

extension View {
    internal func tvGlassRounded(_ radius: CGFloat = 24) -> some View {
        modifier(TVGlassRoundedModifier(radius: radius))
    }

    internal func tvGlassCapsule() -> some View {
        modifier(TVGlassCapsuleModifier())
    }
}

@MainActor @ViewBuilder
internal func tvGlassContainer<Content: View>(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
    if let spacing {
        GlassEffectContainer(spacing: spacing, content: content)
    } else {
        GlassEffectContainer(content: content)
    }
}
