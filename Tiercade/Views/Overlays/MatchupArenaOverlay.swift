import SwiftUI
import TiercadeCore

internal enum MatchupFocusAnchor: Hashable {
    case primary
    case secondary
    case pass
    case apply
    case abort
}

internal struct MatchupArenaOverlay: View {
    @Bindable var app: AppState
    @Namespace private var glassNamespace
    @FocusState private var focusAnchor: MatchupFocusAnchor?
    @State private var lastFocus: MatchupFocusAnchor = .primary
    @State private var suppressFocusReset = false
    #if !os(tvOS)
    @FocusState private var overlayHasFocus: Bool
    #endif

    private let minOverlayWidth: CGFloat = 960

    internal var body: some View {
        if app.h2hActive {
            ZStack {
                LinearGradient(
                    colors: [Palette.bg.opacity(0.65), Palette.surfHi.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

                GeometryReader { proxy in
                    overlayContent(maxWidth: overlayMaxWidth(for: proxy))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .transition(.opacity)
        }
    }

    private func overlayContent(maxWidth: CGFloat) -> some View {
        #if os(tvOS)
        buildOverlayContainer(maxWidth: maxWidth)
            .applyOverlayModifiers(namespace: glassNamespace)
            .applyFocusModifiers(
                focusAnchor: $focusAnchor,
                defaultFocus: defaultFocus,
                onAppear: handleAppear,
                onFocusChange: handleFocusAnchorChange
            )
            .applyH2HPairTracking(
                app: app,
                onSync: synchronizeFocus,
                onDisappear: { suppressFocusReset = true }
            )
            .applyTVOSModifiers(
                app: app,
                handleMove: handleMoveCommand
            )
        #else
        buildOverlayContainer(maxWidth: maxWidth)
            .applyOverlayModifiers(namespace: glassNamespace)
            .applyFocusModifiers(
                focusAnchor: $focusAnchor,
                defaultFocus: defaultFocus,
                onAppear: handleAppear,
                onFocusChange: handleFocusAnchorChange
            )
            .applyH2HPairTracking(
                app: app,
                onSync: synchronizeFocus,
                onDisappear: { overlayHasFocus = false }
            )
            .applyNonTVOSModifiers(
                app: app,
                overlayHasFocus: $overlayHasFocus,
                handleInput: handleDirectionalInput,
                handleAction: handlePrimaryAction
            )
        #endif
    }

    private func buildOverlayContainer(maxWidth: CGFloat) -> some View {
        tvGlassContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerSection
                progressSection
                Divider()
                    .blendMode(.plusLighter)
                    .opacity(0.3)
                matchSection
                commandBar
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: maxWidth)
        }
    }

    private func handleFocusAnchorChange(newValue: MatchupFocusAnchor?) {
        guard !suppressFocusReset else { return }
        if let newValue {
            lastFocus = newValue
        } else {
            focusAnchor = lastFocus
        }
    }

    private var defaultFocus: MatchupFocusAnchor {
        app.h2hPair == nil ? .apply : .primary
    }

    private func overlayMaxWidth(for proxy: GeometryProxy) -> CGFloat {
        #if os(tvOS)
        let safeArea = proxy.safeAreaInsets
        let available = max(proxy.size.width - safeArea.leading - safeArea.trailing, 0)
        let horizontalMargin = Metrics.grid * 4
        let desired = max(available - horizontalMargin, minOverlayWidth)
        return min(desired, available)
        #else
        let available = proxy.size.width
        let horizontalMargin = Metrics.grid * 4
        let desired = max(available - horizontalMargin, 860)
        return min(desired, available)
        #endif
    }

    private var verticalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding * 1.25
        #else
        return Metrics.grid * 5
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding * 1.1
        #else
        return Metrics.grid * 4.5
        #endif
    }

    private var sectionSpacing: CGFloat {
        #if os(tvOS)
        return TVMetrics.cardSpacing * 1.15
        #else
        return Metrics.grid * 3.5
        #endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matchup Arena")
                .font(TypeScale.h2)
            Text("Compare contenders, build your ranking, and keep the momentum flowing.")
                .font(TypeScale.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("MatchupOverlay_Header")
    }

    private var progressSection: some View {
        HStack(alignment: .center, spacing: Metrics.grid * 3) {
            MatchupProgressDial(progress: app.h2hOverallProgress, label: progressLabel)
                .frame(width: 150, height: 150)
                .accessibilityIdentifier("MatchupOverlay_Progress")

            VStack(alignment: .leading, spacing: 6) {
                Text(statusSummary)
                    .font(.title3.weight(.semibold))
                Text(secondaryStatus)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if app.h2hSkippedCount > 0 {
                    Text("Skipped: \(app.h2hSkippedCount)")
                        .font(.headline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .accessibilityIdentifier("MatchupOverlay_SkippedBadge")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var matchSection: some View {
        Group {
            if let pair = app.h2hPair {
                HStack(alignment: .top, spacing: pairSpacing) {
                    MatchupCandidateCard(
                        item: pair.0,
                        accentColor: Palette.brand,
                        alignment: .leading,
                        action: { app.voteH2H(winner: pair.0) }
                    )
                    .focused($focusAnchor, equals: .primary)
                    .accessibilityIdentifier("MatchupOverlay_Primary")

                    MatchupPassTile(action: { app.skipCurrentH2HPair() })
                        .focused($focusAnchor, equals: .pass)
                        .accessibilityIdentifier("MatchupOverlay_Pass")

                    MatchupCandidateCard(
                        item: pair.1,
                        accentColor: Palette.tierColor("S"),
                        alignment: .trailing,
                        action: { app.voteH2H(winner: pair.1) }
                    )
                    .focused($focusAnchor, equals: .secondary)
                    .accessibilityIdentifier("MatchupOverlay_Secondary")
                }
            } else {
                MatchupCompletionPanel()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private var commandBar: some View {
        HStack(spacing: Metrics.grid * 3) {
            Button(role: .destructive) {
                app.cancelH2H()
            } label: {
                Label("Leave Session", systemImage: "xmark.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 220)
            }
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.cancelAction)
            #endif
            .focused($focusAnchor, equals: .abort)
            .accessibilityIdentifier("MatchupOverlay_Cancel")

            Spacer(minLength: Metrics.grid * 4)

            Button {
                app.finishH2H()
            } label: {
                Label("Commit Rankings", systemImage: "checkmark.seal")
                    .labelStyle(.titleAndIcon)
                    .frame(minWidth: 260)
            }
            #if os(tvOS)
            .buttonStyle(.glassProminent)
            #else
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            #endif
            .focused($focusAnchor, equals: .apply)
            .accessibilityIdentifier("MatchupOverlay_Apply")
        }
    }

    private var pairSpacing: CGFloat {
        #if os(tvOS)
        return TVMetrics.cardSpacing * 1.3
        #else
        return Metrics.grid * 4
        #endif
    }

    private var progressLabel: String {
        let percentage = Int(round(app.h2hOverallProgress * 100))
        return "\(percentage)%"
    }

    private var statusSummary: String {
        switch app.h2hPhase {
        case .quick:
            return "Building your ranking"
        case .refinement:
            if app.h2hTotalRemainingComparisons == 0 {
                return "Ranking complete"
            }
            return "Polishing the results"
        }
    }

    private var secondaryStatus: String {
        if app.h2hTotalRemainingComparisons == 0 {
            return "Choose Commit Rankings to apply the outcome."
        }
        switch app.h2hPhase {
        case .quick:
            return "Keep comparing contenders to shape the tiers."
        case .refinement:
            return "Tightening boundaries with targeted matchups."
        }
    }

    private func handleAppear() {
        suppressFocusReset = false
        synchronizeFocus()
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
    }

    private func synchronizeFocus() {
        Task { @MainActor in
            let target = defaultFocus
            focusAnchor = target
            lastFocus = target
        }
    }

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let mapped = DirectionalMove(moveCommand: direction) else { return }
        handleDirectionalInput(mapped)
    }
    #endif

    private func handleDirectionalInput(_ move: DirectionalMove) {
        guard !suppressFocusReset else { return }
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
        let current = focusAnchor ?? lastFocus
        guard let next = nextFocusAnchor(from: current, direction: move) else { return }
        focusAnchor = next
    }

    private func nextFocusAnchor(
        from current: MatchupFocusAnchor,
        direction: DirectionalMove
    ) -> MatchupFocusAnchor? {
        switch direction {
        case .left: return moveLeft(from: current)
        case .right: return moveRight(from: current)
        case .up: return moveUp(from: current)
        case .down: return moveDown(from: current)
        }
    }

    private func moveLeft(from current: MatchupFocusAnchor) -> MatchupFocusAnchor? {
        switch current {
        case .secondary: return .pass
        case .pass: return .primary
        case .apply: return .abort
        default: return nil
        }
    }

    private func moveRight(from current: MatchupFocusAnchor) -> MatchupFocusAnchor? {
        switch current {
        case .primary: return app.h2hPair != nil ? .pass : .apply
        case .pass: return .secondary
        case .abort: return .apply
        default: return nil
        }
    }

    private func moveUp(from current: MatchupFocusAnchor) -> MatchupFocusAnchor? {
        switch current {
        case .apply, .abort:
            return app.h2hPair != nil ? .pass : nil
        case .pass:
            return .primary
        default:
            return nil
        }
    }

    private func moveDown(from current: MatchupFocusAnchor) -> MatchupFocusAnchor? {
        switch current {
        case .primary, .secondary, .pass:
            return .apply
        default:
            return nil
        }
    }

    private func handlePrimaryAction() {
        let anchor = focusAnchor ?? defaultFocus
        switch anchor {
        case .primary:
            if let pair = app.h2hPair {
                app.voteH2H(winner: pair.0)
            }
        case .secondary:
            if let pair = app.h2hPair {
                app.voteH2H(winner: pair.1)
            }
        case .pass:
            app.skipCurrentH2HPair()
        case .apply:
            app.finishH2H()
        case .abort:
            app.cancelH2H()
        }
    }
}
