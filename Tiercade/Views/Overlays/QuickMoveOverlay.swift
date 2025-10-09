import SwiftUI
import TiercadeCore

#if os(tvOS)
struct QuickMoveOverlay: View {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode

    var body: some View {
        if let item = app.quickMoveTarget {
            let isBatchMode = app.batchQuickMoveActive
            let title = isBatchMode
                ? "Move \(app.selection.count) Items"
                : item.name ?? item.id
            let allTiers = app.tierOrder + ["unranked"]
            let currentTier = app.currentTier(of: item.id)
            let isMultiSelectActive = editMode?.wrappedValue == .active

            ZStack {
                // Background dimming (non-interactive)
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 28) {
                    // Title
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Tier selection - use ScrollView + VStack for reliable tvOS focus
                    ScrollView {
                        tvGlassContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ForEach(allTiers, id: \.self) { tierName in
                                    TierButton(
                                        tierName: tierName,
                                        displayLabel: app.displayLabel(for: tierName),
                                        tierColor: Palette.tierColor(tierName),
                                        itemCount: app.tiers[tierName]?.count ?? 0,
                                        isCurrentTier: !isBatchMode && currentTier == tierName,
                                        action: { app.commitQuickMove(to: tierName) }
                                    )
                                    .accessibilityIdentifier("QuickMove_\(tierName)")
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: 600)

                    Divider()
                        .opacity(0.3)
                        .padding(.horizontal, 24)

                    // Secondary actions
                    HStack(spacing: 16) {
                        // Single-item actions (not in batch mode)
                        if !isBatchMode {
                            if isMultiSelectActive {
                                Button(app.isSelected(item.id) ? "Remove from Selection" : "Add to Selection") {
                                    app.toggleSelection(item.id)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("QuickMove_ToggleSelection")
                            }

                            Button("View Details") {
                                app.detailItem = item
                                app.cancelQuickMove()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("QuickMove_ViewDetails")
                        }

                        Spacer()

                        Button("Cancel", role: .cancel) {
                            app.cancelQuickMove()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("QuickMove_Cancel")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(32)
                .tvGlassRounded(28)
                .shadow(color: Color.black.opacity(0.22), radius: 24, y: 8)
                .focusSection()
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityIdentifier("QuickMove_Overlay")
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// Simplified tier button component - relies on SwiftUI default focus behavior
private struct TierButton: View {
    let tierName: String
    let displayLabel: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    let action: () -> Void

    var body: some View {
        Button(
            action: { if !isCurrentTier { action() } },
            label: {
            HStack(spacing: 16) {
                // Tier label
                Text(displayLabel)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 60, alignment: .leading)

                // Item count (with fixed space reservation)
                Group {
                    if itemCount > 0 {
                        Text("\(itemCount)")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("")
                            .font(.title3.weight(.medium))
                            .hidden()
                    }
                }
                .frame(minWidth: 40, alignment: .leading)

                Spacer()

                // Current tier indicator (with fixed space reservation)
                Group {
                    if isCurrentTier {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(tierColor)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .hidden()
                    }
                }
                .frame(width: 30)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .tvGlassRounded(16)
            .tint(tierColor.opacity(isCurrentTier ? 0.36 : 0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tierColor.opacity(isCurrentTier ? 0.95 : 0.55), lineWidth: isCurrentTier ? 3 : 2)
            )
            }
        )
        .buttonStyle(.plain)
        .disabled(isCurrentTier)
        .accessibilityLabel(isCurrentTier ? "Current tier: \(displayLabel)" : "Move to \(displayLabel)")
    }
}
#endif
