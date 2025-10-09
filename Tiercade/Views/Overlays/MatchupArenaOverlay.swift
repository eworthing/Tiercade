import SwiftUI
import TiercadeCore

private enum MatchupFocusAnchor: Hashable {
    case primary
    case secondary
    case pass
    case apply
    case abort
}

struct MatchupArenaOverlay: View {
    @Bindable var app: AppState
    @Namespace private var glassNamespace
    @FocusState private var focusAnchor: MatchupFocusAnchor?
    @State private var lastFocus: MatchupFocusAnchor = .primary
    @State private var suppressFocusReset = false

    private let minOverlayWidth: CGFloat = 960

    var body: some View {
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
        .tvGlassRounded(40)
#if swift(>=6.0)
        .glassEffectID("matchupOverlay", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
#endif
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 36, y: 18)
        .padding(.horizontal, Metrics.grid * 2)
        .accessibilityIdentifier("MatchupOverlay_Root")
        .accessibilityElement(children: .contain)
#if os(tvOS) || os(macOS)
        .focusable(true)
        .focusSection()
#endif
        .defaultFocus($focusAnchor, defaultFocus)
        .onAppear { handleAppear() }
        .onChange(of: app.h2hPair?.0.id) { _, _ in synchronizeFocus() }
        .onChange(of: app.h2hPair?.1.id) { _, _ in synchronizeFocus() }
        .onChange(of: app.h2hPair == nil) { _, _ in synchronizeFocus() }
        .onChange(of: focusAnchor) { _, newValue in
            guard !suppressFocusReset else { return }
            if let newValue { lastFocus = newValue } else { focusAnchor = lastFocus }
        }
#if os(tvOS)
        .onExitCommand { app.cancelH2H(fromExitCommand: true) }
        .onDisappear { suppressFocusReset = true }
        .onMoveCommand(perform: handleMoveCommand)
#else
        .accessibilityAddTraits(.isModal)
#endif
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
            .buttonStyle(.tvGlass)
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
            .buttonStyle(.tvGlass)
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
    }

    private func synchronizeFocus() {
        Task { @MainActor in
            let target = defaultFocus
            focusAnchor = target
            lastFocus = target
        }
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !suppressFocusReset else { return }
        let current = focusAnchor ?? lastFocus
        guard let next = nextFocusAnchor(from: current, direction: direction) else { return }
        focusAnchor = next
    }

    private func nextFocusAnchor(
        from current: MatchupFocusAnchor,
        direction: MoveCommandDirection
    ) -> MatchupFocusAnchor? {
        switch direction {
        case .left: return moveLeft(from: current)
        case .right: return moveRight(from: current)
        case .up: return moveUp(from: current)
        case .down: return moveDown(from: current)
        default: return nil
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
}

private struct MatchupProgressDial: View {
    let progress: Double
    let label: String

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 14)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.brand, Palette.tierColor("S"), Palette.brand]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 26, weight: .semibold))
                Text(label)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Matchup progress")
        .accessibilityValue(label)
    }

    private var symbolName: String {
        switch clampedProgress {
        case 0..<0.25:
            return "gauge.low"
        case 0.25..<0.75:
            return "gauge.medium"
        default:
            return "gauge.high"
        }
    }
}

private struct MatchupCandidateCard: View {
    enum AlignmentHint { case leading, trailing }

    let item: Item
    let accentColor: Color
    let alignment: AlignmentHint
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 18) {
                header
                detail
            }
            .padding(Metrics.grid * 3)
            .frame(
                minWidth: 360,
                maxWidth: 520,
                minHeight: 280,
                alignment: alignment == .leading ? .topLeading : .topTrailing
            )
            .background(backgroundShape)
        }
        .buttonStyle(.tvGlass)
        .accessibilityLabel(item.name ?? item.id)
        .accessibilityHint(item.description ?? "Choose this contender")
    }

    private var header: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 10) {
            Text(item.name ?? item.id)
                .font(TypeScale.h3)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(3)
            if let season = item.seasonString, !season.isEmpty {
                Text("Season \(season)")
                    .font(.headline)
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var detail: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 12) {
            if !metadataTokens.isEmpty {
                metadataStack
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(TypeScale.body)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .lineSpacing(6)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
    }

    private var metadataStack: some View {
        let alignment: HorizontalAlignment = self.alignment == .leading ? .leading : .trailing

        return VStack(alignment: alignment, spacing: 6) {
            ForEach(metadataTokens, id: \.self) { token in
                Text(token)
                    .font(TypeScale.metadata)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(self.alignment == .leading ? .leading : .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metadataTokens: [String] {
        var tokens: [String] = []
        if let season = item.seasonString, !season.isEmpty {
            tokens.append("Season \(season)")
        }
        if let status = item.status, !status.isEmpty {
            tokens.append(status)
        }
        return tokens
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accentColor.opacity(0.4), lineWidth: 1.6)
            )
    }
}

private struct MatchupPassTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.uturn.left.circle")
                    .font(.system(size: 48, weight: .semibold))
                Text("Pass for Now")
                    .font(.headline)
            }
            .frame(width: 240, height: 240)
            .background(tileShape)
        }
        .buttonStyle(.tvGlass)
        .accessibilityLabel("Pass on this matchup")
        .accessibilityHint("Skip and revisit later")
    }

    private var tileShape: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.26), lineWidth: 1.4)
            )
    }
}

private struct MatchupCompletionPanel: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 64, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text("Every matchup reviewed")
                .font(.title2.weight(.semibold))
            Text("Choose Commit Rankings to apply your results or leave the session to discard them.")
                .font(TypeScale.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(.vertical, Metrics.grid * 4)
        .padding(.horizontal, Metrics.grid * 5)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.4)
                )
        )
        .accessibilityIdentifier("MatchupOverlay_Complete")
    }
}
