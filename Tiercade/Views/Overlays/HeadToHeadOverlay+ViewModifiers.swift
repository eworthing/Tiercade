import SwiftUI

// MARK: - View Modifiers for HeadToHeadOverlay

internal extension View {
    func headToHeadOverlayChrome(namespace: Namespace.ID) -> some View {
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
            .accessibilityIdentifier("HeadToHeadOverlay_Root")
            .accessibilityElement(children: .contain)
            #if os(tvOS)
            .focusSection()
            #endif
    }

    func headToHeadFocusModifiers(
        focusAnchor: FocusState<HeadToHeadFocusAnchor?>.Binding,
        defaultFocus: HeadToHeadFocusAnchor,
        onAppear: @escaping () -> Void
    ) -> some View {
        self
            .defaultFocus(focusAnchor, defaultFocus)
            .onAppear { onAppear() }
    }

    func trackHeadToHeadPairs(
        app: AppState,
        onSync: @escaping () -> Void,
        onDisappear: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: app.headToHead.currentPair?.0.id) { _, _ in onSync() }
            .onChange(of: app.headToHead.currentPair?.1.id) { _, _ in onSync() }
            .onChange(of: app.headToHead.currentPair == nil) { _, _ in onSync() }
            .onDisappear { onDisappear() }
    }

    #if os(tvOS)
    func headToHeadTVModifiers(
        app: AppState,
        handleMove: @escaping (MoveCommandDirection) -> Void
    ) -> some View {
        self
            .onExitCommand { app.cancelHeadToHead(fromExitCommand: true) }
            .onMoveCommand(perform: handleMove)
    }
    #else
    func headToHeadMacOSModifiers(
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
            .accessibilityAddTraits(.isModal)
    }
    #endif
}

#if swift(>=6.0)
private struct GlassEffectModifier: ViewModifier {
    internal let namespace: Namespace.ID

    internal func body(content: Content) -> some View {
        content
            .glassEffectID("headToHeadOverlay", in: namespace)
            .glassEffectTransition(.matchedGeometry)
    }
}
#endif
