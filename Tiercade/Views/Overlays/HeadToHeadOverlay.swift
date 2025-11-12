import SwiftUI
import TiercadeCore

internal enum HeadToHeadFocusAnchor: Hashable {
    case primary
    case pass
    case secondary
    case commit
    case cancel
}

internal struct HeadToHeadOverlay: View {
    @Bindable var app: AppState
    @Namespace private var glassNamespace
    @FocusState private var focusAnchor: HeadToHeadFocusAnchor?
    #if !os(tvOS)
    @FocusState private var overlayHasFocus: Bool
    #endif

    private let minOverlayWidth: CGFloat = 960

    internal var body: some View {
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
    }

    private func overlayContent(maxWidth: CGFloat) -> some View {
        #if os(tvOS)
        buildOverlayContainer(maxWidth: maxWidth)
            .headToHeadOverlayChrome(namespace: glassNamespace)
            .headToHeadFocusModifiers(
                focusAnchor: $focusAnchor,
                defaultFocus: defaultFocus,
                onAppear: handleAppear
            )
            .trackHeadToHeadPairs(
                app: app,
                onSync: synchronizeFocus,
                onDisappear: {}
            )
            .headToHeadTVModifiers(
                app: app,
                handleMove: handleMoveCommand
            )
        #else
        buildOverlayContainer(maxWidth: maxWidth)
            .headToHeadOverlayChrome(namespace: glassNamespace)
            .headToHeadFocusModifiers(
                focusAnchor: $focusAnchor,
                defaultFocus: defaultFocus,
                onAppear: handleAppear
            )
            .trackHeadToHeadPairs(
                app: app,
                onSync: synchronizeFocus,
                onDisappear: { overlayHasFocus = false }
            )
            .headToHeadMacOSModifiers(
                overlayHasFocus: $overlayHasFocus,
                handleInput: handleDirectionalInput,
                handleAction: handlePrimaryAction
            )
        #endif
    }

    private func buildOverlayContainer(maxWidth: CGFloat) -> some View {
        tvGlassContainer(spacing: 0) {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                overviewSection
                Divider()
                    .blendMode(.plusLighter)
                    .opacity(0.3)
                comparisonSection
                controlBar
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: maxWidth)
        }
    }

    private var defaultFocus: HeadToHeadFocusAnchor {
        app.headToHead.currentPair == nil ? .commit : .primary
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.grid * 1.5) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HeadToHead Arena")
                        .font(TypeScale.h2)
                    Text("Compare contenders, resolve ties, and keep your rankings focused.")
                        .font(TypeScale.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                HeadToHeadPhaseBadge(phase: app.headToHead.phase)
            }
            HStack(alignment: .center, spacing: Metrics.grid * 3) {
                HeadToHeadProgressDial(progress: app.headToHead.overallProgress, label: progressLabel)
                    .frame(width: 150, height: 150)
                    .accessibilityIdentifier("HeadToHeadOverlay_Progress")

                VStack(alignment: .leading, spacing: 12) {
                    Text(statusSummary)
                        .font(.title3.weight(.semibold))
                    Text(secondaryStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Metrics.grid * 2.5) {
                        ForEach(metricTiles, id: \.title) { metric in
                            HeadToHeadMetricTile(
                                title: metric.title,
                                value: metric.value,
                                footnote: metric.caption
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("HeadToHeadOverlay_Header")
    }

    private var metricTiles: [HeadToHeadMetric] {
        [
            HeadToHeadMetric(
                title: "Completed",
                value: "\(app.headToHead.totalDecidedComparisons)",
                caption: "of \(app.headToHead.totalComparisons + app.headToHead.refinementTotalComparisons)"
            ),
            HeadToHeadMetric(
                title: "Remaining",
                value: "\(app.headToHead.totalRemainingComparisons)",
                caption: app.headToHead.phase == .quick ? "Quick phase" : "Refinement"
            ),
            HeadToHeadMetric(
                title: "Skipped",
                value: "\(app.headToHead.skippedCount)",
                caption: "Will resurface later"
            )
        ]
    }

    private var comparisonSection: some View {
        Group {
            if let pair = app.headToHead.currentPair {
                HStack(alignment: .top, spacing: pairSpacing) {
                    HeadToHeadCandidateCard(
                        item: pair.0,
                        accentColor: Palette.brand,
                        alignment: .leading,
                        action: { app.voteHeadToHead(winner: pair.0) }
                    )
                    .focused($focusAnchor, equals: .primary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Primary")

                    HeadToHeadPassTile(action: { app.skipCurrentHeadToHeadPair() })
                        .focused($focusAnchor, equals: .pass)
                        .accessibilityIdentifier("HeadToHeadOverlay_Pass")

                    HeadToHeadCandidateCard(
                        item: pair.1,
                        accentColor: Palette.tierColor("S"),
                        alignment: .trailing,
                        action: { app.voteHeadToHead(winner: pair.1) }
                    )
                    .focused($focusAnchor, equals: .secondary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Secondary")
                }
                .accessibilityIdentifier("HeadToHeadOverlay_Comparison")
            } else {
                HeadToHeadCompletionPanel()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: Metrics.grid * 3) {
            Button(role: .destructive) {
                app.cancelHeadToHead()
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
            .focused($focusAnchor, equals: .cancel)
            .accessibilityIdentifier("HeadToHeadOverlay_Cancel")

            Spacer(minLength: Metrics.grid * 4)

            Button {
                app.finishHeadToHead()
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
            .focused($focusAnchor, equals: .commit)
            .accessibilityIdentifier("HeadToHeadOverlay_Apply")
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
        let percentage = Int(round(app.headToHead.overallProgress * 100))
        return "\(percentage)%"
    }

    private var statusSummary: String {
        switch app.headToHead.phase {
        case .quick:
            return "Building your ranking"
        case .refinement:
            if app.headToHead.totalRemainingComparisons == 0 {
                return "Ranking complete"
            }
            return "Polishing the results"
        }
    }

    private var secondaryStatus: String {
        if app.headToHead.totalRemainingComparisons == 0 {
            return "Choose Commit Rankings to apply the outcome."
        }
        switch app.headToHead.phase {
        case .quick:
            return "Keep comparing contenders to shape the tiers."
        case .refinement:
            return "Tightening boundaries with targeted matchups."
        }
    }

    private func handleAppear() {
        synchronizeFocus()
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
    }

    private func synchronizeFocus() {
        Task { @MainActor in
            focusAnchor = defaultFocus
        }
    }

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let mapped = DirectionalMove(moveCommand: direction) else { return }
        handleDirectionalInput(mapped)
    }
    #endif

    private func handleDirectionalInput(_ move: DirectionalMove) {
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
        guard let current = focusAnchor else { return }
        guard let next = nextFocusAnchor(from: current, direction: move) else { return }
        focusAnchor = next
    }

    private func nextFocusAnchor(
        from current: HeadToHeadFocusAnchor,
        direction: DirectionalMove
    ) -> HeadToHeadFocusAnchor? {
        switch direction {
        case .left: return moveLeft(from: current)
        case .right: return moveRight(from: current)
        case .up: return moveUp(from: current)
        case .down: return moveDown(from: current)
        }
    }

    private func moveLeft(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .secondary: return .pass
        case .pass: return .primary
        case .commit: return .cancel
        default: return nil
        }
    }

    private func moveRight(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .primary: return app.headToHead.currentPair != nil ? .pass : .commit
        case .pass: return .secondary
        case .cancel: return .commit
        default: return nil
        }
    }

    private func moveUp(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .commit, .cancel:
            return app.headToHead.currentPair != nil ? .pass : nil
        case .pass:
            return .primary
        default:
            return nil
        }
    }

    private func moveDown(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .primary, .secondary, .pass:
            return .commit
        default:
            return nil
        }
    }

    private func handlePrimaryAction() {
        let anchor = focusAnchor ?? defaultFocus
        switch anchor {
        case .primary:
            if let pair = app.headToHead.currentPair {
                app.voteHeadToHead(winner: pair.0)
            }
        case .secondary:
            if let pair = app.headToHead.currentPair {
                app.voteHeadToHead(winner: pair.1)
            }
        case .pass:
            app.skipCurrentHeadToHeadPair()
        case .commit:
            app.finishHeadToHead()
        case .cancel:
            app.cancelHeadToHead()
        }
    }
}

private struct HeadToHeadMetric: Identifiable {
    internal let title: String
    internal let value: String
    internal let caption: String?

    internal var id: String { title }
}
