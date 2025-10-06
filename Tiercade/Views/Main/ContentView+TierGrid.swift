import SwiftUI
import Foundation
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
                    let layout = TVMetrics.cardLayout(
                        for: filteredItems.count,
                        preference: app.cardDensityPreference
                    )
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: layout.interItemSpacing) {
                            ForEach(filteredItems, id: \.id) { item in
                                CardView(item: item, layout: layout)
                                    .focused($focusedItemId, equals: item.id)
                            }
                        }
                        .padding(.horizontal, layout.contentPadding)
                        .padding(.bottom, layout.interItemSpacing * 0.5)
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
    @Environment(\.editMode) private var editMode
    #if os(tvOS)
    let layout: TVCardLayout
    #endif

    private var isMultiSelectActive: Bool {
        editMode?.wrappedValue == .active
    }

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
                if isMultiSelectActive {
                    app.toggleSelection(item.id)
                } else {
                    app.beginQuickMove(item)
                }
                #else
                app.beginQuickRank(item)
                #endif
            },
            label: {
                cardBody
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
        .accessibilityLabel(displayLabel)
        .punchyFocus(
            tier: tierForItem(item),
            cornerRadius: {
                #if os(tvOS)
                layout.cornerRadius
                #else
                12
                #endif
            }()
        )
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
            if isMultiSelectActive {
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

    private var displayLabel: String {
        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return item.id
    }

    @ViewBuilder
    private var cardBody: some View {
        #if os(tvOS)
        tvOSCardBody
        #else
        defaultCardBody
        #endif
    }

    #if os(tvOS)
    private var tvOSCardBody: some View {
        let showsOnCardText = layout.density.showsOnCardText

        return VStack(alignment: .leading, spacing: layout.verticalContentSpacing) {
            ThumbnailView(item: item, layout: layout)
            if showsOnCardText {
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayLabel)
                        .font(layout.titleFont)
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.82)
                    if let metadata = metadataText {
                        Text(metadata)
                            .font(layout.metadataFont)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(layout.contentPadding)
        .frame(width: layout.cardWidth, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: layout.cornerRadius)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isMultiSelectActive && app.isSelected(item.id) {
                selectionBadge
            }
        }
    }

    private var metadataText: String? {
        guard layout.density.showsOnCardText else { return nil }
        if let status = item.status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return status
        }
        if let season = item.seasonString?.trimmingCharacters(in: .whitespacesAndNewlines), !season.isEmpty {
            return "Season \(season)"
        }
        return nil
    }

    private var selectionBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accentColor)
            .padding(.all, 6)
            .background(
                Circle().fill(Color.black.opacity(0.4))
            )
            .offset(x: layout.contentPadding * 0.2, y: -layout.contentPadding * 0.2)
    }
    #else
    private var defaultCardBody: some View {
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

            TierBadgeView(tier: tierForItem(item))
                .padding(10)
        }
    }
    #endif
}

private struct ThumbnailView: View {
    let item: Item
    #if os(tvOS)
    let layout: TVCardLayout
    #endif

    var body: some View {
        #if os(tvOS)
        RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
            .fill(Color.clear)
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            .overlay {
                thumbnailContent
                    .clipShape(
                        RoundedRectangle(cornerRadius: max(layout.cornerRadius - 4, 8), style: .continuous)
                    )
            }
        #else
        RoundedRectangle(cornerRadius: 8)
            .frame(
                minWidth: 120,
                idealWidth: 140,
                minHeight: 168,
                idealHeight: 196
            )
            .overlay {
                thumbnailContent
            }
        #endif
    }

    @ViewBuilder
    private var thumbnailContent: some View {
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
            #if os(tvOS)
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            #else
            .frame(
                minWidth: 120,
                idealWidth: 140,
                minHeight: 168,
                idealHeight: 196
            )
            #endif
            .clipped()
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        #if os(tvOS)
        if layout.density == .ultraMicro {
            RoundedRectangle(cornerRadius: max(layout.cornerRadius - 4, 6), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.brand, Palette.brand.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "wand.and.stars")
                        .font(
                            .system(
                                size: min(layout.thumbnailSize.width, layout.thumbnailSize.height) * 0.32,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(Color.white.opacity(0.78))
                )
        } else {
            RoundedRectangle(cornerRadius: max(layout.cornerRadius - 4, 8), style: .continuous)
                .fill(Palette.brand)
                .overlay(
                    Text(String((item.name ?? item.id).prefix(18)))
                        .font(layout.titleFont)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                )
        }
        #else
        RoundedRectangle(cornerRadius: 8)
            .fill(Palette.brand)
            .overlay(
                Text((item.name ?? item.id).prefix(12))
                    .font(.headline)
                    .foregroundStyle(.white)
            )
        #endif
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
