import SwiftUI
import TiercadeCore

struct TierListCreatorView: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var selectedTierID: UUID?
    @State private var selectedItemID: UUID?
    @State private var searchQuery: String = ""
    @State private var itemFilter: ItemFilter = .all

    // Sheet presentations
    @State private var showingTierDetailsSheet = false
    @State private var showingItemDetailsSheet = false
    @State private var showingExportSheet = false
    @State private var exportPayload: String = ""

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
            // Header with title and action buttons
            headerBar

            // Main tab content
            TabView(selection: $selectedTab) {
                settingsTab
                    .tag(0)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }

                itemsTab
                    .tag(1)
                    .tabItem {
                        Label("Items", systemImage: "square.grid.3x3")
                    }

                tiersTab
                    .tag(2)
                    .tabItem {
                        Label("Tiers", systemImage: "list.bullet.rectangle")
                    }
            }
        }
        .background(Palette.bg)
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
        .sheet(isPresented: $showingItemDetailsSheet) {
            if let item = currentItem {
                ItemDetailsSheet(appState: appState, draft: draft, item: item, currentTier: nil)
            }
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

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tier List Creator")
                    .font(.title.weight(.semibold))
                Text(displayedSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await appState.saveTierListDraft(action: .save) }
            } label: {
                Label("Save", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)

            Button {
                Task { await appState.saveTierListDraft(action: .publish) }
            } label: {
                Label("Publish", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                dismiss()
            } label: {
                Label("Close", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }

    private var displayedSubtitle: String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "Draft • \(draft.projectId.uuidString.prefix(8))" }
        return "Draft • \(title)"
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        Form {
            Section("Project Information") {
                TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                    .onChange(of: draft.title) { appState.markDraftEdited(draft) }

                TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: draft.summary) { appState.markDraftEdited(draft) }
            }

            Section("Display Options") {
                #if !os(tvOS)
                Stepper(value: $draft.schemaVersion, in: 1...9) {
                    Text("Schema Version: \(draft.schemaVersion)")
                }
                .onChange(of: draft.schemaVersion) { appState.markDraftEdited(draft) }
                #else
                HStack {
                    Text("Schema Version")
                    Spacer()
                    Text("\(draft.schemaVersion)")
                        .foregroundStyle(.secondary)
                }
                #endif

                Toggle("Show Unranked Tier", isOn: $draft.showUnranked)
                    .onChange(of: draft.showUnranked) { appState.markDraftEdited(draft) }

                Toggle("Enable Grid Snap", isOn: $draft.gridSnap)
                    .onChange(of: draft.gridSnap) { appState.markDraftEdited(draft) }
            }

            Section("Accessibility") {
                Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                    .onChange(of: draft.accessibilityVoiceOver) { appState.markDraftEdited(draft) }

                Toggle("High Contrast Mode", isOn: $draft.accessibilityHighContrast)
                    .onChange(of: draft.accessibilityHighContrast) { appState.markDraftEdited(draft) }
            }

            Section("Publishing") {
                Picker("Visibility", selection: $draft.visibility) {
                    Text("Private").tag("private")
                    Text("Unlisted").tag("unlisted")
                    Text("Public").tag("public")
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.visibility) { appState.markDraftEdited(draft) }
            }

            Section("Validation") {
                if appState.tierListCreatorIssues.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("No issues found")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(appState.tierListCreatorIssues) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(issue.message)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Items Tab

    private var itemsTab: some View {
        VStack(spacing: 0) {
            // Search and filter controls
            VStack(spacing: 12) {
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
            }
            .padding()

            // Items list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        itemRow(item)
                    }
                }
                .padding()
            }

            // Add item button
            Button {
                let newItem = appState.addItem(to: draft)
                selectedItemID = newItem.identifier
                showingItemDetailsSheet = true
            } label: {
                Label("Add New Item", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func itemRow(_ item: TierDraftItem) -> some View {
        Button {
            selectedItemID = item.identifier
            showingItemDetailsSheet = true
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(item.tier?.label ?? "Unassigned")
                        .font(.caption)
                        .foregroundStyle(item.tier != nil ? .blue : .secondary)
                }

                Spacer()

                if item.hidden {
                    Image(systemName: "eye.slash.fill")
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tiers Tab

    private var tiersTab: some View {
        VStack(spacing: 0) {
            // Tiers list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(orderedTiers) { tier in
                        tierRow(tier)
                    }
                }
                .padding()
            }

            // Add tier button
            Button {
                let newTier = appState.addTier(to: draft)
                selectedTierID = newTier.identifier
                showingTierDetailsSheet = true
            } label: {
                Label("Add New Tier", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private func tierRow(_ tier: TierDraftTier) -> some View {
        HStack(spacing: 16) {
            // Color indicator
            Circle()
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

            // Tier info
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.label)
                    .font(.headline)

                Text("\(appState.orderedItems(for: tier).count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status indicators
            HStack(spacing: 12) {
                if tier.locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }

                if tier.collapsed {
                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Actions
            HStack(spacing: 8) {
                Button {
                    appState.moveTier(tier, direction: -1, in: draft)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    appState.moveTier(tier, direction: 1, in: draft)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.bordered)

                Button {
                    selectedTierID = tier.identifier
                    showingTierDetailsSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    appState.delete(tier, from: draft)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

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
