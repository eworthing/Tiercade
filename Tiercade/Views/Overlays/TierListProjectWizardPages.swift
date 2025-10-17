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

struct SchemaWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var schemaFields: [SchemaFieldDefinition] = []
    @State private var showingAddField = false
    private let schemaAdditionalKey = "itemSchema"

    let pageTitle = "Item Schema"
    let pageDescription = "Define custom fields for your items"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Item Properties")
                        .font(.title2.weight(.semibold))

                    Text("Define what information each item should have. Examples: Year, Genre, Platform, Developer, Publisher")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Built-in fields
                VStack(alignment: .leading, spacing: 16) {
                    Text("Built-in Fields")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        builtInFieldRow("Title", icon: "textformat", type: "Text", required: true)
                        builtInFieldRow("Subtitle", icon: "text.alignleft", type: "Text", required: false)
                        builtInFieldRow("Summary", icon: "doc.text", type: "Text Area", required: false)
                        builtInFieldRow("Rating", icon: "star", type: "Number", required: false)
                    }
                    .padding(.horizontal, 20)
                }

                Divider()
                    .padding(.horizontal, 20)

                // Custom fields
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Custom Fields")
                            .font(.headline)

                        Spacer()

                        Button {
                            showingAddField = true
                        } label: {
                            Label("Add Field", systemImage: "plus.circle.fill")
                        }
                        #if os(tvOS)
                        .buttonStyle(.glassProminent)
                        #else
                        .buttonStyle(.borderedProminent)
                        #endif
                        .accessibilityIdentifier("Schema_AddField")
                    }
                    .padding(.horizontal, 20)

                    if schemaFields.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No custom fields yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add fields to capture specific information about your items")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(schemaFields) { field in
                                customFieldRow(field)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .sheet(isPresented: $showingAddField) {
            AddSchemaFieldSheet(onAdd: { field in
                schemaFields.append(field)
                persistSchemaChange()
            })
        }
        .onAppear {
            loadSchema()
        }
    }

    private func builtInFieldRow(_ name: String, icon: String, type: String, required: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(type)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func customFieldRow(_ field: SchemaFieldDefinition) -> some View {
        HStack(spacing: 16) {
            Image(systemName: field.fieldType.icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(field.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(field.fieldType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if field.required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if field.allowMultiple {
                        Text("• Multiple")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation {
                    schemaFields.removeAll { $0.id == field.id }
                    persistSchemaChange()
                }
            } label: {
                Image(systemName: "trash")
            }
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.bordered)
            #endif
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadSchema() {
        guard let stored = draft.additional?[schemaAdditionalKey] else {
            schemaFields = []
            return
        }

        do {
            let data = try TierListCreatorCodec.encoder.encode(stored)
            schemaFields = try TierListCreatorCodec.decoder.decode([SchemaFieldDefinition].self, from: data)
        } catch {
            Logger.appState.error("Schema decode failed: \(error.localizedDescription, privacy: .public)")
            schemaFields = []
        }
    }

    private func saveSchema() {
        do {
            var additional = draft.additional ?? [:]
            if schemaFields.isEmpty {
                additional.removeValue(forKey: schemaAdditionalKey)
                draft.additional = additional.isEmpty ? nil : additional
            } else {
                let data = try TierListCreatorCodec.encoder.encode(schemaFields)
                let json = try TierListCreatorCodec.decoder.decode(JSONValue.self, from: data)
                additional[schemaAdditionalKey] = json
                draft.additional = additional
            }
        } catch {
            Logger.appState.error("Schema encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistSchemaChange() {
        saveSchema()
        appState.markDraftEdited(draft)
    }
}

// MARK: - Add Schema Field Sheet

struct AddSchemaFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (SchemaFieldDefinition) -> Void

    @State private var fieldName = ""
    @State private var fieldType: SchemaFieldDefinition.FieldType = .text
    @State private var required = false
    @State private var allowMultiple = false
    @State private var options: [String] = []
    @State private var newOption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Information") {
                    TextField("Field Name", text: $fieldName, prompt: Text("e.g., Genre, Year, Platform"))
                    #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                    #endif

                    Picker("Field Type", selection: $fieldType) {
                        ForEach(SchemaFieldDefinition.FieldType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Required Field", isOn: $required)
                    Toggle("Allow Multiple Values", isOn: $allowMultiple)
                }

                if fieldType == .singleSelect || fieldType == .multiSelect {
                    Section("Select Options") {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Text(option)
                                Spacer()
                                Button(role: .destructive) {
                                    options.removeAll { $0 == option }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        HStack {
                            TextField("New Option", text: $newOption)
                            #if !os(tvOS)
                                .textFieldStyle(.roundedBorder)
                            #endif
                            Button {
                                if !newOption.isEmpty {
                                    options.append(newOption)
                                    newOption = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Add Custom Field")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let field = SchemaFieldDefinition(
                            name: fieldName,
                            fieldType: fieldType,
                            required: required,
                            allowMultiple: allowMultiple,
                            options: options
                        )
                        onAdd(field)
                        dismiss()
                    }
                    .disabled(fieldName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Items Wizard Page

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
            // Color indicator
            Circle()
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

            // Tier info
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.label)
                    .font(.headline)
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    appState.moveTier(tier, direction: -1, in: draft)
                } label: {
                    Image(systemName: "arrow.up")
                }
                #if os(tvOS)
                .buttonStyle(.glass)
                #else
                .buttonStyle(.bordered)
                #endif

                Button {
                    appState.moveTier(tier, direction: 1, in: draft)
                } label: {
                    Image(systemName: "arrow.down")
                }
                #if os(tvOS)
                .buttonStyle(.glass)
                #else
                .buttonStyle(.bordered)
                #endif

                Button {
                    selectedTierID = tier.identifier
                    showingTierDetailsSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                #if os(tvOS)
                .buttonStyle(.glass)
                #else
                .buttonStyle(.bordered)
                #endif

                Button(role: .destructive) {
                    appState.delete(tier, from: draft)
                } label: {
                    Image(systemName: "trash")
                }
                #if os(tvOS)
                .buttonStyle(.glass)
                #else
                .buttonStyle(.bordered)
                #endif
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

    private var currentTier: TierDraftTier? {
        guard let id = selectedTierID else { return nil }
        return draft.tiers.first { $0.identifier == id }
    }
}
