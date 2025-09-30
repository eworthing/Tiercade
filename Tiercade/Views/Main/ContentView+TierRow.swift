import SwiftUI
import TiercadeCore

struct TierRowView: View {
    @EnvironmentObject var app: AppState
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
    let components = parseRGB(hex: hex)
    let backgroundLuminance = luminance(for: components)
    let whiteContrast = contrast(between: 1.0, and: backgroundLuminance)
    let blackContrast = contrast(between: backgroundLuminance, and: 0.0)
    if whiteContrast >= 4.5 && whiteContrast >= blackContrast {
        return Color.wideGamut("#FFFFFFE6")
    }
    if blackContrast >= 4.5 && blackContrast > whiteContrast {
        return Color.wideGamut("#000000E6")
    }
    return whiteContrast >= blackContrast
        ? Color.wideGamut("#FFFFFFE6")
        : Color.wideGamut("#000000E6")
}

private struct RGBComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

private func parseRGB(hex: String) -> RGBComponents {
    var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if sanitized.hasPrefix("#") { sanitized.removeFirst() }
    if sanitized.count == 8 { sanitized = String(sanitized.prefix(6)) }
    guard sanitized.count == 6 else { return RGBComponents(red: 1, green: 1, blue: 1) }
    let red = CGFloat(Int(sanitized.prefix(2), radix: 16) ?? 255) / 255.0
    let green = CGFloat(Int(sanitized.dropFirst(2).prefix(2), radix: 16) ?? 255) / 255.0
    let blue = CGFloat(Int(sanitized.suffix(2), radix: 16) ?? 255) / 255.0
    return RGBComponents(red: red, green: green, blue: blue)
}

private func luminance(for components: RGBComponents) -> CGFloat {
    func linearize(_ channel: CGFloat) -> CGFloat {
        channel <= 0.04045
            ? (channel / 12.92)
            : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(components.red)
        + 0.7152 * linearize(components.green)
        + 0.0722 * linearize(components.blue)
}

private func contrast(between first: CGFloat, and second: CGFloat) -> CGFloat {
    let L1 = max(first, second)
    let L2 = min(first, second)
    return (L1 + 0.05) / (L2 + 0.05)
}
