import SwiftUI
import Foundation
import TiercadeCore

// MARK: - Card View

internal struct CardView: View {
    internal let item: Item
    @Environment(AppState.self) var app
    @Environment(\.isFocused) var isFocused: Bool
    #if os(iOS) || os(tvOS)
    @Environment(\.editMode) private var editMode
    #endif
    #if os(tvOS)
    internal let layout: TVCardLayout
    #else
    internal let layout: PlatformCardLayout
    internal var onTapFocus: (() -> Void)?  // Called when card is tapped to update focus
    #endif

    private var isMultiSelectActive: Bool {
        #if os(iOS) || os(tvOS)
        return editMode?.wrappedValue == .active
        #else
        return false
        #endif
    }

    /// Get color for focus halo using state-driven tier colors
    private func colorForItem(_ item: Item) -> Color {
        guard let tierId = app.currentTier(of: item.id) else {
            return Palette.tierColor("unranked", from: app.tierColors)
        }
        return Palette.tierColor(tierId, from: app.tierColors)
    }

    /// Get tier badge data for display (label and color hex)
    private func tierBadgeData(for item: Item) -> (label: String, colorHex: String) {
        guard let tierId = app.currentTier(of: item.id) else {
            return ("Unranked", app.tierColors["unranked"] ?? "#6B7280")
        }
        let label = app.displayLabel(for: tierId)
        let colorHex = app.tierColors[tierId] ?? "#6B7280"
        return (label, colorHex)
    }

    private var layoutCornerRadius: CGFloat {
        #if os(tvOS)
        layout.cornerRadius
        #else
        layout.cornerRadius
        #endif
    }

    internal var body: some View {
        Button(action: handleTap) {
            cardBody
        }
        .buttonStyle(.plain)
        #if !os(tvOS)
        .focusable()  // Enable keyboard event handling (Space/Return) on iOS/macOS
        .onKeyPress(.space) {
            onTapFocus?()  // Update focus state
            if !isMultiSelectActive {
                app.beginQuickRank(item)
            }
            return .handled
        }
        .onKeyPress(.return) {
            onTapFocus?()  // Update focus state
            if !isMultiSelectActive {
                app.beginQuickRank(item)
            }
            return .handled
        }
        #endif
        .accessibilityIdentifier("Card_\(item.id)")
        .scaleEffect(app.draggingId == item.id ? 0.98 : 1.0)
        .shadow(
            color: Palette.bg.opacity(app.draggingId == item.id ? 0.45 : 0.1),
            radius: app.draggingId == item.id ? 20 : 6,
            x: 0,
            y: app.draggingId == item.id ? 12 : 4
        )
        .contentShape(Rectangle())
        .accessibilityLabel(displayLabel)
        .punchyFocus(color: colorForItem(item), cornerRadius: layoutCornerRadius)
        #if os(iOS) || os(macOS)
        .accessibilityAddTraits(.isButton)
        #endif
        #if !os(tvOS)
        .onDrag {
            app.setDragging(item.id)
            return NSItemProvider(object: NSString(string: item.id))
        }
        #endif
        #if os(tvOS)
        .onPlayPauseCommand {
            if isMultiSelectActive {
                app.toggleSelection(item.id)
            } else {
                app.beginQuickMove(item)
            }
        }
        .onMoveCommand { direction in
            // Don't reorder if not in custom sort mode - let focus navigate
            guard app.globalSortMode.isCustom else { return }

            // Get current tier for this item
            guard let tierName = app.currentTier(of: item.id) else { return }

            // Check if we're in multi-select mode with selected items
            if isMultiSelectActive && app.isSelected(item.id) && app.selection.count > 1 {
                // Block move: move all selected items in this tier together
                handleBlockMove(tierName: tierName, direction: direction)
            } else {
                // Single item move
                switch direction {
                case .left:
                    app.moveItemLeft(item.id, in: tierName)
                case .right:
                    app.moveItemRight(item.id, in: tierName)
                default:
                    break
                }
            }
        }
        .contextMenu {
            ForEach(app.tierOrder, id: \.self) { tier in
                Button("Move to \(tier)") {
                    app.move(item.id, to: tier)
                }
            }
            Button("Move to Unranked") {
                app.move(item.id, to: "unranked")
            }
            Button("View Details") { app.overlays.detailItem = item }
        }
        #endif
    }

    // MARK: - Actions

    private func handleTap() {
        #if os(tvOS)
        if isMultiSelectActive {
            app.toggleSelection(item.id)
        } else {
            app.beginQuickMove(item)
        }
        #else
        // On macOS, clicking a card updates focus for keyboard navigation
        // The actual QuickRank action is triggered by Space/Return on the grid
        if isMultiSelectActive {
            app.toggleSelection(item.id)
        } else {
            onTapFocus?()  // Update hardware focus to this card
            app.beginQuickRank(item)
        }
        #endif
    }

    // MARK: - Display

    private var displayLabel: String {
        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return item.id
    }

    @ViewBuilder
    private var cardBody: some View {
        #if os(tvOS)
        tvOSCardBody
        #else
        pointerCardBody
        #endif
    }

    #if os(tvOS)
    private var tvOSCardBody: some View {
        VStack(alignment: .leading, spacing: layout.verticalContentSpacing) {
            ThumbnailView(item: item, layout: layout)
            if layout.density.showsOnCardText {
                cardTextBlock(font: layout.titleFont, metadataFont: layout.metadataFont)
            }
        }
        .padding(layout.contentPadding)
        .frame(width: layout.cardWidth, alignment: .leading)
        .background(Palette.cardBackground)
        .cornerRadius(layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isMultiSelectActive && app.isSelected(item.id) {
                selectionBadge
            }
        }
    }
    #else
    private var pointerCardBody: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: layout.verticalContentSpacing) {
                ThumbnailView(item: item, layout: layout)
                if layout.showsText {
                    cardTextBlock(font: layout.titleFont, metadataFont: layout.metadataFont)
                }
            }
            .padding(layout.contentPadding)
            .frame(width: layout.cardWidth, alignment: .leading)
            .background(Palette.cardBackground)
            .cornerRadius(layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Palette.stroke.opacity(0.9), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isMultiSelectActive && app.isSelected(item.id) {
                    selectionBadge
                        .padding(6)
                }
            }

            let badgeData = tierBadgeData(for: item)
            DynamicTierBadgeView(label: badgeData.label, colorHex: badgeData.colorHex)
                .padding(layout.contentPadding * 0.6)
        }
    }
    #endif

    // MARK: - Text & Metadata

    private func cardTextBlock(font titleFont: Font, metadataFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayLabel)
                .font(titleFont)
                .foregroundColor(Palette.cardText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.82)
            if let metadata = metadataText {
                Text(metadata)
                    .font(metadataFont)
                    .foregroundStyle(Palette.cardTextDim)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataText: String? {
        #if os(tvOS)
        guard layout.density.showsOnCardText else { return nil }
        #else
        guard layout.showsText else { return nil }
        #endif

        if let status = item.status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return status
        }
        if let season = item.seasonString?.trimmingCharacters(in: .whitespacesAndNewlines), !season.isEmpty {
            return "Season \(season)"
        }
        return nil
    }

    // MARK: - Selection Badge

    private var selectionBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(Palette.textOnAccent, Color.accentColor)
            .accessibilityLabel("Selected")
            .padding(.all, 6)
            .background(
                Circle().fill(Palette.bg.opacity(0.4))
            )
            #if os(tvOS)
            .offset(x: layout.contentPadding * 0.2, y: -layout.contentPadding * 0.2)
        #endif
    }

    // MARK: - Block Move (tvOS)

    #if os(tvOS)
    /// Handle block move for multi-select: move all selected items in a tier together
    private func handleBlockMove(tierName: String, direction: MoveCommandDirection) {
        guard let items = app.tiers[tierName] else { return }

        // Get indices of all selected items in this tier
        let selectedIndices = IndexSet(
            items.enumerated()
                .filter { app.selection.contains($0.element.id) }
                .map { $0.offset }
        )

        guard !selectedIndices.isEmpty else { return }

        // Calculate destination index based on direction
        let minIndex = selectedIndices.min() ?? 0
        let maxIndex = selectedIndices.max() ?? (items.count - 1)

        let destination: Int
        switch direction {
        case .left:
            // Move block one position to the left
            destination = max(0, minIndex - 1)
        case .right:
            // Move block one position to the right
            destination = min(items.count, maxIndex + 2)
        default:
            return
        }

        app.reorderBlock(in: tierName, from: selectedIndices, to: destination)
    }
    #endif
}
