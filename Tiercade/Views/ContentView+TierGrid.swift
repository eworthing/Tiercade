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
        .background(
            LinearGradient(gradient: .tierListBackground, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

struct TierRowView: View {
    @EnvironmentObject var app: AppState
    let tier: String
    #if os(tvOS)
    @FocusState private var focusedCardId: String?
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
            VStack(alignment: .leading, spacing: Metrics.grid) {
                HStack {
                    #if os(tvOS)
                    TierHeaderView(tierId: tier)
                    #else
                    Text(app.displayLabel(for: tier))
                        .font(TypeScale.h3)
                        .foregroundColor(Palette.text)
                    #endif
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredCards.count)/\(app.tierCount(tier))")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    }
                }

                #if os(tvOS)
                if filteredCards.count >= TierRowPerformance.limit {
                    CollectionTierRowContainer(
                        tierName: tier,
                        items: filteredCards,
                        onSelect: { item in
                            if app.isMultiSelect { app.toggleSelection(item.id) } else { app.presentItemMenu(item) }
                        },
                        onPlayPause: { item in
                            if app.isMultiSelect { app.toggleSelection(item.id) } else { app.beginQuickMove(item) }
                        },
                        selectedIds: app.selection,
                        isMultiSelect: app.isMultiSelect
                    )
                    .frame(height: 260)
                    .focusSection()
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 10) {
                            ForEach(filteredCards, id: \.id) { item in
                                CardView(item: item)
                                    .focused($focusedCardId, equals: item.id)
                            }
                        }
                        .padding(.bottom, Metrics.grid * 0.5)
                    }
                    .focusSection()
                    .onAppear { focusedCardId = filteredCards.first?.id }
                }
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
            .background(
                ZStack {
                    if let hex = app.displayColorHex(for: tier), let color = Color(hex: hex) {
                        RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12))
                    }
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                }
            )
            .overlay(
                Group {
                    if let hex = app.displayColorHex(for: tier), let color = Color(hex: hex) {
                        RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1)
                    } else { EmptyView() }
                }
            )
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == tier, color: Palette.tierColor(tier))
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

struct UnrankedView: View {
    @EnvironmentObject var app: AppState
    #if os(tvOS)
    @FocusState private var focusedCardId: String?
    #endif

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
                        .foregroundColor(Palette.text)
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredItems.count)/\(app.unrankedCount())")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    } else {
                        Text("\(filteredItems.count)")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)]) {
                    ForEach(filteredItems, id: \.id) { item in
                        CardView(item: item)
                        #if !os(tvOS)
                            .draggable(item.id)
                        #else
                            .focused($focusedCardId, equals: item.id)
                        #endif
                    }
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
            .padding(Metrics.grid * 1.5)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary))
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == "unranked", color: Palette.tierColor("F"))
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
            .onAppear { focusedCardId = filteredItems.first?.id }
            #endif
        }
    }
}

struct CardView: View {
    let item: Item
    @EnvironmentObject var app: AppState
    var body: some View {
        Button(action: {
            #if os(tvOS)
            if app.isMultiSelect { app.toggleSelection(item.id) } else { app.presentItemMenu(item) }
            #else
            app.beginQuickRank(item)
            #endif
        }) {
            VStack(spacing: 8) {
                ThumbnailView(item: item)
                Text("S \(item.seasonString ?? "?")").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(Metrics.grid)
            .card()
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("Card_\(item.id)")
        .scaleEffect(app.draggingId == item.id ? 0.98 : 1.0)
        .shadow(color: Color.black.opacity(app.draggingId == item.id ? 0.45 : 0.1), radius: app.draggingId == item.id ? 20 : 6, x: 0, y: app.draggingId == item.id ? 12 : 4)
        .contentShape(Rectangle())
        .accessibilityLabel(item.name ?? item.id)
        #if os(macOS)
        .focusable(true)
        .accessibilityAddTraits(.isButton)
        #endif
        #if !os(tvOS)
        .onDrag {
            app.setDragging(item.id)
            return NSItemProvider(object: NSString(string: item.id))
        }
        #endif
        #if os(tvOS)
        .focusable(true)
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
            Button("View Details") { app.detailItem = item }
        }
        #endif
    }
}

struct ThumbnailView: View {
    let item: Item
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .frame(minWidth: 120, idealWidth: 140, minHeight: 72, idealHeight: 88)
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
