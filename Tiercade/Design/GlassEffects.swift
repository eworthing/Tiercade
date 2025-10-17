import SwiftUI

// MARK: - Liquid Glass helpers with graceful fallbacks

private struct TVGlassRoundedModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: shape)
        } else {
            content.glassEffect(.regular.interactive(), in: shape)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

private struct TVGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.thickMaterial, in: Capsule())
        } else {
            content.glassEffect(.regular.interactive(), in: Capsule())
        }
    }
}

extension View {
    func tvGlassRounded(_ radius: CGFloat = 24) -> some View {
        modifier(TVGlassRoundedModifier(radius: radius))
    }

    func tvGlassCapsule() -> some View {
        modifier(TVGlassCapsuleModifier())
    }
}

@ViewBuilder
func tvGlassContainer<Content: View>(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
    if let spacing {
        GlassEffectContainer(spacing: spacing, content: content)
    } else {
        GlassEffectContainer(content: content)
    }
}
