import SwiftUI
import TiercadeCore
import UniformTypeIdentifiers

#if !os(tvOS)
internal struct CardFocus: Hashable {
    internal let tier: String
    internal let itemID: String
}
#endif

internal struct TierRowWrapper: View {
    @Environment(AppState.self) private var app: AppState
    internal let tier: String
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    @State private var showMenu = false
    #else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    internal let hardwareFocus: FocusState<CardFocus?>.Binding
    #endif

    private var filteredCards: [Item] {
        app.filteredItems(for: tier)
    }

    internal var body: some View {
        if !filteredCards.isEmpty {
            let accent = tierAccentColor()

            HStack(spacing: 0) {
                tierBadge(accent: accent)
                tierContent(accent: accent)
            }
            // NOTE: Don't set accessibilityIdentifier on parent - it overrides children!
            // Individual cards and buttons have their own IDs
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Palette.stroke, lineWidth: 1)
            )
            .overlay {
                DragTargetHighlight(
                    isTarget: app.dragTargetTier == tier,
                    color: accent
                )
            }
            #if !os(tvOS)
            .onDrop(of: [.text], isTargeted: nil, perform: { providers in
                // Load NSItemProvider inside closure per security rules
                guard let provider = providers.first else {
                    app.setDragTarget(nil)
                    return false
                }

                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, error in
                    if let data = item as? Data, let id = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            app.move(id, to: tier)
                            app.setDragTarget(nil)
                            app.setDragging(nil)
                        }
                    }
                }
                return true
            })
            #endif
        }
    }

    private func tierAccentColor() -> Color {
        if let hex = app.displayColorHex(for: tier), let color = Color(hex: hex) {
            return color
        }
        if let resolved = Tier(rawValue: tier.lowercased()) {
            return resolved.color
        }
        return Tier.f.color
    }

    private func tierBadge(accent: Color) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            VerticalTierText(
                label: app.displayLabel(for: tier),
                textColor: dynamicTextOn(
                    hex: app.displayColorHex(for: tier) ?? defaultHex(for: tier)
                )
            )
            .layoutPriority(1)

            Spacer(minLength: 0)

            #if os(tvOS)
            TierControlButtons(
                tier: tier,
                isLocked: app.isTierLocked(tier),
                textColor: dynamicTextOn(
                    hex: app.displayColorHex(for: tier) ?? defaultHex(for: tier)
                ),
                onToggleLock: { app.toggleTierLocked(tier) },
                onShowMenu: { showMenu = true }
            )
            #endif
        }
        .padding(.vertical, Metrics.grid)
        .padding(.horizontal, Metrics.grid)
        .frame(width: 96)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        #if os(tvOS)
        .sheet(isPresented: $showMenu) {
            TierLabelEditor(app: app, tierId: tier, showMenu: $showMenu)
        }
        #endif
    }

    private func tierContent(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: Metrics.grid) {
            header
            cardsSection
        }
        .padding(Metrics.grid * 1.5)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Spacer()
            if !app.searchQuery.isEmpty || app.activeFilter != .all {
                Text("\(filteredCards.count)/\(app.tierCount(tier))")
                    .font(TypeScale.label)
                    .foregroundColor(Palette.cardTextDim)
            }
        }
    }

    @ViewBuilder
    private var cardsSection: some View {
        #if os(tvOS)
        let layout = TVMetrics.cardLayout(
            for: filteredCards.count,
            preference: app.cardDensityPreference
        )
        ScrollView(.horizontal) {
            LazyHStack(spacing: layout.interItemSpacing) {
                ForEach(filteredCards, id: \.id) { item in
                    CardView(item: item, layout: layout)
                        .focused($focusedItemId, equals: item.id)
                        .onMoveCommand { direction in
                            handleMoveCommand(for: item.id, in: tier, direction: direction)
                        }
                }
            }
            .padding(.horizontal, layout.contentPadding)
            .padding(.bottom, layout.interItemSpacing * 0.5)
        }
        .accessibilityIdentifier("TierRow_\(tier)")
        .focusSection()
        .defaultFocus($focusedItemId, filteredCards.first?.id)
        #else
        let layout = PlatformCardLayoutProvider.layout(
            for: filteredCards.count,
            preference: app.cardDensityPreference,
            horizontalSizeClass: horizontalSizeClass
        )

        LazyVGrid(
            columns: layout.gridColumns,
            alignment: .leading,
            spacing: layout.rowSpacing
        ) {
            ForEach(filteredCards, id: \.id) { item in
                let focusID = CardFocus(tier: tier, itemID: item.id)
                CardView(item: item, layout: layout, onTapFocus: {
                    // Update hardware focus when card is clicked
                    hardwareFocus.wrappedValue = focusID
                })
                .focused(hardwareFocus, equals: focusID)
                .overlay {
                    if hardwareFocus.wrappedValue == focusID {
                        RoundedRectangle(cornerRadius: layout.cornerRadius)
                            .stroke(Color.accentColor.opacity(0.85), lineWidth: 3)
                    }
                }
            }
        }
        .padding(.bottom, layout.rowSpacing * 0.5)
        .animation(reduceMotion ? nil : Motion.emphasis, value: filteredCards.count)
        #endif
    }

    private func defaultHex(for tier: String) -> String {
        switch tier.uppercased() {
        case "S": return "#FF0037"
        case "A": return "#FFA000"
        case "B": return "#00EC57"
        case "C": return "#00D9FE"
        case "D": return "#1E3A8A"
        default: return "#808080"
        }
    }

    #if os(tvOS)
    /// Handle move command for both single item and block moves
    private func handleMoveCommand(for itemId: String, in tierName: String, direction: MoveCommandDirection) {
        // Don't reorder if not in custom sort mode - let focus navigate
        guard app.globalSortMode.isCustom else { return }

        // Check if item is selected and we're in multi-select mode with multiple items
        #if os(tvOS)
        // tvOS doesn't have editMode, check selection directly
        if app.isSelected(itemId) && app.selection.count > 1 {
            handleBlockMove(tierName: tierName, direction: direction)
        } else {
            // Single item move
            switch direction {
            case .left:
                app.moveItemLeft(itemId, in: tierName)
            case .right:
                app.moveItemRight(itemId, in: tierName)
            default:
                break
            }
        }
        #endif
    }

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

// MARK: - Contrast Helpers

private func dynamicTextOn(hex: String) -> Color {
    // Use consolidated ColorUtilities instead of duplicated logic
    ColorUtilities.accessibleTextColor(onBackground: hex)
}

// MARK: - Color Extension

extension Color {
    internal func toHex() -> String? {
        #if os(tvOS) || os(iOS)
        guard let components = UIColor(self).cgColor.components else { return nil }
        #else
        guard let components = NSColor(self).cgColor.components else { return nil }
        #endif

        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Vertical Tier Components

private struct VerticalTierText: View {
    internal let label: String
    internal let textColor: Color

    internal var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let charCount = CGFloat(label.count)
            // Calculate ideal font size based on available space
            // Reserve 1pt spacing between chars: (availableHeight - (charCount-1)*1) / charCount
            let calculatedSize = (availableHeight - (charCount - 1) * 1) / charCount
            // Clamp between 16pt and 32pt for readability
            let fontSize = min(32, max(16, calculatedSize))

            VStack(spacing: 1) {
                ForEach(Array(label), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: fontSize, weight: .heavy, design: .default))
                        .tracking(-0.5)
                        .foregroundColor(textColor)
                        .minimumScaleFactor(0.5)
                        .frame(width: 56)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }
}

#if os(tvOS)
private struct TierControlButtons: View {
    internal let tier: String
    internal let isLocked: Bool
    internal let textColor: Color
    internal let onToggleLock: () -> Void
    internal let onShowMenu: () -> Void

    internal var body: some View {
        Button(action: onShowMenu, label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 24))
                .foregroundColor(textColor)
        })
        .buttonStyle(.plain)
        .accessibilityIdentifier("TierRow_\(tier)_Menu")
        .accessibilityLabel("Tier Menu")
        .focusTooltip("Menu")
    }
}

private struct TierLabelEditor: View {
    @Bindable var app: AppState
    internal let tierId: String
    @Binding var showMenu: Bool
    @State private var label: String = ""
    @State private var colorHex: String = ""
    @State private var showAdvancedColor: Bool = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case label
        case apply
        case colorOption(String)
        case advancedToggle
        case advancedHex
        case advancedSet
        case lock
        case clear
        case close
    }

    // Color picker options for tvOS
    private let colorOptions: [(String, String)] = [
        ("Red", "#FF0037"),
        ("Orange", "#FFA000"),
        ("Green", "#00EC57"),
        ("Cyan", "#00D9FE"),
        ("Blue", "#1E3A8A"),
        ("Purple", "#9333EA"),
        ("Pink", "#EC4899"),
        ("Gray", "#808080")
    ]

    internal var body: some View {
        VStack(spacing: 20) {
            Text("Tier \(tierId)").font(.title2)

            // Rename section
            VStack(alignment: .leading, spacing: 8) {
                Text("Label").font(.headline)
                HStack(spacing: 12) {
                    TextField("Rename", text: $label)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .frame(width: 360)
                        .focused($focusedField, equals: .label)
                    Button("Apply") {
                        app.setDisplayLabel(label, for: tierId)
                        app.showInfoToast("Renamed", message: "Tier \(tierId) → \(label)")
                    }
                    .focused($focusedField, equals: .apply)
                }
            }

            // Color picker section (tvOS compatible)
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.headline)

                // Color swatches
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                    ForEach(colorOptions, id: \.0) { name, hex in
                        Button(action: {
                            app.setDisplayColorHex(hex, for: tierId)
                            colorHex = hex
                            app.showInfoToast("Recolored", message: name)
                        }, label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 60, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(colorHex == hex ? Color.white : Color.clear, lineWidth: 3)
                                    )
                                Text(name)
                                    .font(.caption2)
                            }
                        })
                        .buttonStyle(.plain)
                        .focused($focusedField, equals: .colorOption(hex))
                    }
                }

                // Advanced hex input
                Button(action: { showAdvancedColor.toggle() }, label: {
                    HStack {
                        Text("Advanced")
                        Image(systemName: showAdvancedColor ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                })
                .focused($focusedField, equals: .advancedToggle)

                if showAdvancedColor {
                    HStack(spacing: 12) {
                        TextField("Hex Color (e.g., #E11D48)", text: $colorHex)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(width: 360)
                            .focused($focusedField, equals: .advancedHex)
                        Button("Set") {
                            app.setDisplayColorHex(colorHex, for: tierId)
                            app.showInfoToast("Recolored", message: colorHex)
                        }
                        .focused($focusedField, equals: .advancedSet)
                    }
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(app.isTierLocked(tierId) ? "Unlock" : "Lock") {
                    app.toggleTierLocked(tierId)
                }
                .buttonStyle(.borderedProminent)
                .focused($focusedField, equals: .lock)
                Button("Clear Tier") {
                    app.clearTier(tierId)
                }
                .buttonStyle(.bordered)
                .focused($focusedField, equals: .clear)
                Button("Close", role: .cancel) { showMenu = false }
                    .focused($focusedField, equals: .close)
            }
        }
        .padding(24)
        .onAppear {
            label = app.displayLabel(for: tierId)
            if let hex = app.displayColorHex(for: tierId) {
                colorHex = hex
            }
            focusedField = .label
        }
        .onDisappear { focusedField = nil }
        .focusSection()
        .defaultFocus($focusedField, .label)
        .onExitCommand { showMenu = false }
        .onChange(of: showAdvancedColor) { _, isExpanded in
            if !isExpanded,
               focusedField == .advancedHex || focusedField == .advancedSet {
                focusedField = .advancedToggle
            }
        }
    }
}
#endif
