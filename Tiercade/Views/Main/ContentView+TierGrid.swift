import SwiftUI
import Foundation
import TiercadeCore

// MARK: - Tier grid
internal struct TierGridView: View {
    @Environment(AppState.self) var app: AppState
    internal let tierOrder: [String]
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif
    #if !os(tvOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @FocusState var hardwareFocus: CardFocus?
    @State var lastHardwareFocus: CardFocus?
    @FocusState var gridHasFocus: Bool
    #endif

    internal var body: some View {
        #if !os(tvOS)
        ZStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(tierOrder, id: \.self) { tier in
                        TierRowWrapper(tier: tier, hardwareFocus: $hardwareFocus)
                    }
                    UnrankedView(hardwareFocus: $hardwareFocus)
                }
                .padding(Metrics.grid * 2)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Palette.appBackground.ignoresSafeArea(edges: .bottom))
        }
        .focusable()
        .focused($gridHasFocus)
        .onAppear {
            gridHasFocus = true
            seedHardwareFocus()
        }
        .onKeyPress(.upArrow) { handleDirectionalInput(.up); return .handled }
        .onKeyPress(.downArrow) { handleDirectionalInput(.down); return .handled }
        .onKeyPress(.leftArrow) { handleDirectionalInput(.left); return .handled }
        .onKeyPress(.rightArrow) { handleDirectionalInput(.right); return .handled }
        .onChange(of: app.searchQuery) { _ in ensureHardwareFocusValid() }
        .onChange(of: app.activeFilter) { _ in ensureHardwareFocusValid() }
        .onChange(of: app.cardDensityPreference) { _ in ensureHardwareFocusValid() }
        .onChange(of: app.tierOrder) { _ in ensureHardwareFocusValid() }
        .onChange(of: hardwareFocus) { _, _ in gridHasFocus = true }
        .onTapGesture { gridHasFocus = true }
        #else
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tierOrder, id: \.self) { tier in
                    TierRowWrapper(tier: tier)
                }
                UnrankedView()
            }
            .padding(.horizontal, TVMetrics.contentHorizontalPadding)
            .padding(.vertical, Metrics.grid)
        }
        .background(Palette.appBackground.ignoresSafeArea())
        #endif
    }
}

internal struct UnrankedView: View {
    @Environment(AppState.self) private var app: AppState
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    #else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    internal let hardwareFocus: FocusState<CardFocus?>.Binding
    #endif

    private var filteredItems: [Item] {
        app.filteredItems(for: "unranked")
    }

    internal var body: some View {
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
                let layout = PlatformCardLayoutProvider.layout(
                    for: filteredItems.count,
                    preference: app.cardDensityPreference,
                    horizontalSizeClass: horizontalSizeClass
                )

                LazyVGrid(
                    columns: layout.gridColumns,
                    alignment: .leading,
                    spacing: layout.rowSpacing
                ) {
                    ForEach(filteredItems, id: \.id) { item in
                        let focusID = CardFocus(tier: "unranked", itemID: item.id)
                        CardView(item: item, layout: layout, onTapFocus: {
                            // Update hardware focus when card is clicked
                            hardwareFocus.wrappedValue = focusID
                        })
                        .draggable(item.id)
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
                .animation(reduceMotion ? nil : Motion.emphasis, value: filteredItems.count)
                #endif
            }
            .padding(Metrics.grid * 1.5)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Palette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Palette.stroke, lineWidth: 1)
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
                .foregroundColor(Palette.cardText)
            Spacer()
            if !app.searchQuery.isEmpty || app.activeFilter != .all {
                Text("\(filteredItems.count)/\(app.unrankedCount())")
                    .font(TypeScale.label)
                    .foregroundColor(Palette.cardText)
            } else {
                Text("\(filteredItems.count)")
                    .font(TypeScale.label)
                    .foregroundColor(Palette.cardText)
            }
        }
    }
}

internal struct CardView: View {
    internal let item: Item
    @Environment(AppState.self) var app
    @Environment(\.isFocused) var isFocused: Bool
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif
    #if os(tvOS)
    internal let layout: TVCardLayout
    #else
    internal let layout: PlatformCardLayout
    internal var onTapFocus: (() -> Void)?  // Called when card is tapped to update focus
    #endif

    private var isMultiSelectActive: Bool {
        #if os(iOS)
        return editMode?.wrappedValue == .active
        #else
        return false
        #endif
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

    private var layoutCornerRadius: CGFloat {
        #if os(tvOS)
        layout.cornerRadius
        #else
        layout.cornerRadius
        #endif
    }

    internal var body: some View {
        Button(action: handleTap) {
            cardBody
        }
        .buttonStyle(.plain)
        #if !os(tvOS)
        .focusable()  // Enable keyboard event handling (Space/Return) on Catalyst/iOS
        .onKeyPress(.space) {
            onTapFocus?()  // Update focus state
            if !isMultiSelectActive {
                app.beginQuickRank(item)
            }
            return .handled
        }
        .onKeyPress(.return) {
            onTapFocus?()  // Update focus state
            if !isMultiSelectActive {
                app.beginQuickRank(item)
            }
            return .handled
        }
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
        .punchyFocus(tier: tierForItem(item), cornerRadius: layoutCornerRadius)
        #if os(iOS) || os(macOS)
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

    private func handleTap() {
        #if os(tvOS)
        if isMultiSelectActive {
            app.toggleSelection(item.id)
        } else {
            app.beginQuickMove(item)
        }
        #else
        // On Catalyst, clicking a card updates focus for keyboard navigation
        // The actual QuickRank action is triggered by Space/Return on the grid
        if isMultiSelectActive {
            app.toggleSelection(item.id)
        } else {
            onTapFocus?()  // Update hardware focus to this card
            app.beginQuickRank(item)
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
        pointerCardBody
        #endif
    }

    #if os(tvOS)
    private var tvOSCardBody: some View {
        VStack(alignment: .leading, spacing: layout.verticalContentSpacing) {
            ThumbnailView(item: item, layout: layout)
            if layout.density.showsOnCardText {
                cardTextBlock(font: layout.titleFont, metadataFont: layout.metadataFont)
            }
        }
        .padding(layout.contentPadding)
        .frame(width: layout.cardWidth, alignment: .leading)
        .background(Palette.cardBackground)
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
    #else
    private var pointerCardBody: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: layout.verticalContentSpacing) {
                ThumbnailView(item: item, layout: layout)
                if layout.showsText {
                    cardTextBlock(font: layout.titleFont, metadataFont: layout.metadataFont)
                }
            }
            .padding(layout.contentPadding)
            .frame(width: layout.cardWidth, alignment: .leading)
            .background(Palette.cardBackground)
            .cornerRadius(layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .stroke(Palette.stroke.opacity(0.9), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isMultiSelectActive && app.isSelected(item.id) {
                    selectionBadge
                        .padding(6)
                }
            }

            TierBadgeView(tier: tierForItem(item))
                .padding(layout.contentPadding * 0.6)
        }
    }
    #endif

    private func cardTextBlock(font titleFont: Font, metadataFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayLabel)
                .font(titleFont)
                .foregroundColor(Palette.cardText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.82)
            if let metadata = metadataText {
                Text(metadata)
                    .font(metadataFont)
                    .foregroundStyle(Palette.cardTextDim)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataText: String? {
        #if os(tvOS)
        guard layout.density.showsOnCardText else { return nil }
        #else
        guard layout.showsText else { return nil }
        #endif

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
            #if os(tvOS)
            .offset(x: layout.contentPadding * 0.2, y: -layout.contentPadding * 0.2)
        #endif
    }
}

private struct ThumbnailView: View {
    internal let item: Item
    #if os(tvOS)
    internal let layout: TVCardLayout
    #else
    internal let layout: PlatformCardLayout
    #endif

    internal var body: some View {
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
        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous)
            .fill(Color.clear)
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
            .overlay {
                thumbnailContent
                    .clipShape(
                        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous)
                    )
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
            .frame(width: layout.thumbnailSize.width, height: layout.thumbnailSize.height)
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
        RoundedRectangle(cornerRadius: layout.thumbnailCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.brand, Palette.brand.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String((item.name ?? item.id).prefix(18)))
                    .font(layout.titleFont)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
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
