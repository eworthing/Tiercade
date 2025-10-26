import SwiftUI
import TiercadeCore
import os

// MARK: - Schema Wizard Page (Item Fields Definition)

struct ItemsWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var searchQuery: String = ""
    @State private var itemFilter: ItemFilter = .all

    // Use parent wizard's state for item selection
    @State private var selectedItemID: UUID?
    @State private var showingItemEditor = false

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
            case .all: return "All"
            case .assigned: return "Assigned"
            case .unassigned: return "Unassigned"
            case .hidden: return "Hidden"
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
        .fullScreenCover(isPresented: $showingItemEditor) {
            if let item = currentItem {
                LargeItemEditorView(appState: appState, draft: draft, item: item)
            }
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
                .overlay(Rectangle().stroke(Palette.stroke, lineWidth: 1))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundStyle(Palette.textDim)
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
                        .stroke(Palette.stroke, lineWidth: 1)
                )
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
        .padding(24)
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
    }

    private var itemCardBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
            .fill(Palette.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                    .stroke(Palette.stroke, lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private var filteredItems: [TierDraftItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        return draft.items.filter { item in
            let matchesSearch: Bool
            if trimmed.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = item.title.localizedCaseInsensitiveContains(trimmed)
                    || item.itemId.localizedCaseInsensitiveContains(trimmed)
                    || item.slug.localizedCaseInsensitiveContains(trimmed)
            }

            let matchesFilter: Bool
            switch itemFilter {
            case .all:
                matchesFilter = true
            case .assigned:
                matchesFilter = item.tier != nil
            case .unassigned:
                matchesFilter = item.tier == nil
            case .hidden:
                matchesFilter = item.hidden
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
        guard let id = selectedItemID else { return nil }
        return draft.items.first { $0.identifier == id }
    }
}

