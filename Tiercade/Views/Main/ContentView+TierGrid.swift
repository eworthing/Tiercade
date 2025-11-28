import SwiftUI
import Foundation
import TiercadeCore
import UniformTypeIdentifiers

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
    // swiftlint:disable:next private_swiftui_state - Accessed from ContentView+TierGrid+HardwareFocus.swift
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
        .onChange(of: app.searchQuery) { ensureHardwareFocusValid() }
        .onChange(of: app.activeFilter) { ensureHardwareFocusValid() }
        .onChange(of: app.cardDensityPreference) { ensureHardwareFocusValid() }
        .onChange(of: app.tierOrder) { ensureHardwareFocusValid() }
        .onChange(of: hardwareFocus) { _, _ in gridHasFocus = true }
        .accessibilityHidden(true)  // Focus management only, not user-actionable
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

// MARK: - Unranked Section

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
                                .onMoveCommand { direction in
                                    handleUnrankedMoveCommand(for: item.id, direction: direction)
                                }
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
                    color: Palette.tierColor("unranked", from: app.tierColors)
                )
            }
            #if !os(tvOS)
            .onDrop(of: [.text], isTargeted: nil, perform: { providers in
                // Load NSItemProvider inside closure per security rules
                guard let provider = providers.first else {
                    app.setDragTarget(nil)
                    return false
                }

                provider.loadItem(
                    forTypeIdentifier: UTType.text.identifier,
                    options: nil
                ) { item, _ in
                    if let data = item as? Data, let id = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            app.move(id, to: "unranked")
                            app.setDragTarget(nil)
                            app.setDragging(nil)
                        }
                    }
                }
                return true
            })
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

    #if os(tvOS)
    /// Handle move command for both single item and block moves in unranked tier
    private func handleUnrankedMoveCommand(for itemId: String, direction: MoveCommandDirection) {
        // Don't reorder if not in custom sort mode - let focus navigate
        guard app.globalSortMode.isCustom else { return }

        // Check if item is selected and we're in multi-select mode with multiple items
        if app.isSelected(itemId) && app.selection.count > 1 {
            handleUnrankedBlockMove(direction: direction)
        } else {
            // Single item move
            switch direction {
            case .left:
                app.moveItemLeft(itemId, in: "unranked")
            case .right:
                app.moveItemRight(itemId, in: "unranked")
            default:
                break
            }
        }
    }

    /// Handle block move for multi-select in unranked tier
    private func handleUnrankedBlockMove(direction: MoveCommandDirection) {
        guard let items = app.tiers["unranked"] else { return }

        // Get indices of all selected items in unranked tier
        let selectedIndices = IndexSet(
            items.enumerated()
                .filter { app.selection.contains($0.element.id) }
                .map { $0.offset }
        )

        guard !selectedIndices.isEmpty else { return }

        // Calculate destination index based on direction
        let minIndex = selectedIndices.min() ?? 0
        let maxIndex = selectedIndices.max() ?? (items.count - 1)

        let destination: Int
        switch direction {
        case .left:
            // Move block one position to the left
            destination = max(0, minIndex - 1)
        case .right:
            // Move block one position to the right
            destination = min(items.count, maxIndex + 2)
        default:
            return
        }

        app.reorderBlock(in: "unranked", from: selectedIndices, to: destination)
    }
    #endif
}

// MARK: - Gradient Extension

private extension Gradient {
    static var tierListBackground: Gradient {
        .init(colors: [Palette.bg.opacity(0.6), Palette.brand.opacity(0.2)])
    }
}

// MARK: - Tier Grid Previews

@MainActor
private struct ContentViewTierGridPreview: View {
    private let appState = AppState(inMemory: true)

    var body: some View {
        ContentView()
            .environment(appState)
    }
}

#Preview("iPhone") {
    ContentViewTierGridPreview()
}

#Preview("iPad") {
    ContentViewTierGridPreview()
}

#if os(tvOS)
#Preview("tvOS") {
    ContentViewTierGridPreview()
}
#endif
