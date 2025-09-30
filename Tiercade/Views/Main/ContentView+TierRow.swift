import SwiftUI
import TiercadeCore

struct TierRowWrapper: View {
    @Environment(AppState.self) private var app: AppState
    let tier: String
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            Text(tier.uppercased())
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(
                    dynamicTextOn(
                        hex: app.displayColorHex(for: tier) ?? defaultHex(for: tier)
                    )
                )
        }
        .frame(width: 48, height: 48)
        .padding(.horizontal, Metrics.grid)
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
            #if os(tvOS)
            TierHeaderView(tierId: tier, titleColor: Color.textPrimary)
            #else
            Text(app.displayLabel(for: tier))
                .font(TypeScale.h3)
                .foregroundColor(Color.textPrimary)
            #endif
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
