import SwiftUI
import TiercadeCore
import os

// MARK: - Wizard Page Protocol

protocol WizardPage {
    var pageTitle: String { get }
    var pageDescription: String { get }
}

// MARK: - Settings Wizard Page

struct SettingsWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft

    let pageTitle = "Project Settings"
    let pageDescription = "Configure basic project information and options"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                projectInfoSection
                displayOptionsSection
                accessibilitySection
                publishingSection
                validationSection
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    private var projectInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Project Information")

            VStack(alignment: .leading, spacing: 16) {
                TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .font(.title3)
                    .onChange(of: draft.title) { appState.markDraftEdited(draft) }
                    .accessibilityIdentifier("Settings_TitleField")

                TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .lineLimit(3...6)
                    .onChange(of: draft.summary) { appState.markDraftEdited(draft) }
                    .accessibilityIdentifier("Settings_DescriptionField")
            }
        }
    }

    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Display Options")

            VStack(alignment: .leading, spacing: 16) {
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
                    .accessibilityIdentifier("Settings_ShowUnrankedToggle")

                Toggle("Enable Grid Snap", isOn: $draft.gridSnap)
                    .onChange(of: draft.gridSnap) { appState.markDraftEdited(draft) }
                    .accessibilityIdentifier("Settings_GridSnapToggle")
            }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Accessibility")

            VStack(alignment: .leading, spacing: 16) {
                Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                    .onChange(of: draft.accessibilityVoiceOver) { appState.markDraftEdited(draft) }
                    .accessibilityIdentifier("Settings_VoiceOverToggle")

                Toggle("High Contrast Mode", isOn: $draft.accessibilityHighContrast)
                    .onChange(of: draft.accessibilityHighContrast) { appState.markDraftEdited(draft) }
                    .accessibilityIdentifier("Settings_HighContrastToggle")
            }
        }
    }

    private var publishingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Publishing")

            Picker("Visibility", selection: $draft.visibility) {
                Text("Private").tag("private")
                Text("Unlisted").tag("unlisted")
                Text("Public").tag("public")
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.visibility) { appState.markDraftEdited(draft) }
            .accessibilityIdentifier("Settings_VisibilityPicker")
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader("Validation")

            if appState.tierListCreatorIssues.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No issues found")
                            .font(.headline)
                        Text("Your project configuration is valid")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(appState.tierListCreatorIssues) { issue in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .font(.body)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

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
            // Search and filter controls
            VStack(spacing: 16) {
                TextField("Search items", text: $searchQuery)
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .font(.title3)
                    .accessibilityIdentifier("Items_SearchField")

                Picker("Filter", selection: $itemFilter) {
                    ForEach(ItemFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("Items_FilterPicker")
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Items list
            ScrollView {
                LazyVStack(spacing: 16) {
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredItems) { item in
                            itemCard(item)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            // Add item button
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
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showingItemEditor) {
            if let item = currentItem {
                LargeItemEditorView(appState: appState, draft: draft, item: item)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No items found")
                .font(.title3)
            Text(searchQuery.isEmpty ? "Add items to populate your tier list" : "No items match your search")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func itemCard(_ item: TierDraftItem) -> some View {
        Button {
            selectedItemID = item.identifier
            showingItemEditor = true
        } label: {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        if let tier = item.tier {
                            Label(tier.label, systemImage: "tag")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Label("Unassigned", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if item.hidden {
                            Label("Hidden", systemImage: "eye.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
            }
            .padding(24)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Items_Card_\(item.itemId)")
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

// MARK: - Tiers Wizard Page

struct TiersWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var selectedTierID: UUID?
    @State private var showingTierDetailsSheet = false

    let pageTitle = "Tier Assignment"
    let pageDescription = "Review and manage item assignments to tiers"

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    assignmentOverviewSection

                    Divider()
                        .padding(.horizontal, 20)

                    tierManagementSection
                }
                .padding(20)
            }

            // Add tier button at bottom
            HStack {
                Spacer()
                Button {
                    let newTier = appState.addTier(to: draft)
                    selectedTierID = newTier.identifier
                    showingTierDetailsSheet = true
                } label: {
                    Label("Add Tier", systemImage: "plus.circle.fill")
                }
                #if os(tvOS)
                .buttonStyle(.glassProminent)
                #else
                .buttonStyle(.borderedProminent)
                #endif
                .accessibilityIdentifier("Tiers_AddTier")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
    }

    private var assignmentOverviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Assignment Overview")
                .font(.title2.weight(.semibold))

            let assignedCount = draft.items.filter { $0.tier != nil }.count
            let totalCount = draft.items.count
            let percentage = totalCount > 0 ? Double(assignedCount) / Double(totalCount) * 100 : 0

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(assignedCount) / \(totalCount)")
                        .font(.title.weight(.bold))
                }

                Divider()
                    .frame(height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", percentage))
                        .font(.title.weight(.bold))
                        .foregroundStyle(percentage == 100 ? .green : .primary)
                }

                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var tierManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tier Management")
                .font(.title2.weight(.semibold))

            if orderedTiers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(orderedTiers) { tier in
                        tierManagementCard(tier)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No tiers defined")
                .font(.title3)
            Text("Use the Add Tier button below to create ranking tiers")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func tierManagementCard(_ tier: TierDraftTier) -> some View {
        let items = appState.orderedItems(for: tier)

        return HStack(spacing: 16) {
            Circle()
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.label).font(.headline)
                Text("\(items.count) items").font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                tierActionButton("arrow.up") { appState.moveTier(tier, direction: -1, in: draft) }
                tierActionButton("arrow.down") { appState.moveTier(tier, direction: 1, in: draft) }
                tierActionButton("pencil") {
                    selectedTierID = tier.identifier
                    showingTierDetailsSheet = true
                }
                tierActionButton("trash", role: .destructive) { appState.delete(tier, from: draft) }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tierActionButton(
        _ icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.bordered)
        #endif
    }

    // MARK: - Helpers

    private var orderedTiers: [TierDraftTier] {
        appState.orderedTiers(for: draft)
    }

    private var currentTier: TierDraftTier? {
        guard let id = selectedTierID else { return nil }
        return draft.tiers.first { $0.identifier == id }
    }
}
