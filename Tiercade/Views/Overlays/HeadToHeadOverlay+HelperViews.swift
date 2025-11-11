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

    internal var body: some View {
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
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
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

internal struct HeadToHeadPassTile: View {
    internal let action: () -> Void

    internal var body: some View {
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
    internal var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 64, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text("All comparisons complete")
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
        .accessibilityIdentifier("HeadToHeadOverlay_Complete")
    }
}

internal struct HeadToHeadPhaseBadge: View {
    internal let phase: HeadToHeadPhase

    internal var body: some View {
        Label {
            Text(phaseLabel)
                .font(.footnote.weight(.semibold))
        } icon: {
            Image(systemName: phaseIcon)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
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

    internal var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
