import os
import SwiftUI
import TiercadeCore

// MARK: - Schema Wizard Page (Item Fields Definition)

struct ItemsWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var searchQuery: String = ""
    @State private var itemFilter: ItemFilter = .all

    // Use parent wizard's state for item selection
    @State private var selectedItemID: UUID?
    @State private var showingItemEditor = false
    @State private var showAIGenerator = false

    let pageTitle = "Items"
    let pageDescription = "Add and configure items for your tier list"

    #if os(tvOS)
    @Namespace private var defaultFocusNamespace
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case search }
    #endif

    private enum ItemFilter: String, CaseIterable, Identifiable {
        case all
        case assigned
        case unassigned
        case hidden

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "All"
            case .assigned: "Assigned"
            case .unassigned: "Unassigned"
            case .hidden: "Hidden"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchControls

            ScrollView {
                LazyVStack(spacing: Metrics.grid * 2) {
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredItems) { item in
                            itemCard(item)
                        }
                    }
                }
                .padding(.horizontal, Metrics.grid * 6)
                .padding(.vertical, Metrics.grid * 5)
            }

            addItemBar
        }
        .background(Palette.bg)
        #if os(tvOS)
            // Ensure default focus is evaluated within a defined scope
                .focusScope(defaultFocusNamespace)
        #endif
        #if os(macOS)
        .sheet(isPresented: $showingItemEditor) {
            if let item = currentItem {
                LargeItemEditorView(appState: appState, draft: draft, item: item)
            }
        }
        #else
        .fullScreenCover(isPresented: $showingItemEditor) {
                if let item = currentItem {
                    LargeItemEditorView(appState: appState, draft: draft, item: item)
                }
            }
        #endif
            .sheet(isPresented: $showAIGenerator) {
                    #if os(macOS) || os(iOS)
                    AIItemGeneratorOverlay(appState: appState, draft: draft)
                    #else
                    // tvOS: Show informative message
                    VStack(spacing: Metrics.grid * 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(TypeScale.wizardIcon)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)

                        Text("AI Generation Requires macOS or iOS")
                            .font(.title2)
                            .multilineTextAlignment(.center)

                        Text("Please use the companion iOS or macOS app to generate items with AI.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Metrics.grid * 8)

                        Button("OK") {
                            showAIGenerator = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(Metrics.grid * 8)
                    #endif
                }
        #if os(tvOS)
                .onAppear { focusedField = .search }
        #endif
    }

    private var searchControls: some View {
        VStack(spacing: Metrics.grid * 2) {
            TextField("Search items", text: $searchQuery)
                .font(.title3)
            #if os(tvOS)
                .wizardFieldDecoration()
                .focused($focusedField, equals: .search)
                .prefersDefaultFocus(true, in: defaultFocusNamespace)
            #else
                .textFieldStyle(.roundedBorder)
            #endif
                .accessibilityIdentifier("Items_SearchField")

            Picker("Filter", selection: $itemFilter) {
                ForEach(ItemFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("Items_FilterPicker")
        }
        .padding(.horizontal, Metrics.grid * 6)
        .padding(.top, Metrics.grid * 5)
        .padding(.bottom, Metrics.grid * 3)
    }

    private var addItemBar: some View {
        HStack {
            // AI Generation button
            Button {
                showAIGenerator = true
            } label: {
                Label("Generate with AI", systemImage: "sparkles.rectangle.stack")
            }
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.bordered)
            #endif
            .accessibilityIdentifier("ItemsPage_GenerateAI")

            Spacer()

            Button {
                let newItem = appState.addItem(to: draft)
                selectedItemID = newItem.identifier
                showingItemEditor = true
            } label: {
                Label("Add New Item", systemImage: "plus.circle.fill")
            }
            #if os(tvOS)
            .buttonStyle(.glassProminent)
            #else
            .buttonStyle(.borderedProminent)
            #endif
            .accessibilityIdentifier("Items_AddItem")
        }
        .padding(.horizontal, Metrics.grid * 6)
        .padding(.vertical, Metrics.grid * 3)
        .background(
            Rectangle()
                .fill(Palette.cardBackground.opacity(0.9))
                .overlay(Rectangle().stroke(Palette.stroke, lineWidth: 1)),
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3")
                .font(TypeScale.emptyStateIcon)
                .foregroundStyle(Palette.textDim)
                .accessibilityHidden(true)
            Text("No items found")
                .font(.title3)
            Text(searchQuery.isEmpty ? "Add items to populate your tier list" : "No items match your search")
                .font(.body)
                .foregroundStyle(Palette.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1),
                ),
        )
    }

    private func itemCard(_ item: TierDraftItem) -> some View {
        Button {
            selectedItemID = item.identifier
            showingItemEditor = true
        } label: {
            itemCardContent(item)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Items_Card_\(item.itemId)")
    }

    @ViewBuilder
    private func itemCardContent(_ item: TierDraftItem) -> some View {
        HStack(spacing: 20) {
            itemCardDetails(item)
            Spacer()
            itemCardChevron
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(itemCardBackground)
    }

    @ViewBuilder
    private func itemCardDetails(_ item: TierDraftItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }

            itemCardMetadata(item)
        }
    }

    @ViewBuilder
    private func itemCardMetadata(_ item: TierDraftItem) -> some View {
        HStack(spacing: 12) {
            if let tier = item.tier {
                Label(tier.label, systemImage: "tag")
                    .font(.caption)
                    .foregroundStyle(Palette.brand)
            } else {
                Label("Unassigned", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
            }

            if item.hidden {
                Label("Hidden", systemImage: "eye.slash")
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
            }
        }
    }

    private var itemCardChevron: some View {
        Image(systemName: "chevron.right")
            .foregroundStyle(Palette.textDim)
            .font(.title3)
            .accessibilityHidden(true)
    }

    private var itemCardBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
            .fill(Palette.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1),
            )
    }

    // MARK: - Helpers

    private var filteredItems: [TierDraftItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        return draft.items.filter { item in
            let matchesSearch: Bool = if trimmed.isEmpty {
                true
            } else {
                item.title.localizedCaseInsensitiveContains(trimmed)
                    || item.itemId.localizedCaseInsensitiveContains(trimmed)
                    || item.slug.localizedCaseInsensitiveContains(trimmed)
            }

            let matchesFilter: Bool = switch itemFilter {
            case .all:
                true
            case .assigned:
                item.tier != nil
            case .unassigned:
                item.tier == nil
            case .hidden:
                item.hidden
            }

            return matchesSearch && matchesFilter
        }
        .sorted { left, right in
            if left.title == right.title {
                return left.itemId < right.itemId
            }
            return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
        }
    }

    private var currentItem: TierDraftItem? {
        guard let id = selectedItemID else {
            return nil
        }
        return draft.items.first { $0.identifier == id }
    }
}
