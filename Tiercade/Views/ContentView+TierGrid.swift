import SwiftUI
import TiercadeCore

// MARK: - Tier grid
struct TierGridView: View {
    @EnvironmentObject var app: AppState
    let tierOrder: [String]
    private var columns: [GridItem] { Array(repeating: GridItem(.adaptive(minimum: 180), spacing: 12), count: 1) }

    var body: some View {
        ScrollView {
                LazyVStack(spacing: 16) {
                ForEach(tierOrder, id: \.self) { tier in
                    TierRowView(tier: tier)
                }
                UnrankedView()
                }
                .padding(Metrics.grid * 2)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

struct TierRowView: View {
    @EnvironmentObject var app: AppState
    let tier: String
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    #endif

    var filteredCards: [Item] {
        let allCards = app.items(for: tier)

        // Apply global filter
        switch app.activeFilter {
        case .all:
            break // Show all from this tier
        case .ranked:
            if tier == "unranked" { return [] } // Hide unranked when filter is "ranked"
        case .unranked:
            if tier != "unranked" { return [] } // Hide ranked tiers when filter is "unranked"
        }

        // Apply search filter
        return app.applySearchFilter(to: allCards)
    }

    var body: some View {
        if !filteredCards.isEmpty {
            // Accent color for this tier (used for colored square)
            let accent: Color = {
                if let hex = app.displayColorHex(for: tier), let c = Color(hex: hex) { return c }
                switch tier.uppercased() {
                case "S": return .tierS
                case "A": return .tierA
                case "B": return .tierB
                case "C": return .tierC
                case "D": return .tierD
                default: return .tierF
                }
            }()

            HStack(spacing: 0) {
                // Leading colored square with tier letter
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    Text(tier.uppercased())
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(dynamicTextOn(hex: app.displayColorHex(for: tier) ?? {
                            switch tier.uppercased() {
                            case "S": return "#FF0037"
                            case "A": return "#FFA000"
                            case "B": return "#00EC57"
                            case "C": return "#00D9FE"
                            case "D": return "#1E3A8A"
                            default: return "#808080"
                            }
                        }()))
                }
                .frame(width: 48, height: 48)
                .padding(.leading, Metrics.grid * 1.0)
                .padding(.trailing, Metrics.grid * 1.0)

                VStack(alignment: .leading, spacing: Metrics.grid) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        // Title (neutral); no redundant letter here
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

                    #if os(tvOS)
                    // SwiftUI-only row for tvOS with seeded default focus
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
                .padding(Metrics.grid * 1.5)
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
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: tier) }
                app.setDragTarget(nil)
                app.setDragging(nil)
                return true
            } isTargeted: { isTargeted in
                app.setDragTarget(isTargeted ? tier : nil)
            }
            #endif
        }
    }
}

// MARK: - Row text contrast helpers
private func rowTitleColor(for tier: String, customHex: String?) -> Color {
    let hex: String = customHex ?? {
        switch tier.uppercased() {
        case "S": return "#FF0037"
        case "A": return "#FFA000"
        case "B": return "#00EC57"
        case "C": return "#00D9FE"
        case "D": return "#1E3A8A"
        default: return "#808080"
        }
    }()
    return dynamicTextOn(hex: hex)
}

private func dynamicTextOn(hex: String) -> Color {
    // Compute luminance of the background and pick black/white accordingly (>=4.5:1 when possible)
    func parse(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 8 { s = String(s.prefix(6)) }
        guard s.count == 6 else { return (1,1,1) }
        let r = CGFloat(Int(s.prefix(2), radix: 16) ?? 255) / 255.0
        let g = CGFloat(Int(s.dropFirst(2).prefix(2), radix: 16) ?? 255) / 255.0
        let b = CGFloat(Int(s.suffix(2), radix: 16) ?? 255) / 255.0
        return (r,g,b)
    }
    func lin(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? (c/12.92) : pow((c+0.055)/1.055, 2.4) }
    func lum(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat { 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b) }
    func contrast(_ a: CGFloat, _ b: CGFloat) -> CGFloat { let L1 = max(a,b), L2 = min(a,b); return (L1+0.05)/(L2+0.05) }
    let (r,g,b) = parse(hex)
    let Lbg = lum(r,g,b)
    let Lw: CGFloat = 1.0
    let Lk: CGFloat = 0.0
    let cw = contrast(Lw, Lbg)
    let ck = contrast(Lbg, Lk)
    if cw >= 4.5 && cw >= ck { return Color.wideGamut("#FFFFFFE6") }
    if ck >= 4.5 && ck > cw { return Color.wideGamut("#000000E6") }
    return cw >= ck ? Color.wideGamut("#FFFFFFE6") : Color.wideGamut("#000000E6")
}

struct UnrankedView: View {
    @EnvironmentObject var app: AppState

    var filteredItems: [Item] {
        let allUnranked = app.items(for: "unranked")

        // Apply global filter
        switch app.activeFilter {
        case .all, .unranked:
            break // Show unranked
        case .ranked:
            return [] // Hide unranked when filter is "ranked"
        }

        // Apply search filter
        return app.applySearchFilter(to: allUnranked)
    }

    var body: some View {
        if !filteredItems.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                HStack {
                    Text("Unranked")
                        .font(TypeScale.h3)
                        .foregroundColor(Color.textPrimary)
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredItems.count)/\(app.unrankedCount())")
                            .font(TypeScale.label)
                                        .foregroundColor(Color.textPrimary)
                    } else {
                        Text("\(filteredItems.count)")
                            .font(TypeScale.label)
                                        .foregroundColor(Color.textPrimary)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 24)]) {
                    ForEach(filteredItems, id: \.id) { item in
                        CardView(item: item)
                        #if !os(tvOS)
                            .draggable(item.id)
                        #endif
                    }
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
            .padding(Metrics.grid * 1.5)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.stroke, lineWidth: 1)
            )
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == "unranked", color: Color.tierF)
            }
            #if !os(tvOS)
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: "unranked") }
                app.setDragTarget(nil)
                app.setDragging(nil)
                return true
            } isTargeted: { isTargeted in
                app.setDragTarget(isTargeted ? "unranked" : nil)
            }
            #else
            #endif
        }
    }
}

struct CardView: View {
    let item: Item
    @EnvironmentObject var app: AppState
    @Environment(\.isFocused) var isFocused: Bool

    private func tierForItem(_ item: Item) -> Tier {
        // Heuristic: infer tier from current placement when available; default F
        let t = app.currentTier(of: item.id) ?? "F"
        switch t.uppercased() {
        case "S": return .s
        case "A": return .a
        case "B": return .b
        case "C": return .c
        case "D": return .d
        default: return .f
        }
    }

    var body: some View {
        Button(action: {
            #if os(tvOS)
            if app.isMultiSelect { app.toggleSelection(item.id) } else { app.presentItemMenu(item) }
            #else
            app.beginQuickRank(item)
            #endif
        }) {
            ZStack(alignment: .topLeading) {
                // Card surface and image
                VStack(spacing: 8) {
                    ThumbnailView(item: item)
                    Text("S \(item.seasonString ?? "?")").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(Metrics.grid)
                .background(Color.cardBackground)
                .cornerRadius(12)
                #if !os(tvOS)
                // Tier chip (not shown on tvOS)
                TierBadgeView(tier: tierForItem(item))
                    .padding(10)
                #endif
            }
            #if os(tvOS)
            .overlay(alignment: .topTrailing) {
                if app.isMultiSelect && app.isSelected(item.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                        .offset(x: 6, y: -6)
                }
            }
            #endif
        }
        #if os(tvOS)
        .buttonStyle(.plain)
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
        .accessibilityIdentifier("Card_\(item.id)")
        .scaleEffect(app.draggingId == item.id ? 0.98 : 1.0)
        .shadow(color: Color.black.opacity(app.draggingId == item.id ? 0.45 : 0.1), radius: app.draggingId == item.id ? 20 : 6, x: 0, y: app.draggingId == item.id ? 12 : 4)
        .contentShape(Rectangle())
        .accessibilityLabel(item.name ?? item.id)
        .focusable(true)
        .punchyFocus(tier: tierForItem(item), cornerRadius: 12)
    // tvOS scale handled by punchyFocus; avoid duplicate scaling
        #if os(macOS)
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
            if app.isMultiSelect {
                app.toggleSelection(item.id)
            } else {
                app.beginQuickMove(item)
            }
        }
        .contextMenu {
            ForEach(app.tierOrder, id: \.self) { t in
                Button("Move to \(t)") { app.move(item.id, to: t) }
            }
            Button("Move to Unranked") { app.move(item.id, to: "unranked") }
            Button("View Details") { app.detailItem = item }
        }
        #endif
    }
}

struct ThumbnailView: View {
    let item: Item
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .frame(minWidth: 120, idealWidth: 140, minHeight: 168, idealHeight: 196)
            .overlay(
                Group {
                    if let thumb = item.imageUrl ?? item.videoUrl, let url = URL(string: thumb) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                                    .overlay(Text((item.name ?? item.id).prefix(12)).font(.headline).foregroundStyle(.white))
                            @unknown default:
                                RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                            }
                        }
                        .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                            .overlay(Text((item.name ?? item.id).prefix(12)).font(.headline).foregroundStyle(.white))
                    }
                }
            )
    }
}

private extension Gradient {
    static var tierListBackground: Gradient { .init(colors: [Color.black.opacity(0.6), Color.blue.opacity(0.2)]) }
}

#Preview("iPhone") { ContentView() }
#Preview("iPad") { ContentView() }
#if os(tvOS)
#Preview("tvOS") { ContentView() }
#endif
