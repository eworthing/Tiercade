import SwiftUI
import TiercadeCore

// MARK: - Compact Tabbed Creator

internal struct TierListProjectWizard: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    internal let context: AppState.TierListWizardContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    #if os(tvOS)
    @Namespace private var toolbarFocusNamespace
    @Namespace private var tabFocusNamespace
    #endif

    // Sheet presentations for item/tier editing
    @State private var showingTierDetailsSheet = false
    @State private var showingItemDetailsSheet = false
    @State private var selectedTierID: UUID?
    @State private var selectedItemID: UUID?

    internal var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            contentSection
        }
        .background(Palette.bg)
        .sheet(isPresented: $showingTierDetailsSheet) {
            if let tier = currentTier {
                TierDetailsSheet(appState: appState, draft: draft, tier: tier)
            }
        }
        #if os(macOS)
        .sheet(isPresented: $showingItemDetailsSheet) {
            if let item = currentItem {
                LargeItemEditorView(appState: appState, draft: draft, item: item)
            }
        }
        #else
        .fullScreenCover(isPresented: $showingItemDetailsSheet) {
            if let item = currentItem {
                LargeItemEditorView(appState: appState, draft: draft, item: item)
            }
        }
        #endif
        #if os(tvOS)
        .onExitCommand { dismiss() }
        #endif
    }

    // MARK: - Sections

    private var toolbarSection: some View {
        Group {
            #if os(tvOS)
            tvGlassContainer(spacing: 0) {
                toolbarContent
            }
            .focusSection()
            // Scope default focus for toolbar buttons
            .focusScope(toolbarFocusNamespace)
            #else
            toolbarContent
                .background(.ultraThinMaterial)
            #endif
        }
    }

    private var contentSection: some View {
        TabView(selection: $selectedTab) {
            SettingsWizardPage(appState: appState, draft: draft)
                .tag(0)
                #if os(tvOS)
                .focusSection()
            #endif

            SchemaWizardPage(appState: appState, draft: draft)
                .tag(1)
                #if os(tvOS)
                .focusSection()
            #endif

            ItemsWizardPage(appState: appState, draft: draft)
                .tag(2)
                #if os(tvOS)
                .focusSection()
            #endif

            TiersWizardPage(appState: appState, draft: draft)
                .tag(3)
                #if os(tvOS)
                .focusSection()
            #endif
        }
        #if os(tvOS)
        .tabViewStyle(.page)
        #elseif os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        .tabViewStyle(.automatic)
        #endif
    }

    // MARK: - Toolbar Content

    private var toolbarContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Title
                Text(displayedTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Actions
                HStack(spacing: 12) {
                    Button {
                        Task { await appState.saveTierListDraft(action: .save) }
                    } label: {
                        Label(primaryActionTitle, systemImage: primaryActionSymbol)
                            #if os(tvOS)
                            .labelStyle(.iconOnly)
                        #else
                        .labelStyle(.titleAndIcon)
                        #endif
                    }
                    #if os(tvOS)
                    .buttonStyle(.glass)
                    .prefersDefaultFocus(true, in: toolbarFocusNamespace)
                    #else
                    .buttonStyle(.borderless)
                    #endif
                    .accessibilityIdentifier("Wizard_Save")

                    Button {
                        Task { await appState.saveTierListDraft(action: .publish) }
                    } label: {
                        Label(secondaryActionTitle, systemImage: secondaryActionSymbol)
                            #if os(tvOS)
                            .labelStyle(.iconOnly)
                        #else
                        .labelStyle(.titleAndIcon)
                        #endif
                    }
                    #if os(tvOS)
                    .buttonStyle(.glassProminent)
                    #else
                    .buttonStyle(.borderless)
                    .foregroundStyle(Palette.brand)
                    #endif
                    .accessibilityIdentifier("Wizard_Publish")

                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                            #if os(tvOS)
                            .labelStyle(.iconOnly)
                        #else
                        .labelStyle(.titleAndIcon)
                        #endif
                    }
                    #if os(tvOS)
                    .buttonStyle(.glass)
                    #else
                    .buttonStyle(.borderless)
                    #endif
                    .accessibilityIdentifier("Wizard_Close")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Tabs
            HStack(spacing: 0) {
                tabButton("Settings", icon: "gearshape", index: 0)
                tabButton("Schema", icon: "list.bullet.clipboard", index: 1)
                tabButton("Items", icon: "square.grid.3x3", index: 2)
                tabButton("Tiers", icon: "chart.bar", index: 3)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            #if os(tvOS)
            // Scope default focus for tab buttons when declaring prefersDefaultFocus
            .focusScope(tabFocusNamespace)
            #endif

            Divider()
        }
    }

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == index
                    ? Palette.brand.opacity(0.25)
                    : Palette.surface.opacity(0.35)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .prefersDefaultFocus(index == selectedTab, in: tabFocusNamespace)
        #endif
        .accessibilityIdentifier("Tab_\(title)")
    }

    private var displayedTitle: String {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch context {
        case .create:
            return trimmed.isEmpty ? "New Tier List" : trimmed
        case .edit(let handle):
            let base = trimmed.isEmpty ? handle.displayName : trimmed
            guard base.isEmpty == false else { return "Edit Tier List" }
            return "Edit \(base)"
        }
    }

    private var primaryActionTitle: String {
        switch context {
        case .create: return "Save"
        case .edit: return "Update"
        }
    }

    private var primaryActionSymbol: String {
        switch context {
        case .create: return "checkmark.circle"
        case .edit: return "arrow.triangle.2.circlepath"
        }
    }

    private var secondaryActionTitle: String {
        switch context {
        case .create: return "Publish"
        case .edit: return "Republish"
        }
    }

    private var secondaryActionSymbol: String {
        return "paperplane.fill"
    }

    // MARK: - Helpers

    private var currentTier: TierDraftTier? {
        guard let id = selectedTierID else { return nil }
        return draft.tiers.first { $0.identifier == id }
    }

    private var currentItem: TierDraftItem? {
        guard let id = selectedItemID else { return nil }
        return draft.items.first { $0.identifier == id }
    }
}

// MARK: - Large Item Editor

internal struct LargeItemEditorView: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @Bindable var item: TierDraftItem
    @Environment(\.dismiss) private var dismiss

    internal var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: Binding(
                        get: { item.title },
                        set: { newValue in
                            item.title = newValue
                            appState.markDraftEdited(draft)
                        }
                    ))
                    .font(.title3)
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
                    .lineLimit(3...6)
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                }

                Section("Tier Assignment") {
                    Picker("Tier", selection: Binding(
                        get: { item.tier?.identifier ?? UUID() },
                        set: { newTierID in
                            if let tier = draft.tiers.first(where: { $0.identifier == newTierID }) {
                                appState.assign(item, to: tier, in: draft)
                            }
                        }
                    )) {
                        Text("Unassigned").tag(UUID())
                        ForEach(appState.orderedTiers(for: draft)) { tier in
                            HStack {
                                Circle()
                                    .fill(ColorUtilities.color(hex: tier.colorHex))
                                    .frame(width: 16, height: 16)
                                Text(tier.label)
                            }
                            .tag(tier.identifier)
                        }
                    }
                }

                Section("Additional Details") {
                    TextField("Item ID", text: Binding(
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

                    #if !os(tvOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating: \(Int(item.rating ?? 50))")
                            .font(.caption)
                        Slider(value: Binding(
                            get: { item.rating ?? 50 },
                            set: { newValue in
                                item.rating = newValue
                                appState.markDraftEdited(draft)
                            }
                        ), in: 0...100, step: 1)
                    }
                    #else
                    Text("Rating: \(Int(item.rating ?? 50))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif

                    Toggle("Hide from library", isOn: Binding(
                        get: { item.hidden },
                        set: { newValue in
                            item.hidden = newValue
                            appState.markDraftEdited(draft)
                        }
                    ))
                }
            }
            .navigationTitle("Edit Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
