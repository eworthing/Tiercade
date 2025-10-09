import SwiftUI

// MARK: - Liquid Glass helpers with graceful fallbacks

private struct TVGlassRoundedModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *) {
            if reduceTransparency {
                content.background(.thickMaterial, in: shape)
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
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
        if #available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *) {
            if reduceTransparency {
                content.background(.thickMaterial, in: Capsule())
            } else {
                content.glassEffect(.regular.interactive(), in: Capsule())
            }
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct TVGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        let base = configuration.label
            .scaleEffect(isFocused && !reduceMotion ? 1.05 : 1.0)

        return Group {
            if #available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *) {
                base
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
            } else {
                base
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(
                        color: isFocused ? .white.opacity(0.18) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: isFocused ? 4 : 0
                    )
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.22), value: isFocused)
    }
}

extension ButtonStyle where Self == TVGlassButtonStyle {
    static var tvGlass: TVGlassButtonStyle { TVGlassButtonStyle() }
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
    if #available(tvOS 26.0, iOS 26.0, macOS 15.0, macCatalyst 26.0, *) {
        if let spacing {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            GlassEffectContainer(content: content)
        }
    } else {
        if let spacing {
            VStack(spacing: spacing, content: content)
        } else {
            VStack(content: content)
        }
    }
}
