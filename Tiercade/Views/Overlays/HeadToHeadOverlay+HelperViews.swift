import SwiftUI
import TiercadeCore

internal struct HeadToHeadProgressDial: View {
    internal let progress: Double
    internal let label: String
    internal let accentColor: Color

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    internal var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 14)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.brand, accentColor, Palette.brand]),
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

    @ScaledMetric(relativeTo: .title) private var cardWidth = ScaledDimensions.candidateCardWidth
    @ScaledMetric(relativeTo: .title) private var cardMinHeight = ScaledDimensions.candidateCardMinHeight
    @ScaledMetric(relativeTo: .title) private var thumbnailHeight = ScaledDimensions.candidateThumbnailHeight

    internal var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: Metrics.grid * 2) {
                thumbnail
                textContent
            }
            .padding(Metrics.grid * 2.5)
            .frame(width: compact ? nil : cardWidth)
            .frame(maxWidth: compact ? .infinity : nil)
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

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.clear)
            .frame(width: cardWidth - (Metrics.grid * 5), height: thumbnailHeight)
            .overlay {
                thumbnailContent
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let asset = item.imageUrl ?? item.videoUrl,
           let url = URLValidator.allowedMediaURL(from: asset) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    thumbnailPlaceholder
                        .overlay {
                            ProgressView()
                                .tint(.white.opacity(0.6))
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    thumbnailPlaceholder
                        .overlay {
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                @unknown default:
                    thumbnailPlaceholder
                }
            }
        } else {
            thumbnailPlaceholder
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.3),
                        accentColor.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var textContent: some View {
        VStack(alignment: .center, spacing: Metrics.grid * 1.25) {
            Text(item.name ?? item.id)
                .font(candidateTitleFont)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let season = item.seasonString, !season.isEmpty {
                Text("Season \(season)")
                    .font(TypeScale.caption)
                    .foregroundStyle(accentColor)
            }

            if let status = item.status, !status.isEmpty {
                Text(status)
                    .font(TypeScale.footnote)
                    .foregroundStyle(.secondary)
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(candidateDescriptionFont)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .lineSpacing(Metrics.grid * 0.75)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: cardWidth - (Metrics.grid * 3))
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

// MARK: - Control Bar

internal struct HeadToHeadControlBar: View {
    internal let focusAnchor: FocusState<HeadToHeadFocusAnchor?>.Binding
    internal let canSkip: Bool
    internal let onCancel: () -> Void
    internal let onSkip: () -> Void
    internal let onFinish: () -> Void

    internal var body: some View {
        #if os(tvOS)
        tvOSLayout
        #else
        pointerLayout
        #endif
    }

    #if os(tvOS)
    private var tvOSLayout: some View {
        HStack(spacing: Metrics.grid * 3) {
            cancelButton
            skipButton
            finishButton
        }
    }
    #else
    private var pointerLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.grid * 3) {
                cancelButton
                skipButton
                finishButton
            }

            VStack(spacing: Metrics.grid * 2) {
                cancelButton
                skipButton
                finishButton
            }
        }
    }
    #endif

    private var cancelButton: some View {
        Button(role: .destructive, action: onCancel) {
            Label("Cancel", systemImage: "xmark.circle")
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.cancelAction)
        #endif
        .focused(focusAnchor, equals: .cancel)
        .accessibilityIdentifier("HeadToHeadOverlay_Cancel")
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Label("Skip Pair", systemImage: "arrow.uturn.left.circle")
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.borderedProminent)
        #endif
        .focused(focusAnchor, equals: .pass)
        .accessibilityIdentifier("HeadToHeadOverlay_Pass")
        .disabled(!canSkip)
    }

    private var finishButton: some View {
        Button(action: onFinish) {
            Label("Finish Ranking", systemImage: "checkmark.seal")
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
        }
        #if os(tvOS)
        .buttonStyle(.glassProminent)
        #else
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        #endif
        .focused(focusAnchor, equals: .commit)
        .accessibilityIdentifier("HeadToHeadOverlay_Apply")
    }
}

// MARK: - Metric Model

internal struct HeadToHeadMetric: Identifiable {
    internal let title: String
    internal let value: String
    internal let caption: String?

    internal var id: String { title }
}
