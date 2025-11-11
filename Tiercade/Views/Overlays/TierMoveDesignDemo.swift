import SwiftUI
import TiercadeCore

/// Demo view for comparing tier move row design options
/// Shows 4 different design approaches with various tier name lengths
internal struct TierMoveDesignDemo: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOption: DesignOption = .hybrid

    enum DesignOption: String, CaseIterable, Identifiable {
        case hybrid = "Hybrid (Recommended)"
        case barTextBorder = "Bar + Text + Border"
        case leftSection = "Left Colored Section"
        case gradientBar = "Gradient Bar"

        var id: String { rawValue }
    }

    // Sample tiers with different name lengths
    private let sampleTiers: [(name: String, color: Color, count: Int)] = [
        ("S", Color(designHex: "#E11D48"), 5),
        ("Really Intense Score", Color(designHex: "#F59E0B"), 12),
        ("Good", Color(designHex: "#22C55E"), 8),
        ("Somewhat Intense Score", Color(designHex: "#06B6D4"), 3),
        ("B", Color(designHex: "#3B82F6"), 15),
        ("Top of the List", Color(designHex: "#8B5CF6"), 7)
    ]

    internal var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Option picker
                Picker("Design Option", selection: $selectedOption) {
                    ForEach(DesignOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Description
                descriptionSection
                    .padding()

                Divider()

                // Demo rows
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(sampleTiers.enumerated()), id: \.offset) { index, tier in
                            demoRow(for: tier, isCurrentTier: index == 1)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tier Row Design Options")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedOption.rawValue)
                .font(.headline)

            Text(description(for: selectedOption))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func demoRow(for tier: (name: String, color: Color, count: Int), isCurrentTier: Bool) -> some View {
        switch selectedOption {
        case .hybrid:
            HybridRow(tierName: tier.name, tierColor: tier.color, itemCount: tier.count, isCurrentTier: isCurrentTier)
        case .barTextBorder:
            BarTextBorderRow(tierName: tier.name, tierColor: tier.color, itemCount: tier.count, isCurrentTier: isCurrentTier)
        case .leftSection:
            LeftSectionRow(tierName: tier.name, tierColor: tier.color, itemCount: tier.count, isCurrentTier: isCurrentTier)
        case .gradientBar:
            GradientBarRow(tierName: tier.name, tierColor: tier.color, itemCount: tier.count, isCurrentTier: isCurrentTier)
        }
    }

    private func description(for option: DesignOption) -> String {
        switch option {
        case .hybrid:
            return "Bar + tinted background + colored text + border. Maximum color prominence while maintaining solid backgrounds. Best for any text length."
        case .barTextBorder:
            return "Clean design with thick left bar, tier-colored text, and subtle border. No background tint. Professional look."
        case .leftSection:
            return "TierMaker-style colored section on left (30-35% width) with white text. Very prominent but uses significant horizontal space."
        case .gradientBar:
            return "Modern gradient bar at bottom with tier-colored text. Visually interesting but less immediate recognition."
        }
    }
}

// MARK: - Option 1: Hybrid (Recommended)

private struct HybridRow: View {
    let tierName: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    @State private var isFocused = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isFocused.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                // Left accent bar
                Rectangle()
                    .fill(tierColor)
                    .frame(width: 12)

                HStack(spacing: 16) {
                    // Tier name
                    Text(tierName)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(tierColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 12)

                    // Item count
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    // Icon
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tierColor.opacity(isFocused ? 0.18 : 0.12))
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.cardBackground)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused ? Color.white : tierColor.opacity(0.35), lineWidth: isFocused ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option 2: Bar + Text + Border

private struct BarTextBorderRow: View {
    let tierName: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    @State private var isFocused = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isFocused.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                // Left accent bar
                Rectangle()
                    .fill(tierColor)
                    .frame(width: 12)

                HStack(spacing: 16) {
                    // Tier name
                    Text(tierName)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(tierColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 12)

                    // Item count
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    // Icon
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused ? Color.white : tierColor.opacity(0.35), lineWidth: isFocused ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option 3: Left Colored Section

private struct LeftSectionRow: View {
    let tierName: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    @State private var isFocused = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isFocused.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                // Left colored section (30% of width)
                Text(tierName)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .background(tierColor)
                    .frame(maxWidth: 140)

                // Right section
                HStack(spacing: 16) {
                    // Item count
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    // Icon
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(tierColor)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused ? Color.white : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option 4: Gradient Bar

private struct GradientBarRow: View {
    let tierName: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    @State private var isFocused = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isFocused.toggle()
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Tier name
                    Text(tierName)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(tierColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 12)

                    // Item count
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    // Icon
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(.title3)
                            .foregroundStyle(tierColor, Color.white.opacity(0.85))
                            .symbolRenderingMode(.palette)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                // Gradient bar at bottom
                LinearGradient(
                    colors: [tierColor, tierColor.opacity(0.3), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isFocused ? Color.white : tierColor.opacity(0.25), lineWidth: isFocused ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

