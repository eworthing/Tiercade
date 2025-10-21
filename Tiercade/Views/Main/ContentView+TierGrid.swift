import SwiftUI
import Foundation
import TiercadeCore

// MARK: - Tier grid
struct TierGridView: View {
    @Environment(AppState.self) private var app: AppState
    let tierOrder: [String]
    @Environment(\.editMode) private var editMode
#if !os(tvOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var hardwareFocus: CardFocus?
    @State private var lastHardwareFocus: CardFocus?
    @FocusState private var gridHasFocus: Bool
#endif

    var body: some View {
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
            .background(Palette.appBackground.ignoresSafeArea())
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

struct UnrankedView: View {
    @Environment(AppState.self) private var app: AppState
    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    #else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let hardwareFocus: FocusState<CardFocus?>.Binding
    #endif

    private var filteredItems: [Item] {
        app.filteredItems(for: "unranked")
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

struct CardView: View {
    let item: Item
    @Environment(AppState.self) var app
    @Environment(\.isFocused) var isFocused: Bool
    @Environment(\.editMode) private var editMode
    #if os(tvOS)
    let layout: TVCardLayout
    #else
    let layout: PlatformCardLayout
    var onTapFocus: (() -> Void)?  // Called when card is tapped to update focus
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

    private var layoutCornerRadius: CGFloat {
        #if os(tvOS)
        layout.cornerRadius
        #else
        layout.cornerRadius
        #endif
    }

    var body: some View {
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
        #if os(iOS) && !os(tvOS) || targetEnvironment(macCatalyst)
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

#if !os(tvOS)
private extension TierGridView {
    struct TierSnapshot {
        let tier: String
        let items: [Item]
        let layout: PlatformCardLayout
    }

    var navigationTierSequence: [String] {
        var sequence = tierOrder
        sequence.append("unranked")
        return sequence
    }

    func seedHardwareFocus() {
        let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }
        if let existing = hardwareFocus,
           snapshot.contains(where: {
               $0.tier == existing.tier && $0.items.contains(where: { $0.id == existing.itemID })
           }) {
            lastHardwareFocus = existing
            return
        }
        if let fallback = defaultHardwareFocus(for: snapshot) {
            hardwareFocus = fallback
            lastHardwareFocus = fallback
        }
    }

    func ensureHardwareFocusValid() {
        let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }
        if let focus = hardwareFocus,
           snapshot.contains(where: { $0.tier == focus.tier && $0.items.contains(where: { $0.id == focus.itemID }) }) {
            lastHardwareFocus = focus
            return
        }
        if let fallback = defaultHardwareFocus(for: snapshot) {
            hardwareFocus = fallback
            lastHardwareFocus = fallback
        }
    }

    func handleDirectionalInput(_ move: DirectionalMove) {
        gridHasFocus = true
        let snapshot = currentSnapshot()
        guard !snapshot.isEmpty else {
            hardwareFocus = nil
            lastHardwareFocus = nil
            return
        }

        let activeFocus = hardwareFocus ?? defaultHardwareFocus(for: snapshot)
        guard let focus = activeFocus else { return }

        guard let next = focusAfter(focus, move: move, snapshot: snapshot) else { return }
        hardwareFocus = next
        lastHardwareFocus = next
    }

    func currentSnapshot() -> [TierSnapshot] {
        navigationTierSequence.compactMap { tier in
            let items = app.filteredItems(for: tier)
            guard !items.isEmpty else { return nil }
            let layout = PlatformCardLayoutProvider.layout(
                for: items.count,
                preference: app.cardDensityPreference,
                horizontalSizeClass: horizontalSizeClass
            )
            return TierSnapshot(tier: tier, items: items, layout: layout)
        }
    }

    func defaultHardwareFocus(for snapshot: [TierSnapshot]) -> CardFocus? {
        if let cached = lastHardwareFocus,
           snapshot.contains(where: {
               $0.tier == cached.tier && $0.items.contains(where: { $0.id == cached.itemID })
           }) {
            return cached
        }
        guard let firstTier = snapshot.first, let firstItem = firstTier.items.first else { return nil }
        return CardFocus(tier: firstTier.tier, itemID: firstItem.id)
    }

    func focusAfter(
        _ current: CardFocus,
        move: DirectionalMove,
        snapshot: [TierSnapshot]
    ) -> CardFocus? {
        guard let tierIndex = snapshot.firstIndex(where: { $0.tier == current.tier }) else {
            return defaultHardwareFocus(for: snapshot)
        }
        let tierData = snapshot[tierIndex]
        guard let currentIndex = tierData.items.firstIndex(where: { $0.id == current.itemID }) else {
            return defaultHardwareFocus(for: snapshot)
        }

        switch move {
        case .left:
            return focusLeft(
                from: currentIndex,
                tier: current.tier,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .right:
            return focusRight(
                from: currentIndex,
                tier: current.tier,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .up:
            return focusUp(
                from: currentIndex,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        case .down:
            return focusDown(
                from: currentIndex,
                tierIndex: tierIndex,
                tierData: tierData,
                snapshot: snapshot
            )
        @unknown default:
            return current
        }
    }

    private func focusLeft(
        from currentIndex: Int,
        tier: String,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        if currentIndex > 0 {
            return CardFocus(tier: tier, itemID: tierData.items[currentIndex - 1].id)
        } else if tierIndex > 0 {
            let previous = snapshot[tierIndex - 1]
            guard let target = previous.items.last else {
                return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
            }
            return CardFocus(tier: previous.tier, itemID: target.id)
        }
        return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusRight(
        from currentIndex: Int,
        tier: String,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        if currentIndex + 1 < tierData.items.count {
            return CardFocus(tier: tier, itemID: tierData.items[currentIndex + 1].id)
        } else if tierIndex + 1 < snapshot.count {
            let next = snapshot[tierIndex + 1]
            guard let target = next.items.first else {
                return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
            }
            return CardFocus(tier: next.tier, itemID: target.id)
        }
        return CardFocus(tier: tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusUp(
        from currentIndex: Int,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        let columns = max(1, tierData.layout.gridColumns.count)
        let targetIndex = currentIndex - columns

        if targetIndex >= 0 {
            return CardFocus(tier: tierData.tier, itemID: tierData.items[targetIndex].id)
        } else if tierIndex > 0 {
            let previous = snapshot[tierIndex - 1]
            let prevColumns = max(1, previous.layout.gridColumns.count)
            let targetColumn = min(currentIndex % columns, prevColumns - 1)
            let lastRowStart = max(previous.items.count - prevColumns, 0)
            let index = min(previous.items.count - 1, lastRowStart + targetColumn)
            return CardFocus(tier: previous.tier, itemID: previous.items[index].id)
        }
        return CardFocus(tier: tierData.tier, itemID: tierData.items[currentIndex].id)
    }

    private func focusDown(
        from currentIndex: Int,
        tierIndex: Int,
        tierData: TierSnapshot,
        snapshot: [TierSnapshot]
    ) -> CardFocus {
        let columns = max(1, tierData.layout.gridColumns.count)
        let targetIndex = currentIndex + columns

        if targetIndex < tierData.items.count {
            return CardFocus(tier: tierData.tier, itemID: tierData.items[targetIndex].id)
        } else if tierIndex + 1 < snapshot.count {
            let next = snapshot[tierIndex + 1]
            let nextColumns = max(1, next.layout.gridColumns.count)
            let targetColumn = min(currentIndex % columns, nextColumns - 1)
            let index = min(next.items.count - 1, targetColumn)
            return CardFocus(tier: next.tier, itemID: next.items[index].id)
        }
        return CardFocus(tier: tierData.tier, itemID: tierData.items[currentIndex].id)
    }

    func item(for focus: CardFocus, in snapshot: [TierSnapshot]) -> Item? {
        guard let tierData = snapshot.first(where: { $0.tier == focus.tier }) else { return nil }
        return tierData.items.first(where: { $0.id == focus.itemID })
    }
}
#endif

private struct ThumbnailView: View {
    let item: Item
    #if os(tvOS)
    let layout: TVCardLayout
    #else
    let layout: PlatformCardLayout
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
