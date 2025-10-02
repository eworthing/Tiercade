import SwiftUI
import TiercadeCore

// MARK: - Tier grid
struct TierGridView: View {
    @Environment(AppState.self) private var app: AppState
    let tierOrder: [String]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tierOrder, id: \.self) { tier in
                    TierRowWrapper(tier: tier)
                }
                UnrankedView()
            }
            #if os(tvOS)
            .padding(.horizontal, TVMetrics.contentHorizontalPadding)
            .padding(.vertical, Metrics.grid)
            #else
            .padding(Metrics.grid * 2)
            #endif
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

struct UnrankedView: View {
    @Environment(AppState.self) private var app: AppState
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    #endif

    private var filteredItems: [Item] {
        let allUnranked = app.items(for: "unranked")

        switch app.activeFilter {
        case .all, .unranked:
            break
        case .ranked:
            return []
        }

        return app.applySearchFilter(to: allUnranked)
    }

    var body: some View {
        if !filteredItems.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                header
                #if os(tvOS)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 24) {
                        ForEach(filteredItems, id: \.id) { item in
                            CardView(item: item)
                                .focused($focusedItemId, equals: item.id)
                        }
                    }
                    .padding(.bottom, Metrics.grid * 0.5)
                }
                .focusSection()
                .defaultFocus($focusedItemId, filteredItems.first?.id)
                #else
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(filteredItems, id: \.id) { item in
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
                RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Color.stroke, lineWidth: 1)
            )
            .overlay {
                DragTargetHighlight(
                    isTarget: app.dragTargetTier == "unranked",
                    color: Palette.tierColor("unranked")
                )
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
            #endif
        }
    }

    private var header: some View {
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
    }
}

struct CardView: View {
    let item: Item
    @Environment(AppState.self) var app
    @Environment(\.isFocused) var isFocused: Bool

    private static let tierLookup: [String: Tier] = [
        "S": .s,
        "A": .a,
        "B": .b,
        "C": .c,
        "D": .d,
        "F": .f
    ]

    private func tierForItem(_ item: Item) -> Tier {
        guard let tierId = app.currentTier(of: item.id)?.uppercased() else { return .unranked }
        return Self.tierLookup[tierId] ?? .unranked
    }

    var body: some View {
        Button(
            action: {
                #if os(tvOS)
                if app.isMultiSelect {
                    app.toggleSelection(item.id)
                } else {
                    app.presentItemMenu(item)
                }
                #else
                app.beginQuickRank(item)
                #endif
            },
            label: {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 8) {
                        ThumbnailView(item: item)
                        Text("S \(item.seasonString ?? "?")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(Metrics.grid)
                    .background(Color.cardBackground)
                    .cornerRadius(12)

                    #if !os(tvOS)
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
                            .background(
                                Circle().fill(Color.black.opacity(0.4))
                            )
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
        .punchyFocus(tier: tierForItem(item), cornerRadius: 12)
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
            ForEach(app.tierOrder, id: \.self) { tier in
                Button("Move to \(tier)") {
                    app.move(item.id, to: tier)
                }
            }
            Button("Move to Unranked") {
                app.move(item.id, to: "unranked")
            }
            Button("View Details") { app.detailItem = item }
        }
        #endif
    }
}

private struct ThumbnailView: View {
    let item: Item

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .frame(
                minWidth: 120,
                idealWidth: 140,
                minHeight: 168,
                idealHeight: 196
            )
            .overlay {
                Group {
                    if let asset = item.imageUrl ?? item.videoUrl,
                       let url = URL(string: asset) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                placeholder
                            @unknown default:
                                placeholder
                            }
                        }
                        .frame(
                            minWidth: 120,
                            idealWidth: 140,
                            minHeight: 168,
                            idealHeight: 196
                        )
                        .clipped()
                    } else {
                        placeholder
                    }
                }
            }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Palette.brand)
            .overlay(
                Text((item.name ?? item.id).prefix(12))
                    .font(.headline)
                    .foregroundStyle(.white)
            )
    }
}

private extension Gradient {
    static var tierListBackground: Gradient {
        .init(colors: [Color.black.opacity(0.6), Color.blue.opacity(0.2)])
    }
}

#Preview("iPhone") { ContentView() }
#Preview("iPad") { ContentView() }
#if os(tvOS)
#Preview("tvOS") { ContentView() }
#endif
