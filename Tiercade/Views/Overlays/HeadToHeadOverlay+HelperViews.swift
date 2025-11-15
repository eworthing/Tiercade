import SwiftUI
import TiercadeCore

internal struct HeadToHeadProgressDial: View {
    internal let progress: Double
    internal let label: String

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    internal var body: some View {
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

            VStack(spacing: Metrics.grid * 0.75) {
                Image(systemName: symbolName)
                    .imageScale(TypeScale.IconScale.small)
                    .fontWeight(.semibold)
                Text(label)
                    .font(TypeScale.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.grid * 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HeadToHead progress")
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

internal struct HeadToHeadCandidateCard: View {
    enum AlignmentHint { case leading, trailing }

    internal let item: Item
    internal let accentColor: Color
    internal let alignment: AlignmentHint
    internal let action: () -> Void
    internal var compact: Bool = false

    @ScaledMetric(relativeTo: .title) private var cardMinWidth = ScaledDimensions.candidateCardMinWidth
    @ScaledMetric(relativeTo: .title) private var cardMaxWidth = ScaledDimensions.candidateCardMaxWidth
    @ScaledMetric(relativeTo: .title) private var cardMinHeight = ScaledDimensions.candidateCardMinHeight

    internal var body: some View {
        Button(action: action) {
            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 2.25) {
                header
                detail
            }
            .padding(Metrics.grid * 3)
            .frame(
                minWidth: compact ? 0 : cardMinWidth,
                maxWidth: compact ? .infinity : cardMaxWidth,
                minHeight: cardMinHeight,
                alignment: alignment == .leading ? .topLeading : .topTrailing
            )
            .background(backgroundShape)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(item.name ?? item.id)
        .accessibilityHint(item.description ?? "Choose this contender")
    }

    private var candidateTitleFont: Font {
        #if os(tvOS)
        // Candidate name: use primary body size on tvOS
        return TypeScale.body
        #else
        return TypeScale.h3
        #endif
    }

    private var candidateDescriptionFont: Font {
        #if os(tvOS)
        // Description: secondary body size on tvOS
        return TypeScale.bodySmall
        #else
        return TypeScale.body
        #endif
    }

    private var header: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 1.25) {
            Text(item.name ?? item.id)
                .font(candidateTitleFont)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(3)
            if let season = item.seasonString, !season.isEmpty {
                Text("Season \(season)")
                    .font(TypeScale.caption)
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var detail: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 1.5) {
            if !metadataTokens.isEmpty {
                metadataStack
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(candidateDescriptionFont)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .lineSpacing(Metrics.grid * 0.75)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
    }

    private var metadataStack: some View {
        let alignment: HorizontalAlignment = self.alignment == .leading ? .leading : .trailing

        return VStack(alignment: alignment, spacing: Metrics.grid * 0.75) {
            ForEach(metadataTokens, id: \.self) { token in
                Text(token)
                    .font(TypeScale.footnote)
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

internal struct HeadToHeadPassTile: View {
    internal let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var tileSize = ScaledDimensions.passTileSize

    internal var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.grid * 2) {
                Image(systemName: "arrow.uturn.left.circle")
                    .imageScale(TypeScale.IconScale.medium)
                    .fontWeight(.semibold)
                Text("Pass for Now")
                    .font(TypeScale.label)
            }
            .frame(width: tileSize, height: tileSize)
            .background(tileShape)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("Pass on this pairing")
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

internal struct HeadToHeadCompletionPanel: View {
    @ScaledMetric(relativeTo: .body) private var textMaxWidth = ScaledDimensions.textContentMaxWidth

    private var titleFont: Font {
        #if os(tvOS)
        return TypeScale.body
        #else
        return TypeScale.h3
        #endif
    }

    private var bodyFont: Font {
        #if os(tvOS)
        return TypeScale.bodySmall
        #else
        return TypeScale.body
        #endif
    }

    internal var body: some View {
        VStack(spacing: Metrics.grid * 2) {
            Image(systemName: "crown.fill")
                .imageScale(TypeScale.IconScale.large)
                .fontWeight(.bold)
                .symbolRenderingMode(.hierarchical)
            Text("All comparisons complete")
                .font(titleFont)
            Text("Choose Commit Rankings to apply your results or leave the session to discard them.")
                .font(bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: textMaxWidth)
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
        .accessibilityIdentifier("HeadToHeadOverlay_Complete")
    }
}

internal struct HeadToHeadPhaseBadge: View {
    internal let phase: HeadToHeadPhase

    internal var body: some View {
        Label {
            Text(phaseLabel)
                .font(TypeScale.footnote)
        } icon: {
            Image(systemName: phaseIcon)
        }
        .padding(.vertical, Metrics.grid * 0.75)
        .padding(.horizontal, Metrics.grid * 1.5)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityLabel("HeadToHead phase \(phaseLabel)")
    }

    private var phaseLabel: String {
        switch phase {
        case .quick: return "Quick pass"
        case .refinement: return "Refinement"
        }
    }

    private var phaseIcon: String {
        switch phase {
        case .quick: return "bolt.fill"
        case .refinement: return "sparkles"
        }
    }
}

internal struct HeadToHeadMetricTile: View {
    internal let title: String
    internal let value: String
    internal let footnote: String?

    private var valueFont: Font {
        #if os(tvOS)
        // Metric value: secondary body size on tvOS
        return TypeScale.bodySmall
        #else
        return TypeScale.body
        #endif
    }

    internal var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 0.5) {
            Text(title.uppercased())
                .font(TypeScale.footnote)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(valueFont)
            if let footnote {
                Text(footnote)
                    .font(TypeScale.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Metrics.grid)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
