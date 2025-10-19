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

#if os(tvOS)
    @Namespace private var defaultFocusNamespace
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, description }
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                projectInfoSection
                displayOptionsSection
                accessibilitySection
                publishingSection
                validationSection
            }
            .padding(.horizontal, Metrics.grid * 6)
            .padding(.vertical, Metrics.grid * 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
#if os(tvOS)
        .onAppear { focusedField = .title }
#endif
    }

    // MARK: - Sections

    private var projectInfoSection: some View {
        sectionContainer(title: "Project Information") {
            TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                .font(.title3)
#if os(tvOS)
                .wizardFieldDecoration()
#else
                .textFieldStyle(.roundedBorder)
#endif
                .accessibilityIdentifier("Settings_TitleField")
                .onChange(of: draft.title) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .focused($focusedField, equals: .title)
                .prefersDefaultFocus(true, in: defaultFocusNamespace)
#endif

            TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                .lineLimit(3...6)
#if os(tvOS)
                .wizardFieldDecoration()
#else
                .textFieldStyle(.roundedBorder)
#endif
                .accessibilityIdentifier("Settings_DescriptionField")
                .onChange(of: draft.summary) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .focused($focusedField, equals: .description)
#endif
        }
    }

    private var displayOptionsSection: some View {
        sectionContainer(title: "Display Options") {
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
                    .foregroundStyle(Palette.textDim)
            }
            .font(.title3)
#endif

            Toggle("Show Unranked Tier", isOn: $draft.showUnranked)
                .accessibilityIdentifier("Settings_ShowUnrankedToggle")
                .onChange(of: draft.showUnranked) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .wizardTogglePadding()
#endif

            Toggle("Enable Grid Snap", isOn: $draft.gridSnap)
                .accessibilityIdentifier("Settings_GridSnapToggle")
                .onChange(of: draft.gridSnap) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .wizardTogglePadding()
#endif
        }
    }

    private var accessibilitySection: some View {
        sectionContainer(title: "Accessibility") {
            Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                .accessibilityIdentifier("Settings_VoiceOverToggle")
                .onChange(of: draft.accessibilityVoiceOver) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .wizardTogglePadding()
#endif

            Toggle("High Contrast Mode", isOn: $draft.accessibilityHighContrast)
                .accessibilityIdentifier("Settings_HighContrastToggle")
                .onChange(of: draft.accessibilityHighContrast) { appState.markDraftEdited(draft) }
#if os(tvOS)
                .wizardTogglePadding()
#endif
        }
    }

    private var publishingSection: some View {
        sectionContainer(title: "Publishing") {
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
        sectionContainer(title: "Validation") {
            if appState.tierListCreatorIssues.isEmpty {
                statusChip(
                    icon: "checkmark.circle.fill",
                    tint: Palette.tierColor("B"),
                    title: "No issues found",
                    message: "Your project configuration is valid"
                )
            } else {
                VStack(alignment: .leading, spacing: Metrics.grid * 2) {
                    ForEach(appState.tierListCreatorIssues) { issue in
                        statusChip(
                            icon: "exclamationmark.triangle.fill",
                            tint: Palette.tierColor("S"),
                            title: issue.category.rawValue.capitalized,
                            message: issue.message
                        )
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

    private func sectionContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2.5) {
            sectionHeader(title)
            content()
        }
        .padding(.all, Metrics.grid * 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Palette.stroke.opacity(0.6), radius: 8, y: 4)
    }

    private func statusChip(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(spacing: Metrics.grid * 2) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: Metrics.grid) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text(message)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(Metrics.grid * 2.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(tint.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

#if os(tvOS)
private extension View {
    func wizardFieldDecoration() -> some View {
        self
            .padding(.vertical, Metrics.grid * 1.5)
            .padding(.horizontal, Metrics.grid * 2)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                    .fill(Palette.surface.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            )
    }

    func wizardTogglePadding() -> some View {
        self.padding(.vertical, Metrics.grid)
    }
}
#endif

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
            HStack(spacing: 20) {
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

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textDim)
                    .font(.title3)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                    .fill(Palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            )
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

#if os(tvOS)
    @Namespace private var defaultFocusNamespace
#endif

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.grid * 3) {
                    assignmentOverviewSection

                    Divider()
                        .padding(.horizontal, Metrics.grid * 6)

                    tierManagementSection
                }
                .padding(.horizontal, Metrics.grid * 6)
                .padding(.vertical, Metrics.grid * 5)
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
                .prefersDefaultFocus(true, in: defaultFocusNamespace)
                #else
                .buttonStyle(.borderedProminent)
                #endif
                .accessibilityIdentifier("Tiers_AddTier")
            }
            .padding(.horizontal, Metrics.grid * 6)
            .padding(.vertical, Metrics.grid * 3)
            .background(
                Rectangle()
                    .fill(Palette.cardBackground.opacity(0.9))
                    .overlay(Rectangle().stroke(Palette.stroke, lineWidth: 1))
            )
        }
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
    }

    private var assignmentOverviewSection: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Assignment Overview")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.text)

            let assignedCount = draft.items.filter { $0.tier != nil }.count
            let totalCount = draft.items.count
            let percentage = totalCount > 0 ? Double(assignedCount) / Double(totalCount) * 100 : 0

            HStack(spacing: Metrics.grid * 3) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned Items")
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)
                    Text("\(assignedCount) / \(totalCount)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Palette.text)
                }

                Divider()
                    .frame(height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)
                    Text(String(format: "%.0f%%", percentage))
                        .font(.title.weight(.bold))
                        .foregroundStyle(percentage == 100 ? Palette.tierColor("B") : Palette.text)
                }

                Spacer()
            }
            .padding(Metrics.grid * 2.5)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                    .fill(Palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private var tierManagementSection: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            Text("Tier Management")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.text)

            if orderedTiers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: Metrics.grid * 2) {
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
                .foregroundStyle(Palette.textDim)
            Text("No tiers defined")
                .font(.title3)
            Text("Use the Add Tier button below to create ranking tiers")
                .font(.body)
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
    }

    private func tierManagementCard(_ tier: TierDraftTier) -> some View {
        let items = appState.orderedItems(for: tier)

        return HStack(spacing: 16) {
            Circle()
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Palette.stroke.opacity(0.5), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.label)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
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
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
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
