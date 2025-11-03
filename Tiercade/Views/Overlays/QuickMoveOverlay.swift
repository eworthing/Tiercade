import SwiftUI
import TiercadeCore

#if os(tvOS)
internal struct QuickMoveOverlay: View {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode
    @FocusState private var focusedElement: FocusElement?
    @Namespace private var quickMoveFocusScope

    internal enum FocusElement: Hashable {
        case tier(String)
        case toggleSelection
        case details
        case cancel
    }

    internal var body: some View {
        if let item = app.overlays.quickMoveTarget {
            let isBatchMode = app.batchQuickMoveActive
            let title = isBatchMode ? "Move \(app.selection.count) Items" : (item.name ?? item.id)
            let allTiers = app.tierOrder + [TierIdentifier.unranked.rawValue]
            let currentTier = app.currentTier(of: item.id)
            let isMultiSelectActive = editMode?.wrappedValue == .active

            ZStack {
                // Background dimming
                Color.black.opacity(OpacityTokens.scrim)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: SpacingTokens.verticalSpacing) {
                    // Title
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Tier buttons
                    tierButtons(
                        item: item,
                        allTiers: allTiers,
                        currentTier: currentTier,
                        isBatchMode: isBatchMode
                    )

                    Divider()
                        .opacity(OpacityTokens.divider)
                        .padding(.horizontal, SpacingTokens.horizontalPadding)

                    // Action buttons
                    actionButtons(
                        item: item,
                        isBatchMode: isBatchMode,
                        isMultiSelectActive: isMultiSelectActive
                    )
                }
                .padding(SpacingTokens.overlayPadding)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(OpacityTokens.containerBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 24, y: 8)
                .focusScope(quickMoveFocusScope)
                .onMoveCommand(perform: handleMoveCommand)
                .defaultFocus($focusedElement, defaultFocus(
                    currentTier: currentTier,
                    allTiers: allTiers,
                    isBatchMode: isBatchMode,
                    isMultiSelectActive: isMultiSelectActive
                ))
                .onAppear {
                    focusedElement = defaultFocus(
                        currentTier: currentTier,
                        allTiers: allTiers,
                        isBatchMode: isBatchMode,
                        isMultiSelectActive: isMultiSelectActive
                    )
                }
                .onDisappear { focusedElement = nil }
                .onExitCommand { app.cancelQuickMove() }
                .accessibilityIdentifier("QuickMove_Overlay")
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    @ViewBuilder
    private func tierButtons(
        item: Item,
        allTiers: [String],
        currentTier: String?,
        isBatchMode: Bool
    ) -> some View {
        ScrollView {
            tvGlassContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(allTiers, id: \.self) { tierName in
                        TierButton(
                            tierName: tierName,
                            displayLabel: app.displayLabel(for: tierName),
                            tierColor: Palette.tierColor(tierName, from: app.tierColors),
                            itemCount: app.tiers[tierName]?.count ?? 0,
                            isCurrentTier: !isBatchMode && currentTier == tierName,
                            isFocused: focusedElement == .tier(tierName),
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
    }

    @ViewBuilder
    private func actionButtons(
        item: Item,
        isBatchMode: Bool,
        isMultiSelectActive: Bool
    ) -> some View {
        HStack(spacing: 16) {
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
                    app.overlays.detailItem = item
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

    private func defaultFocus(
        currentTier: String?,
        allTiers: [String],
        isBatchMode: Bool,
        isMultiSelectActive: Bool
    ) -> FocusElement {
        if isMultiSelectActive && !isBatchMode {
            return .toggleSelection
        }

        if isBatchMode {
            return allTiers.first.map { .tier($0) } ?? .cancel
        }

        if let currentTier,
           let firstAlternative = allTiers.first(where: { $0 != currentTier }) {
            return .tier(firstAlternative)
        }

        if let currentTier, allTiers.contains(currentTier) {
            return .cancel
        }

        return allTiers.first.map { .tier($0) } ?? .cancel
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        let allTiers = app.tierOrder + [TierIdentifier.unranked.rawValue]

        // Trap up-arrow when at first tier
        if direction == .up {
            if case .tier(let tierName) = focusedElement,
               tierName == allTiers.first {
                focusedElement = .tier(allTiers.first ?? TierIdentifier.unranked.rawValue)
                return
            }
        }

        // Trap down-arrow when at bottom
        if direction == .down {
            if focusedElement == .cancel {
                focusedElement = .cancel
                return
            }
        }

        // Trap left/right to prevent horizontal escape
        if direction == .left || direction == .right {
            if case .tier(let tierName) = focusedElement {
                focusedElement = .tier(tierName)
                return
            }
        }
    }
}

// Simplified tier button component
private struct TierButton: View {
    let tierName: String
    let displayLabel: String
    let tierColor: Color
    let itemCount: Int
    let isCurrentTier: Bool
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if !isCurrentTier { action() } }) {
            HStack(spacing: 16) {
                Text(displayLabel)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 60, alignment: .leading)

                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40, alignment: .leading)
                } else {
                    Text("")
                        .font(.title3.weight(.medium))
                        .hidden()
                        .frame(minWidth: 40, alignment: .leading)
                }

                Spacer()

                if isCurrentTier {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tierColor)
                        .frame(width: 30)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .hidden()
                        .frame(width: 30)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .tvGlassRounded(16)
            .tint(tierColor.opacity(isCurrentTier ? OpacityTokens.focusedTint : OpacityTokens.unfocusedTint))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isFocused ? Color.white : tierColor.opacity(isCurrentTier ? 0.95 : 0.55),
                        lineWidth: isFocused ? 4 : (isCurrentTier ? 3 : 2)
                    )
            )
        }
        .buttonStyle(.tvRemote(.secondary))
        .accessibilityLabel(isCurrentTier ? "Current tier: \(displayLabel)" : "Move to \(displayLabel)")
        .accessibilityHint(isCurrentTier ? "Already in this tier" : "Select to move")
    }
}
#endif
