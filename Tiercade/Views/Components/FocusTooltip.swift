import SwiftUI

#if os(tvOS)
/// A modifier that shows a tooltip label when the view is focused
struct FocusTooltip: ViewModifier {
    let label: String
    @Environment(\.isFocused) private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isFocused {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2),
                        )
                        .offset(y: -50)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: -10)))
                        .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
                        .zIndex(100)
                }
            }
    }
}

extension View {
    /// Shows a tooltip label when the view is focused on tvOS
    func focusTooltip(_ label: String) -> some View {
        modifier(FocusTooltip(label: label))
    }
}
#else
extension View {
    /// No-op focus tooltip fallback for non-tvOS platforms
    func focusTooltip(_: String) -> some View { self }
}
#endif
