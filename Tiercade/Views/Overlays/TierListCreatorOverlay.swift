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
    @State private var highlightPreview = false

    private enum FocusArea: Hashable {
        case header
        case tiers
        case canvas
        case library
        case actionStrip
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
            .padding(.horizontal, 80)
            .padding(.vertical, 72)
        }
        .onAppear {
            focusArea = .tiers
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
            }

            Spacer()

            schemaVersionBadge

            Button {
                highlightPreview.toggle()
                withAnimation(.smooth(duration: 0.3)) {
                    focusArea = .canvas
                }
            } label: {
                Label("Preview", systemImage: "display")
            }
            .modifier(GlassButtonStyle(isProminent: false))

            Button {
                Task { await appState.saveTierListDraft(action: .save) }
            } label: {
                Label("Save", systemImage: "tray.and.arrow.down")
            }
            .modifier(GlassButtonStyle(isProminent: false))

            Button {
                if let payload = appState.exportTierListDraftPayload() {
                    exportPayload = payload
                    showingExportSheet = true
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .modifier(GlassButtonStyle(isProminent: false))

            Button {
                appState.cancelTierListCreator()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .modifier(GlassButtonStyle(isProminent: false))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .header)
    }

    private var schemaVersionBadge: some View {
        Text("Schema v\(draft.schemaVersion)")
            .font(.callout.monospacedDigit())
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
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
            compositionCanvas
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
                VStack(spacing: 12) {
                    ForEach(orderedTiers) { tier in
                        tierRow(tier)
                    }
                }
                .padding(.vertical, 4)
            }

            if let tier = currentTier {
                HStack(spacing: 12) {
                    Button { appState.moveTier(tier, direction: -1, in: draft) } label: {
                        Image(systemName: "arrow.up")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))

                    Button { appState.moveTier(tier, direction: 1, in: draft) } label: {
                        Image(systemName: "arrow.down")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))

                    Button(role: .destructive) {
                        appState.delete(tier, from: draft)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .modifier(GlassButtonStyle(isProminent: false))
                }
            }
        }
        .padding(28)
        .frame(width: 320)
        .creatorGlass()
        .focusSection()
        .defaultFocus($focusArea, .tiers)
    }

    private func tierRow(_ tier: TierDraftTier) -> some View {
        let isSelected = tier.identifier == selectedTierID
        return Button {
            selectedTierID = tier.identifier
            focusArea = .canvas
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(ColorUtilities.color(hex: tier.colorHex))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.label)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                    Text("Items: \(appState.orderedItems(for: tier).count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private var compositionCanvas: some View {
        VStack(alignment: .leading, spacing: 24) {
            if appState.tierListCreatorIssues.isEmpty == false {
                validationBanner
            }

            projectMetadataSection
            tierDetailEditor
            previewSection
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .canvas)
    }

    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.yellow)
                Text("Validation Issues")
                    .font(.headline)
            }
            ForEach(appState.tierListCreatorIssues) { issue in
                Text("• \(issue.message)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.yellow.opacity(0.12))
        )
    }

    private var projectMetadataSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Project Metadata")
                .font(.title3.weight(.semibold))

            TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .onChange(of: draft.title) { _ in appState.markDraftEdited(draft) }

            TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                .lineLimit(2...4)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .onChange(of: draft.summary) { _ in appState.markDraftEdited(draft) }

            HStack(spacing: 20) {
                #if !os(tvOS)
                Stepper(value: $draft.schemaVersion, in: 1...9) {
                    Text("Schema Version: \(draft.schemaVersion)")
                }
                .onChange(of: draft.schemaVersion) { _ in appState.markDraftEdited(draft) }
                #else
                Text("Schema Version: \(draft.schemaVersion)")
                #endif

                Toggle("Show Unranked", isOn: $draft.showUnranked)
                    .toggleStyle(.switch)
                    .onChange(of: draft.showUnranked) { _ in appState.markDraftEdited(draft) }

                Toggle("Grid Snap", isOn: $draft.gridSnap)
                    .toggleStyle(.switch)
                    .onChange(of: draft.gridSnap) { _ in appState.markDraftEdited(draft) }
            }

            HStack(spacing: 20) {
                Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                    .toggleStyle(.switch)
                    .onChange(of: draft.accessibilityVoiceOver) { _ in appState.markDraftEdited(draft) }

                Toggle("High Contrast", isOn: $draft.accessibilityHighContrast)
                    .toggleStyle(.switch)
                    .onChange(of: draft.accessibilityHighContrast) { _ in appState.markDraftEdited(draft) }

                Picker("Visibility", selection: $draft.visibility) {
                    Text("Private").tag("private")
                    Text("Unlisted").tag("unlisted")
                    Text("Public").tag("public")
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.visibility) { _ in appState.markDraftEdited(draft) }
            }
        }
    }

    private var tierDetailEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tier Details")
                    .font(.title3.weight(.semibold))
                Spacer()
                if let tier = currentTier {
                    Toggle("Locked", isOn: Binding(
                        get: { tier.locked },
                        set: { _ in appState.toggleLock(tier, in: draft) }
                    ))
                    .toggleStyle(.switch)

                    Toggle("Collapsed", isOn: Binding(
                        get: { tier.collapsed },
                        set: { _ in appState.toggleCollapse(tier, in: draft) }
                    ))
                    .toggleStyle(.switch)
                }
            }

            if let tier = currentTier {
                TextField("Display Label", text: Binding(
                    get: { tier.label },
                    set: { newValue in
                        tier.label = newValue
                        appState.markDraftEdited(draft)
                    }
                ))
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

                TextField("Tier Identifier", text: Binding(
                    get: { tier.tierId },
                    set: { newValue in
                        tier.tierId = newValue
                        appState.markDraftEdited(draft)
                    }
                ))
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

                TextField("Color Hex", text: Binding(
                    get: { tier.colorHex },
                    set: { newValue in
                        tier.colorHex = newValue
                        appState.markDraftEdited(draft)
                    }
                ))
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif

                Rectangle()
                    .fill(ColorUtilities.color(hex: tier.colorHex))
                    .frame(height: 12)
                    .clipShape(Capsule())
            } else {
                Text("Select a tier to edit its properties.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live Preview")
                    .font(.title3.weight(.semibold))
                if highlightPreview {
                    Text("Focused")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.25)))
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(orderedTiers) { tier in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(tier.label)
                                    .font(.headline)
                                Spacer()
                                Text("\(appState.orderedItems(for: tier).count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(appState.orderedItems(for: tier)) { item in
                                        Text(item.title)
                                            .font(.callout)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.white.opacity(0.08))
                                            )
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
            .frame(maxHeight: 260)
        }
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
                    focusArea = .library
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
                .modifier(GlassButtonStyle(isProminent: false))
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
                VStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        itemRow(item)
                    }
                }
                .padding(.vertical, 6)
            }

            if let item = currentItem {
                itemEditor(for: item)
            } else {
                Text("Select an item to edit metadata.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 360)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .library)
    }

    private func itemRow(_ item: TierDraftItem) -> some View {
        let isSelected = item.identifier == selectedItemID
        return Button {
            selectedItemID = item.identifier
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                    Text(item.tier?.label ?? "Unassigned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func itemEditor(for item: TierDraftItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.title3.weight(.semibold))

            TextField("Display Title", text: Binding(
                get: { item.title },
                set: { newValue in
                    item.title = newValue
                    appState.markDraftEdited(draft)
                }
            ))
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif

            TextField("Identifier", text: Binding(
                get: { item.itemId },
                set: { newValue in
                    item.itemId = newValue
                    appState.markDraftEdited(draft)
                }
            ))
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif

            TextField("Slug", text: Binding(
                get: { item.slug },
                set: { newValue in
                    item.slug = newValue
                    appState.markDraftEdited(draft)
                }
            ))
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif

            TextField("Subtitle", text: Binding(
                get: { item.subtitle },
                set: { newValue in
                    item.subtitle = newValue
                    appState.markDraftEdited(draft)
                }
            ))
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif

            TextField("Summary", text: Binding(
                get: { item.summary },
                set: { newValue in
                    item.summary = newValue
                    appState.markDraftEdited(draft)
                }
            ), axis: .vertical)
            .lineLimit(2...3)
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif

            #if !os(tvOS)
            Slider(value: Binding(
                get: { item.rating ?? 50 },
                set: { newValue in
                    item.rating = newValue
                    appState.markDraftEdited(draft)
                }
            ), in: 0...100, step: 1) {
                Text("Rating")
            }
            #endif
            Text("Rating: \(Int(item.rating ?? 50))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Hide from library", isOn: Binding(
                get: { item.hidden },
                set: { newValue in
                    item.hidden = newValue
                    appState.markDraftEdited(draft)
                }
            ))
            .toggleStyle(.switch)

            if let tier = currentTier {
                Button {
                    appState.assign(item, to: tier, in: draft)
                } label: {
                    Label("Assign to \(tier.label)", systemImage: "arrow.turn.down.right")
                }
                .modifier(GlassButtonStyle(isProminent: false))
            }
        }
        .padding(.top, 12)
    }

    private var actionStrip: some View {
        HStack(spacing: 24) {
            Button { } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(true)
            .modifier(GlassButtonStyle(isProminent: false))

            Button { } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(true)
            .modifier(GlassButtonStyle(isProminent: false))

            Button {
                let issues = appState.validateTierListDraft()
                if issues.isEmpty {
                    appState.showToast(
                        type: .success,
                        title: "Validation Passed",
                        message: "Draft is ready to save."
                    )
                }
            } label: {
                Label("Validate", systemImage: "checkmark.seal")
            }
            .modifier(GlassButtonStyle(isProminent: false))

            Spacer()

            Button {
                Task { await appState.saveTierListDraft(action: .publish) }
            } label: {
                Label("Publish", systemImage: "paperplane.fill")
            }
            .modifier(GlassButtonStyle(isProminent: true))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .creatorGlass()
        .focusSection()
        .focused($focusArea, equals: .actionStrip)
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
