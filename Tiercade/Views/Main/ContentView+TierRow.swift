import SwiftUI
import TiercadeCore

struct TierRowWrapper: View {
    @Environment(AppState.self) private var app: AppState
    let tier: String
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    @State private var showMenu = false
    #endif

    private var filteredCards: [Item] {
        let allCards = app.items(for: tier)

        switch app.activeFilter {
        case .all:
            break
        case .ranked:
            if tier == "unranked" { return [] }
        case .unranked:
            if tier != "unranked" { return [] }
        }

        return app.applySearchFilter(to: allCards)
    }

    var body: some View {
        if !filteredCards.isEmpty {
            let accent = tierAccentColor()

            HStack(spacing: 0) {
                tierBadge(accent: accent)
                tierContent(accent: accent)
            }
            // NOTE: Don't set accessibilityIdentifier on parent - it overrides children!
            // Individual cards and buttons have their own IDs
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.stroke, lineWidth: 1)
            )
            .overlay {
                DragTargetHighlight(
                    isTarget: app.dragTargetTier == tier,
                    color: accent
                )
            }
            #if !os(tvOS)
            .dropDestination(
                for: String.self,
                action: { items, _ in
                    if let id = items.first { app.move(id, to: tier) }
                    app.setDragTarget(nil)
                    app.setDragging(nil)
                    return true
                },
                isTargeted: { isTargeted in
                    app.setDragTarget(isTargeted ? tier : nil)
                }
            )
            #endif
        }
    }

    private func tierAccentColor() -> Color {
        if let hex = app.displayColorHex(for: tier), let color = Color(hex: hex) {
            return color
        }
        switch tier.uppercased() {
        case "S": return .tierS
        case "A": return .tierA
        case "B": return .tierB
        case "C": return .tierC
        case "D": return .tierD
        default: return .tierF
        }
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
                    .foregroundColor(Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var cardsSection: some View {
        #if os(tvOS)
        ScrollView(.horizontal) {
            LazyHStack(spacing: 24) {
                ForEach(filteredCards, id: \.id) { item in
                    CardView(item: item)
                        .focused($focusedItemId, equals: item.id)
                }
            }
            .padding(.bottom, Metrics.grid * 0.5)
        }
        .accessibilityIdentifier("TierRow_\(tier)")
        .focusSection()
        .defaultFocus($focusedItemId, filteredCards.first?.id)
        #else
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(filteredCards, id: \.id) { item in
                    CardView(item: item)
                        .draggable(item.id)
                }
            }
            .padding(.bottom, Metrics.grid * 0.5)
        }
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
}

// MARK: - Contrast Helpers

private func dynamicTextOn(hex: String) -> Color {
    // Use consolidated ColorUtilities instead of duplicated logic
    ColorUtilities.accessibleTextColor(onBackground: hex)
}

// MARK: - Color Extension

extension Color {
    func toHex() -> String? {
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
    let label: String
    let textColor: Color

    var body: some View {
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
    let tier: String
    let isLocked: Bool
    let textColor: Color
    let onToggleLock: () -> Void
    let onShowMenu: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onToggleLock, label: {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 24))
                    .foregroundColor(textColor)
            })
            .buttonStyle(.plain)
            .accessibilityIdentifier("TierRow_\(tier)_Lock")
            .accessibilityLabel(isLocked ? "Unlock Tier" : "Lock Tier")
            .focusTooltip(isLocked ? "Unlock" : "Lock")

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
}

private struct TierLabelEditor: View {
    @Bindable var app: AppState
    let tierId: String
    @Binding var showMenu: Bool
    @State private var label: String = ""
    @State private var colorHex: String = ""
    @State private var showAdvancedColor: Bool = false

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

    var body: some View {
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
                    Button("Apply") {
                        app.setDisplayLabel(label, for: tierId)
                        app.showInfoToast("Renamed", message: "Tier \(tierId) → \(label)")
                    }
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

                if showAdvancedColor {
                    HStack(spacing: 12) {
                        TextField("Hex Color (e.g., #E11D48)", text: $colorHex)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(width: 360)
                        Button("Set") {
                            app.setDisplayColorHex(colorHex, for: tierId)
                            app.showInfoToast("Recolored", message: colorHex)
                        }
                    }
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(app.isTierLocked(tierId) ? "Unlock" : "Lock") {
                    app.toggleTierLocked(tierId)
                }
                .buttonStyle(.borderedProminent)
                Button("Clear Tier") {
                    app.clearTier(tierId)
                }
                .buttonStyle(.bordered)
                Button("Close", role: .cancel) { showMenu = false }
            }
        }
        .padding(24)
        .onAppear {
            label = app.displayLabel(for: tierId)
            if let hex = app.displayColorHex(for: tierId) {
                colorHex = hex
            }
        }
    }
}
#endif
