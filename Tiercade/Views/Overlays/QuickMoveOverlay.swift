import SwiftUI
import TiercadeCore

#if os(tvOS)
internal struct QuickMoveOverlay: View {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode
    @FocusState private var focusedElement: FocusElement?

    private enum FocusElement: Hashable {
        case tier(String)
        case toggleSelection
        case details
        case cancel
    }

    internal var body: some View {
        if let item = app.quickMoveTarget {
            let isBatchMode = app.batchQuickMoveActive
            let title = isBatchMode
                ? "Move \(app.selection.count) Items"
                : item.name ?? item.id
            let allTiers = app.tierOrder + ["unranked"]
            let currentTier = app.currentTier(of: item.id)
            let isMultiSelectActive = editMode?.wrappedValue == .active
            let computeDefaultFocus: () -> FocusElement = {
                guard let target = app.quickMoveTarget else { return .cancel }
                return resolvedDefaultFocus(
                    tiers: allTiers,
                    currentTier: app.currentTier(of: target.id),
                    isBatchMode: app.batchQuickMoveActive,
                    hasSelectionControls: (editMode?.wrappedValue == .active) && !app.batchQuickMoveActive
                )
            }
            let defaultFocus = computeDefaultFocus()

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
                                    .focused($focusedElement, equals: .tier(tierName))
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: 600)
                    .focusSection()

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
                                .focused($focusedElement, equals: .toggleSelection)
                            }

                            Button("View Details") {
                                app.detailItem = item
                                app.cancelQuickMove()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("QuickMove_ViewDetails")
                            .focused($focusedElement, equals: .details)
                        }

                        Spacer()

                        Button("Cancel", role: .cancel) {
                            app.cancelQuickMove()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("QuickMove_Cancel")
                        .focused($focusedElement, equals: .cancel)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(32)
                .tvGlassRounded(28)
                .shadow(color: Color.black.opacity(0.22), radius: 24, y: 8)
                .focusSection()
                .defaultFocus($focusedElement, defaultFocus)
                .onAppear { focusedElement = defaultFocus }
                .onDisappear { focusedElement = nil }
                .onChange(of: app.batchQuickMoveActive) { _, _ in
                    focusedElement = computeDefaultFocus()
                }
                .onChange(of: app.quickMoveTarget?.id) { _, _ in
                    focusedElement = computeDefaultFocus()
                }
                .onChange(of: editMode?.wrappedValue) { _, _ in
                    focusedElement = computeDefaultFocus()
                }
                .onExitCommand { app.cancelQuickMove() }
                .accessibilityIdentifier("QuickMove_Overlay")
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    private func resolvedDefaultFocus(
        tiers: [String],
        currentTier: String?,
        isBatchMode: Bool,
        hasSelectionControls: Bool
    ) -> FocusElement {
        if hasSelectionControls {
            return .toggleSelection
        }

        if isBatchMode {
            if let first = tiers.first {
                return .tier(first)
            }
            return .cancel
        }

        if let currentTier,
           let firstAlternative = tiers.first(where: { $0 != currentTier }) {
            return .tier(firstAlternative)
        }

        if let currentTier, tiers.contains(currentTier) {
            return .cancel
        }

        if let first = tiers.first {
            return .tier(first)
        }

        return .cancel
    }
}

// Simplified tier button component - relies on SwiftUI default focus behavior
private struct TierButton: View {
    internal let tierName: String
    internal let displayLabel: String
    internal let tierColor: Color
    internal let itemCount: Int
    internal let isCurrentTier: Bool
    internal let action: () -> Void

    internal var body: some View {
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
        .focusable(!isCurrentTier, interactions: .activate)
        .accessibilityLabel(isCurrentTier ? "Current tier: \(displayLabel)" : "Move to \(displayLabel)")
    }
}
#endif
