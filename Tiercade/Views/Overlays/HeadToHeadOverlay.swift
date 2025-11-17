import SwiftUI
import os
import TiercadeCore

// swiftlint:disable type_body_length
// HeadToHeadOverlay: Complex overlay with platform-specific presentation, focus management, and adaptive layouts
// Type body length exception justified - splitting would fragment tightly-coupled presentation logic

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

    // tvOS uses a wider, tv-optimized overlay width.
    // Other platforms rely on overlayLayoutSize for adaptive sizing.
    private let minOverlayWidth: CGFloat = 960

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Scaled Dimensions
    @ScaledMetric(relativeTo: .title3) private var progressDialSize = ScaledDimensions.progressDialSize
    @ScaledMetric(relativeTo: .body) private var buttonMinWidthSmall = ScaledDimensions.buttonMinWidthSmall
    @ScaledMetric(relativeTo: .body) private var buttonMinWidthLarge = ScaledDimensions.buttonMinWidthLarge

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
                #if os(tvOS)
                let maxWidth = overlayMaxWidth(for: proxy)
                overlayContent(maxWidth: maxWidth, maxHeight: proxy.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                #else
                let layoutSize = overlayLayoutSize(
                    availableSize: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets
                )

                overlayContent(maxWidth: layoutSize.width, maxHeight: layoutSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                #endif
            }
        }
    }

    private func overlayContent(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let content = buildOverlayContainer()

        #if os(tvOS)
        return content
            .headToHeadOverlayChrome(namespace: glassNamespace)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
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
        return content
            .headToHeadOverlayChrome(namespace: glassNamespace)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
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
                handleAction: handlePrimaryAction,
                handleCancel: { app.cancelHeadToHead() }
            )
        #endif
    }

    private func buildOverlayContainer() -> some View {
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
        }
    }

    private var defaultFocus: HeadToHeadFocusAnchor {
        app.headToHead.currentPair == nil ? .commit : .primary
    }

    private func overlayMaxWidth(for proxy: GeometryProxy) -> CGFloat {
        #if os(tvOS)
        let insets = proxy.safeAreaInsets
        let safeWidth = max(proxy.size.width - insets.leading - insets.trailing, 0)

        let outerMargin = Metrics.grid * 4
        let available = max(safeWidth - outerMargin * 2, 0)

        // Treat minOverlayWidth as a minimum target, not a maximum.
        // If there's room, go at least that wide; if not, use whatever
        // safe width is available.
        let desired = max(available, minOverlayWidth)
        let clamped = min(desired, safeWidth)

        return clamped
        #else
        let available = proxy.size.width
        let horizontalMargin = Metrics.grid * 4
        let desired = max(available - horizontalMargin, 860)
        return min(desired, available)
        #endif
    }

    private func overlayLayoutSize(
        availableSize: CGSize,
        safeAreaInsets: EdgeInsets
    ) -> CGSize {
        let usableWidth = max(availableSize.width - safeAreaInsets.leading - safeAreaInsets.trailing, 0)
        let usableHeight = max(availableSize.height - safeAreaInsets.top - safeAreaInsets.bottom, 0)

        let outerHorizontalInset: CGFloat
        let outerVerticalInset: CGFloat

        #if os(tvOS)
        outerHorizontalInset = TVMetrics.overlayPadding * 1.4
        outerVerticalInset = TVMetrics.overlayPadding * 1.4
        #else
        outerHorizontalInset = Metrics.grid * 3.5
        outerVerticalInset = Metrics.grid * 3.5
        #endif

        let maxWidth = max(usableWidth - outerHorizontalInset * 2, 320)
        let maxHeight = max(usableHeight - outerVerticalInset * 2, 320)

        var targetWidth: CGFloat
        var targetHeight: CGFloat

        #if os(tvOS)
        targetWidth = 1400
        targetHeight = 820
        #else
        let isRegularWidth = horizontalSizeClass == .regular || horizontalSizeClass == nil
        if isRegularWidth {
            targetWidth = 980
            targetHeight = 720
        } else {
            targetWidth = 760
            targetHeight = 640
        }
        #endif

        // Give large Dynamic Type a bit more vertical room, similar
        // to Apple's AnyLayout guidance that pivots layouts based
        // on dynamicTypeSize.
        if dynamicTypeSize >= .xLarge {
            targetHeight *= 1.1
        }
        if dynamicTypeSize >= .accessibility1 {
            targetHeight *= 1.2
        }

        let clampedWidth = min(targetWidth, maxWidth)
        let clampedHeight = min(targetHeight, maxHeight)

        return CGSize(width: clampedWidth, height: clampedHeight)
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

    private var titleFont: Font {
        #if os(tvOS)
        // Overlay title: smallest tvOS-safe heading
        return TypeScale.body
        #else
        return TypeScale.h2
        #endif
    }

    private var heroFont: Font {
        #if os(tvOS)
        // Status summary: one step below title on tvOS
        return TypeScale.bodySmall
        #else
        return TypeScale.h3
        #endif
    }

    private var supportingBodyFont: Font {
        #if os(tvOS)
        // Supporting copy in the header on tvOS
        return TypeScale.bodySmall
        #else
        return TypeScale.body
        #endif
    }

    private var overviewSection: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 3) {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                Text("HeadToHead Arena")
                    .font(titleFont)
            }

            Spacer()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Metrics.grid * 3) {
                    HeadToHeadProgressDial(
                        progress: app.headToHead.overallProgress,
                        label: progressLabel,
                        accentColor: Palette.tierColor("S", from: app.tierColors)
                    )
                        .frame(width: progressDialSize, height: progressDialSize)
                        .accessibilityIdentifier("HeadToHeadOverlay_Progress")

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

                VStack(alignment: .leading, spacing: Metrics.grid * 2) {
                    HeadToHeadProgressDial(
                        progress: app.headToHead.overallProgress,
                        label: progressLabel,
                        accentColor: Palette.tierColor("S", from: app.tierColors)
                    )
                        .frame(width: progressDialSize, height: progressDialSize)
                        .accessibilityIdentifier("HeadToHeadOverlay_Progress")

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
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var metricTiles: [HeadToHeadMetric] {
        [
            HeadToHeadMetric(
                title: "Completed",
                value: "\(app.headToHead.totalDecidedComparisons)",
                caption: nil
            ),
            HeadToHeadMetric(
                title: "Remaining",
                value: "\(app.headToHead.totalRemainingComparisons)",
                caption: nil
            ),
            HeadToHeadMetric(
                title: "Skipped",
                value: "\(app.headToHead.skippedCount)",
                caption: nil
            )
        ]
    }

    private var comparisonSection: some View {
        Group {
            if let pair = app.headToHead.currentPair {
                #if os(tvOS)
                comparisonLayout(for: pair)
                #else
                ScrollView {
                    comparisonLayout(for: pair)
                        .padding(.vertical, Metrics.grid * 1.5)
                }
                .scrollIndicators(.hidden)
                #endif
            } else {
                HeadToHeadCompletionPanel()
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    private enum ComparisonLayoutMode {
        case wideRow
        case stacked
    }

    private func comparisonLayoutMode(for width: CGFloat) -> ComparisonLayoutMode {
        let isAccessibility = dynamicTypeSize >= .accessibility1
        if isAccessibility || width < minimumComparisonWidth() {
            return .stacked
        }
        return .wideRow
    }

    @ViewBuilder
    private func comparisonLayout(for pair: (Item, Item)) -> some View {
        GeometryReader { sectionProxy in
            let width = sectionProxy.size.width
            let mode = comparisonLayoutMode(for: width)
            switch mode {
            case .wideRow:
                AnyLayout(HStackLayout(spacing: pairSpacing)) {
                    HeadToHeadCandidateCard(
                        item: pair.0,
                        accentColor: Palette.brand,
                        alignment: .leading,
                        action: { app.voteHeadToHead(winner: pair.0) },
                        compact: false
                    )
                    .focused($focusAnchor, equals: .primary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Primary")

                    HeadToHeadCandidateCard(
                        item: pair.1,
                        accentColor: Palette.tierColor("S", from: app.tierColors),
                        alignment: .trailing,
                        action: { app.voteHeadToHead(winner: pair.1) },
                        compact: false
                    )
                    .focused($focusAnchor, equals: .secondary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Secondary")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("HeadToHeadOverlay_Comparison")
                #if DEBUG
                .onAppear {
                    Logger.headToHead.debug("comparison width=\(width) mode=wideRow min=\(minimumComparisonWidth())")
                }
                #endif

            case .stacked:
                VStack(spacing: pairSpacing) {
                    HeadToHeadCandidateCard(
                        item: pair.0,
                        accentColor: Palette.brand,
                        alignment: .leading,
                        action: { app.voteHeadToHead(winner: pair.0) },
                        compact: true
                    )
                    .focused($focusAnchor, equals: .primary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Primary")

                    HeadToHeadCandidateCard(
                        item: pair.1,
                        accentColor: Palette.tierColor("S", from: app.tierColors),
                        alignment: .trailing,
                        action: { app.voteHeadToHead(winner: pair.1) },
                        compact: true
                    )
                    .focused($focusAnchor, equals: .secondary)
                    .accessibilityIdentifier("HeadToHeadOverlay_Secondary")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("HeadToHeadOverlay_Comparison")
                #if DEBUG
                .onAppear {
                    Logger.headToHead.debug("comparison width=\(width) mode=stacked min=\(minimumComparisonWidth())")
                }
                #endif
            }
        }
        .frame(minHeight: 0)
    }

    private func minimumComparisonWidth() -> CGFloat {
        let cards = ScaledDimensions.candidateCardMinWidth * 2
        let gaps = pairSpacing
        return cards + gaps
    }

    private var controlBar: some View {
        #if os(tvOS)
        HStack(spacing: Metrics.grid * 3) {
            Button(role: .destructive) {
                app.cancelHeadToHead()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .focused($focusAnchor, equals: .cancel)
            .accessibilityIdentifier("HeadToHeadOverlay_Cancel")

            Button {
                app.skipCurrentHeadToHeadPair()
            } label: {
                Label("Skip Pair", systemImage: "arrow.uturn.left.circle")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .focused($focusAnchor, equals: .pass)
            .accessibilityIdentifier("HeadToHeadOverlay_Pass")
            .disabled(app.headToHead.currentPair == nil)

            Button {
                app.finishHeadToHead()
            } label: {
                Label("Finish Ranking", systemImage: "checkmark.seal")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .focused($focusAnchor, equals: .commit)
            .accessibilityIdentifier("HeadToHeadOverlay_Apply")
        }
        #else
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.grid * 3) {
                Button(role: .destructive) {
                    app.cancelHeadToHead()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
                .focused($focusAnchor, equals: .cancel)
                .accessibilityIdentifier("HeadToHeadOverlay_Cancel")

                Button {
                    app.skipCurrentHeadToHeadPair()
                } label: {
                    Label("Skip Pair", systemImage: "arrow.uturn.left.circle")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .focused($focusAnchor, equals: .pass)
                .accessibilityIdentifier("HeadToHeadOverlay_Pass")
                .disabled(app.headToHead.currentPair == nil)

                Button {
                    app.finishHeadToHead()
                } label: {
                    Label("Finish Ranking", systemImage: "checkmark.seal")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .focused($focusAnchor, equals: .commit)
                .accessibilityIdentifier("HeadToHeadOverlay_Apply")
            }

            VStack(spacing: Metrics.grid * 2) {
                Button(role: .destructive) {
                    app.cancelHeadToHead()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)
                .focused($focusAnchor, equals: .cancel)
                .accessibilityIdentifier("HeadToHeadOverlay_Cancel")

                Button {
                    app.skipCurrentHeadToHeadPair()
                } label: {
                    Label("Skip Pair", systemImage: "arrow.uturn.left.circle")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .focused($focusAnchor, equals: .pass)
                .accessibilityIdentifier("HeadToHeadOverlay_Pass")
                .disabled(app.headToHead.currentPair == nil)

                Button {
                    app.finishHeadToHead()
                } label: {
                    Label("Finish Ranking", systemImage: "checkmark.seal")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .focused($focusAnchor, equals: .commit)
                .accessibilityIdentifier("HeadToHeadOverlay_Apply")
            }
        }
        #endif
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

    private func handleAppear() {
        synchronizeFocus()
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
    }

    private func synchronizeFocus() {
        focusAnchor = defaultFocus
    }

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        // Let tvOS manage horizontal focus so HStack navigation feels natural.
        // We only customize vertical moves to steer between the cards and the
        // bottom action row, which the default engine can't infer from layout.
        guard direction == .up || direction == .down else { return }
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
        case .secondary:
            return .primary
        case .commit:
            // When a pair is active, move toward the middle Skip button.
            // Otherwise, step to the Cancel action.
            return app.headToHead.currentPair != nil ? .pass : .cancel
        case .pass:
            return .cancel
        default: return nil
        }
    }

    private func moveRight(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .primary:
            return .secondary
        case .cancel:
            // With an active pair, move into the middle Skip action.
            // After completion, skip directly to Finish.
            return app.headToHead.currentPair != nil ? .pass : .commit
        case .pass:
            return .commit
        default: return nil
        }
    }

    private func moveUp(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .cancel, .pass:
            // Move back to the primary card when comparisons are active.
            return app.headToHead.currentPair != nil ? .primary : nil
        case .commit:
            // The positive action lines up under the secondary card.
            return app.headToHead.currentPair != nil ? .secondary : nil
        default:
            return nil
        }
    }

    private func moveDown(from current: HeadToHeadFocusAnchor) -> HeadToHeadFocusAnchor? {
        switch current {
        case .primary, .secondary:
            // First vertical step from a card goes to Skip when a pair exists,
            // or directly to Finish when we're in the completion state.
            return app.headToHead.currentPair != nil ? .pass : .commit
        case .pass:
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

// MARK: - Previews

@MainActor
private struct HeadToHeadOverlayPreview: View {
    @State private var appState = PreviewHelpers.makeAppState { app in
        // Use the real lifecycle helper to seed a HeadToHead session
        // from the preview fixture items.
        app.startHeadToHead()
    }

    var body: some View {
        HeadToHeadOverlay(app: appState)
    }
}

#Preview("Head-to-Head Overlay") {
    HeadToHeadOverlayPreview()
}
