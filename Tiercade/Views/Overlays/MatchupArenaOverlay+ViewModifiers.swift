import SwiftUI
import TiercadeCore

// MARK: - View Modifiers for MatchupArenaOverlay

extension View {
    func applyOverlayModifiers(namespace: Namespace.ID) -> some View {
        self
            .tvGlassRounded(40)
            #if swift(>=6.0)
            .modifier(GlassEffectModifier(namespace: namespace))
            #endif
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 36, y: 18)
            .padding(.horizontal, Metrics.grid * 2)
            .accessibilityIdentifier("MatchupOverlay_Root")
            .accessibilityElement(children: .contain)
            #if os(tvOS)
            .focusSection()
            #endif
    }

    func applyFocusModifiers(
        focusAnchor: FocusState<MatchupFocusAnchor?>.Binding,
        defaultFocus: MatchupFocusAnchor,
        onAppear: @escaping () -> Void,
        onFocusChange: @escaping (MatchupFocusAnchor?) -> Void
    ) -> some View {
        self
            .defaultFocus(focusAnchor, defaultFocus)
            .onAppear { onAppear() }
            .onChange(of: focusAnchor.wrappedValue) { _, newValue in onFocusChange(newValue) }
    }

    func applyH2HPairTracking(
        app: AppState,
        onSync: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: app.h2hPair?.0.id) { _, _ in onSync() }
            .onChange(of: app.h2hPair?.1.id) { _, _ in onSync() }
            .onChange(of: app.h2hPair == nil) { _, _ in onSync() }
            .onDisappear { onDisappear() }
    }

    #if os(tvOS)
    func applyTVOSModifiers(
        app: AppState,
        handleMove: @escaping (MoveCommandDirection) -> Void
    ) -> some View {
        self
            .onExitCommand { app.cancelH2H(fromExitCommand: true) }
            .onMoveCommand(perform: handleMove)
    }
    #else
    func applyNonTVOSModifiers(
        app: AppState,
        overlayHasFocus: FocusState<Bool>.Binding,
        handleInput: @escaping (DirectionalMove) -> Void,
        handleAction: @escaping () -> Void
    ) -> some View {
        self
            .focusable()
            .focused(overlayHasFocus)
            .onKeyPress(.upArrow) { handleInput(.up); return .handled }
            .onKeyPress(.downArrow) { handleInput(.down); return .handled }
            .onKeyPress(.leftArrow) { handleInput(.left); return .handled }
            .onKeyPress(.rightArrow) { handleInput(.right); return .handled }
            .onKeyPress(.space) { handleAction(); return .handled }
            .onKeyPress(.return) { handleAction(); return .handled }
            .onChange(of: overlayHasFocus.wrappedValue) { _, newValue in
                guard !newValue, app.h2hActive else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    if app.h2hActive {
                        overlayHasFocus.wrappedValue = true
                    }
                }
            }
            .accessibilityAddTraits(.isModal)
    }
    #endif
}

#if swift(>=6.0)
private struct GlassEffectModifier: ViewModifier {
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .glassEffectID("matchupOverlay", in: namespace)
            .glassEffectTransition(.matchedGeometry)
    }
}
#endif
