import SwiftUI
import TiercadeCore

/// Unified tier move sheet for both single and batch move operations
/// Works across all platforms (tvOS, iOS, iPadOS, macOS)
internal struct TierMoveSheet: View {
    @Bindable var app: AppState
    @Environment(\.dismiss) private var dismiss
    #if os(iOS) || os(tvOS)
    @Environment(\.editMode) private var editMode
    #endif
    @FocusState private var focusedTier: String?
    @Namespace private var focusScope

    private var isBatchMode: Bool {
        app.batchQuickMoveActive
    }

    private var title: String {
        if isBatchMode {
            return "\(app.selection.count) Item\(app.selection.count == 1 ? "" : "s")"
        } else if let item = app.overlays.quickMoveTarget ?? app.quickRankTarget {
            return item.name ?? item.id
        }
        return "Move Item"
    }

    private var allTiers: [String] {
        app.tierOrder + [TierIdentifier.unranked.rawValue]
    }

    private var currentTier: String? {
        guard !isBatchMode,
              let item = app.overlays.quickMoveTarget ?? app.quickRankTarget else { return nil }
        return app.currentTier(of: item.id)
    }

    internal var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, 16)

                Divider()
                    .opacity(0.2)

                // Tier list
                #if os(tvOS)
                if useCompactNoScrollLayout {
                    // Show all tiers without scroll when count is reasonable
                    VStack(spacing: tierSpacing) {
                        ForEach(allTiers, id: \.self) { tierName in
                            TierMoveRow(
                                tierName: tierName,
                                displayLabel: app.displayLabel(for: tierName),
                                tierColor: Palette.tierColor(tierName, from: app.tierColors),
                                itemCount: app.tiers[tierName]?.count ?? 0,
                                isCurrentTier: !isBatchMode && currentTier == tierName,
                                isFocused: focusedTier == tierName,
                                action: { moveTo(tierName) }
                            )
                            .focused($focusedTier, equals: tierName)
                            .accessibilityIdentifier("TierMove_\(tierName)")
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 20)
                    .focusSection()
                } else {
                    ScrollView {
                        VStack(spacing: tierSpacing) {
                            ForEach(allTiers, id: \.self) { tierName in
                                TierMoveRow(
                                    tierName: tierName,
                                    displayLabel: app.displayLabel(for: tierName),
                                    tierColor: Palette.tierColor(tierName, from: app.tierColors),
                                    itemCount: app.tiers[tierName]?.count ?? 0,
                                    isCurrentTier: !isBatchMode && currentTier == tierName,
                                    isFocused: focusedTier == tierName,
                                    action: { moveTo(tierName) }
                                )
                                .focused($focusedTier, equals: tierName)
                                .accessibilityIdentifier("TierMove_\(tierName)")
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 20)
                    }
                    .scrollIndicators(.visible)
                    .focusSection()
                }
                #else
                ScrollView {
                    VStack(spacing: tierSpacing) {
                        ForEach(allTiers, id: \.self) { tierName in
                            TierMoveRow(
                                tierName: tierName,
                                displayLabel: app.displayLabel(for: tierName),
                                tierColor: Palette.tierColor(tierName, from: app.tierColors),
                                itemCount: app.tiers[tierName]?.count ?? 0,
                                isCurrentTier: !isBatchMode && currentTier == tierName,
                                isFocused: focusedTier == tierName,
                                action: { moveTo(tierName) }
                            )
                            .focused($focusedTier, equals: tierName)
                            .accessibilityIdentifier("TierMove_\(tierName)")
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.visible)
                #endif

                #if !os(tvOS)
                Divider()
                    .opacity(0.2)

                // Action buttons (iOS/macOS only - tvOS uses system cancel)
                actionButtons
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
                #endif
            }
            .background(backgroundColor)
            .navigationTitle("Move to Tier")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS) || os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        app.cancelQuickMove()
                    }
                    .accessibilityIdentifier("TierMove_Cancel")
                }
            }
            #endif
            #if os(tvOS)
            .focusScope(focusScope)
            #endif
            .onAppear {
                focusedTier = defaultFocusTier
            }
            #if os(tvOS)
            .onExitCommand {
                dismiss()
                app.cancelQuickMove()
            }
            #endif
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(titleFont)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isBatchMode {
                Text("Select a tier to move all selected items")
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let currentTier {
                HStack(spacing: 6) {
                    Text("Currently in")
                        .font(subtitleFont)
                        .foregroundStyle(.secondary)
                    Text(app.displayLabel(for: currentTier))
                        .font(subtitleFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.tierColor(currentTier, from: app.tierColors))
                }
            }
        }
    }

    #if !os(tvOS)
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if !isBatchMode, let item = app.overlays.quickMoveTarget ?? app.quickRankTarget {
                #if os(iOS)
                if let editMode, editMode.wrappedValue == .active {
                    Button(app.isSelected(item.id) ? "Remove from Selection" : "Add to Selection") {
                        app.toggleSelection(item.id)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("TierMove_ToggleSelection")
                }
                #endif

                // Only show View Details for QuickMove (not QuickRank)
                if app.overlays.quickMoveTarget != nil {
                    Button("View Details") {
                        app.overlays.detailItem = item
                        dismiss()
                        app.cancelQuickMove()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("TierMove_ViewDetails")
                }
            }
        }
    }
    #endif

    // MARK: - Actions

    private func moveTo(_ tierName: String) {
        // Handle both QuickMove and QuickRank
        if app.overlays.quickMoveTarget != nil {
            app.commitQuickMove(to: tierName)
        } else if app.quickRankTarget != nil {
            app.commitQuickRank(to: tierName)
        }
        dismiss()
    }

    // MARK: - Layout Helpers

    private var defaultFocusTier: String? {
        #if os(iOS) || os(tvOS)
        if let editMode, editMode.wrappedValue == .active, !isBatchMode {
            return allTiers.first
        }
        #endif

        if isBatchMode {
            return allTiers.first
        }

        if let currentTier,
           let firstAlternative = allTiers.first(where: { $0 != currentTier }) {
            return firstAlternative
        }

        return allTiers.first
    }

    private var horizontalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding
        #else
        return 20
        #endif
    }

    private var topPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding * 0.6
        #else
        return 20
        #endif
    }

    private var tierSpacing: CGFloat {
        #if os(tvOS)
        return TVMetrics.buttonSpacing
        #else
        return 12
        #endif
    }

    private var titleFont: Font {
        #if os(tvOS)
        return .title
        #else
        return .title2
        #endif
    }

    private var subtitleFont: Font {
        #if os(tvOS)
        return .headline
        #else
        return .subheadline
        #endif
    }

    private var backgroundColor: Color {
        Palette.bg
    }

    #if os(tvOS)
    private var useCompactNoScrollLayout: Bool {
        // Show all tiers without scroll in common cases (≤ 8 tiers)
        allTiers.count <= 8
    }
    #endif
}

// MARK: - Tier Move Row

private struct TierMoveRow: View {
    let tierName: String
    let displayLabel: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    let isFocused: Bool
    let action: () -> Void

    #if os(tvOS)
    @Environment(\.isFocused) private var isEnvironmentFocused
    #endif

    var body: some View {
        Button(action: {
            if !isCurrentTier {
                action()
            }
        }) {
            HStack(spacing: 0) {
                // Left accent bar (Hybrid design element)
                Rectangle()
                    .fill(tierColor)
                    .frame(width: leftBarWidth)

                HStack(spacing: rowSpacing) {
                    // Tier label (in tier color - Hybrid design)
                    Text(displayLabel)
                        .font(labelFont)
                        .fontWeight(.heavy)  // Bolder for prominence
                        .foregroundStyle(tierColor)  // Colored text instead of primary
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 12)

                    // Item count
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(countFont)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    // Current tier indicator (palette rendering - Hybrid design)
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(iconFont)
                            .foregroundStyle(tierColor, secondaryIconColor)
                            .symbolRenderingMode(.palette)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(iconFont)
                            .foregroundStyle(tierColor, secondaryIconColor)
                            .symbolRenderingMode(.palette)
                            .opacity(isFocused ? 1 : 0)
                    }
                }
                .padding(.horizontal, rowHorizontalPadding)
                .padding(.vertical, rowVerticalPadding)
            }
            .frame(maxWidth: .infinity)
            .background(rowBackground)  // Includes tier-tinted background
            .overlay(rowBorder)
            .contentShape(Rectangle())
        }
        .buttonStyle(TierMoveRowButtonStyle(
            tierColor: tierColor,
            isCurrentTier: isCurrentTier
        ))
        .disabled(isCurrentTier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isCurrentTier ? "Already in this tier" : "Select to move")
        .accessibilityAddTraits(isCurrentTier ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Layout Helpers

    private var secondaryIconColor: Color {
        Palette.textOnAccent
    }

    private var leftBarWidth: CGFloat {
        #if os(tvOS)
        return 12
        #else
        return 10
        #endif
    }

    private var rowSpacing: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return 16
        #endif
    }

    private var rowHorizontalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding / 2
        #else
        return 20
        #endif
    }

    private var rowVerticalPadding: CGFloat {
        #if os(tvOS)
        return 16
        #else
        return 16
        #endif
    }

    private var labelFont: Font {
        #if os(tvOS)
        return .title2
        #else
        return .title3
        #endif
    }

    private var countFont: Font {
        #if os(tvOS)
        return .title3
        #else
        return .body
        #endif
    }

    private var iconFont: Font {
        #if os(tvOS)
        return .title3
        #else
        return .title2
        #endif
    }

    // MARK: - Visual Constants

    private let focusedBackgroundOpacity: Double = 0.18
    private let unfocusedBackgroundOpacity: Double = 0.12
    private let currentTierBorderOpacity: Double = 0.8
    private let defaultBorderOpacity: Double = 0.35

    @ViewBuilder
    private var rowBackground: some View {
        #if os(tvOS)
        RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius, style: .continuous)
            .fill(tierColor.opacity(isFocused ? focusedBackgroundOpacity : unfocusedBackgroundOpacity))
            .background(
                RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius, style: .continuous)
                    .fill(Palette.bg.opacity(0.6))
            )
        #else
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tierColor.opacity(unfocusedBackgroundOpacity))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cardBackground)
            )
        #endif
    }

    @ViewBuilder
    private var rowBorder: some View {
        #if os(tvOS)
        RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
        #else
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(borderColor, lineWidth: 2)
        #endif
    }

    private var borderColor: Color {
        #if os(tvOS)
        if isFocused {
            return Palette.text
        }
        return tierColor.opacity(isCurrentTier ? currentTierBorderOpacity : defaultBorderOpacity)
        #else
        return tierColor.opacity(isCurrentTier ? currentTierBorderOpacity : defaultBorderOpacity)
        #endif
    }

    #if os(tvOS)
    private var borderWidth: CGFloat {
        isFocused ? 4 : (isCurrentTier ? 3 : 2)
    }
    #endif

    private var accessibilityLabel: String {
        if isCurrentTier {
            return "Current tier: \(displayLabel), \(itemCount) item\(itemCount == 1 ? "" : "s")"
        } else {
            return "Move to \(displayLabel), \(itemCount) item\(itemCount == 1 ? "" : "s")"
        }
    }
}

// MARK: - Button Style

private struct TierMoveRowButtonStyle: ButtonStyle {
    let tierColor: Color
    let isCurrentTier: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !isCurrentTier ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            #if os(tvOS)
            .focusEffectDisabled(false)
            #endif
    }
}

// MARK: - Previews

@MainActor
private struct TierMoveSheetPreview: View {
    @State private var appState = PreviewHelpers.makeAppState()

    init() {
        // Seed a simple preview scenario: use the first available item if any.
        if let firstTier = appState.tierOrder.first,
           let firstItem = appState.tiers[firstTier]?.first {
            appState.overlays.quickMoveTarget = firstItem
        }
    }

    var body: some View {
        TierMoveSheet(app: appState)
    }
}

#Preview("Tier Move Sheet") {
    TierMoveSheetPreview()
}
