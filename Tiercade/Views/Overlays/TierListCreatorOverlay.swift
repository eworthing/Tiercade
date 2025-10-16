import SwiftUI
import TiercadeCore

struct TierListCreatorOverlay: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft

    @FocusState private var focusArea: FocusArea?
    @State private var selectedTierID: UUID?
    @State private var selectedItemID: UUID?
    @State private var searchQuery: String = ""
    @State private var itemFilter: ItemFilter = .all
    @State private var showingExportSheet = false
    @State private var exportPayload: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Sheet presentation states
    @State private var showingTierDetailsSheet = false
    @State private var showingItemDetailsSheet = false
    @State private var showingProjectSettingsSheet = false
    @State private var showingMoreMenu = false

    private enum FocusArea: Hashable {
        case sidebar    // Tiers + item library
        case actions    // Bottom action strip
    }

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
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 32) {
                headerToolbar
                contentColumns
                actionStrip
            }
            #if os(tvOS)
            .padding(.horizontal, TVMetrics.overlayPadding)
            .padding(.vertical, 48)
            #else
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            #endif
        }
        .onAppear {
            focusArea = .sidebar
            if selectedTierID == nil {
                selectedTierID = orderedTiers.first?.identifier
            }
            if selectedItemID == nil {
                selectedItemID = filteredItems.first?.identifier
            }
        }
        .onChange(of: draft.tiers) { _ in
            guard let id = selectedTierID else {
                selectedTierID = orderedTiers.first?.identifier
                return
            }
            if orderedTiers.contains(where: { $0.identifier == id }) == false {
                selectedTierID = orderedTiers.first?.identifier
            }
        }
        .onChange(of: draft.items) { _ in
            guard let id = selectedItemID else { return }
            if draft.items.contains(where: { $0.identifier == id }) == false {
                selectedItemID = filteredItems.first?.identifier
            }
        }
        #if os(tvOS)
        .onExitCommand { appState.cancelTierListCreator() }
        #endif
        .confirmationDialog("More Options", isPresented: $showingMoreMenu, titleVisibility: .hidden) {
            Button("Project Settings") {
                showingProjectSettingsSheet = true
            }
            Button("Export") {
                if let payload = appState.exportTierListDraftPayload() {
                    exportPayload = payload
                    showingExportSheet = true
                }
            }
            Button("Validate") {
                let issues = appState.validateTierListDraft()
                if issues.isEmpty {
                    appState.showToast(
                        type: .success,
                        title: "Validation Passed",
                        message: "Draft is ready to save."
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
        .sheet(isPresented: $showingItemDetailsSheet) {
            if let item = currentItem {
                ItemDetailsSheet(appState: appState, draft: draft, item: item, currentTier: currentTier)
            }
        }
        .sheet(isPresented: $showingProjectSettingsSheet) {
            ProjectSettingsSheet(appState: appState, draft: draft)
        }
        .sheet(isPresented: $showingExportSheet) {
            NavigationView {
                ScrollView {
                    Text(exportPayload)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Draft Export")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") { showingExportSheet = false }
                    }
                }
            }
            #if os(tvOS)
            .navigationViewStyle(.stack)
            #endif
        }
    }

    // MARK: Header

    private var headerToolbar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tier List Creator")
                    .font(.title.weight(.semibold))
                Text(displayedSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                showingMoreMenu = true
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .modifier(GlassButtonStyle(isProminent: false))
            .accessibilityIdentifier("TierCreator_More")

            Button {
                Task { await appState.saveTierListDraft(action: .save) }
            } label: {
                Label("Save", systemImage: "checkmark.circle")
            }
            .modifier(GlassButtonStyle(isProminent: false))
            .accessibilityIdentifier("TierCreator_Save")

            Button {
                appState.cancelTierListCreator()
            } label: {
                Label("Close", systemImage: "xmark.circle")
            }
            .modifier(GlassButtonStyle(isProminent: false))
            .accessibilityIdentifier("TierCreator_Close")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .creatorGlass()
    }

    private var displayedSubtitle: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "Draft • \(draft.projectId.uuidString.prefix(8))" }
        return "Draft • \(title)"
    }

    // MARK: Columns

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: 28) {
            tierRail
            itemLibrary
        }
    }

    private var tierRail: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tiers")
                    .font(.headline)
                Spacer()
                Button {
                    let newTier = appState.addTier(to: draft)
                    selectedTierID = newTier.identifier
                } label: {
                    Label("Add Tier", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .modifier(GlassButtonStyle(isProminent: false))
                .accessibilityIdentifier("TierCreator_AddTier")
            }

            Divider()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(orderedTiers) { tier in
                        tierRow(tier)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: .infinity)

            if let tier = currentTier {
                HStack(spacing: 12) {
                    Button { appState.moveTier(tier, direction: -1, in: draft) } label: {
                        Image(systemName: "arrow.up")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))
                    .accessibilityIdentifier("TierCreator_MoveTierUp")

                    Button { appState.moveTier(tier, direction: 1, in: draft) } label: {
                        Image(systemName: "arrow.down")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))
                    .accessibilityIdentifier("TierCreator_MoveTierDown")

                    Button(role: .destructive) {
                        appState.delete(tier, from: draft)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))
                    .accessibilityIdentifier("TierCreator_DeleteTier")
                }
            }
        }
        .padding(28)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .sidebar)
    }

    private func tierRow(_ tier: TierDraftTier) -> some View {
        let isSelected = tier.identifier == selectedTierID
        return Button {
            selectedTierID = tier.identifier
            showingTierDetailsSheet = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(ColorUtilities.color(hex: tier.colorHex))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.label)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Items: \(appState.orderedItems(for: tier).count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if tier.locked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var itemLibrary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Item Library")
                    .font(.headline)
                Spacer()
                Button {
                    let newItem = appState.addItem(to: draft)
                    selectedItemID = newItem.identifier
                    focusArea = .sidebar
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .modifier(GlassButtonStyle(isProminent: false))
                .accessibilityIdentifier("TierCreator_AddItem")
            }

            TextField("Search items", text: $searchQuery)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

            Picker("Filter", selection: $itemFilter) {
                ForEach(ItemFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        itemRow(item)
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: .infinity)

            Text("Tap any item to edit details")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .sidebar)
    }

    private func itemRow(_ item: TierDraftItem) -> some View {
        let isSelected = item.identifier == selectedItemID
        return Button {
            selectedItemID = item.identifier
            showingItemDetailsSheet = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .truncationMode(.tail)
                    Text(item.tier?.label ?? "Unassigned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if item.hidden {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var actionStrip: some View {
        HStack {
            Spacer()

            Button {
                Task { await appState.saveTierListDraft(action: .publish) }
            } label: {
                Label("Publish", systemImage: "paperplane.fill")
            }
            .modifier(GlassButtonStyle(isProminent: true))
            .accessibilityIdentifier("TierCreator_Publish")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .actions)
    }

    // MARK: Helpers

    private var orderedTiers: [TierDraftTier] {
        appState.orderedTiers(for: draft)
    }

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

    private var currentTier: TierDraftTier? {
        guard let id = selectedTierID else { return nil }
        return draft.tiers.first { $0.identifier == id }
    }

    private var currentItem: TierDraftItem? {
        guard let id = selectedItemID else { return nil }
        return draft.items.first { $0.identifier == id }
    }
}

// MARK: Styling Helpers

private struct GlassButtonStyle: ViewModifier {
    let isProminent: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
        if isProminent {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
        #else
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isProminent ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.08))
            )
        #endif
    }
}

private extension View {
    @ViewBuilder
    func creatorGlass() -> some View {
        #if os(tvOS)
        self.glassEffect()
        #else
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        #endif
    }
}
