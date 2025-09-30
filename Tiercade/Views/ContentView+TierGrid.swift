// Legacy TierGrid partial retained for reference. Actual implementation now lives
// under `Tiercade/Views/Main/ContentView+TierGrid.swift`. Wrapped in `#if false`
// so it no longer participates in builds.
#sourceLocation(file: "LegacyContentView+TierGrid.swift", line: 1)
#if false
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
                DragTargetHighlight(isTarget: app.dragTargetTier == "unranked", color: Palette.tierColor("unranked"))
            }
            #if !os(tvOS)
            .dropDestination(
                for: String.self,
                action: { items, _ in
                    if let id = items.first { app.move(id, to: "unranked") }
                    app.setDragTarget(nil)
                    app.setDragging(nil)
                    return true
                },
                isTargeted: { isTargeted in
                    app.setDragTarget(isTargeted ? "unranked" : nil)
                }
            )
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
        Button(
            action: {
                #if os(tvOS)
                if app.isMultiSelect { app.toggleSelection(item.id) } else { app.presentItemMenu(item) }
                #else
                app.beginQuickRank(item)
                #endif
            },
            label: {
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
        )
        #if os(tvOS)
        .buttonStyle(.plain)
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
        .accessibilityIdentifier("Card_\(item.id)")
        .scaleEffect(app.draggingId == item.id ? 0.98 : 1.0)
        .shadow(
            color: Color.black.opacity(app.draggingId == item.id ? 0.45 : 0.1),
            radius: app.draggingId == item.id ? 20 : 6,
            x: 0,
            y: app.draggingId == item.id ? 12 : 4
        )
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
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Palette.brand)
                                    .overlay(
                                        Text((item.name ?? item.id).prefix(12))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    )
                            @unknown default:
                                RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                            }
                        }
                        .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Palette.brand)
                            .overlay(
                                Text((item.name ?? item.id).prefix(12))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            )
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
#sourceLocation()
#endif // legacy TierGrid partial disabled
