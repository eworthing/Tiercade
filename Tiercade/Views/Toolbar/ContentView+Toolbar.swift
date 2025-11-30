import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - ToolbarView

struct ToolbarView: ToolbarContent {

    // MARK: Internal

    @Bindable var app: AppState

    var body: some ToolbarContent {
        // Quick menu - iOS uses leading position, macOS uses principal
        #if os(iOS)
        ToolbarItemGroup(placement: .topBarLeading) {
            TierListQuickMenu(app: app)
                .frame(minWidth: 200)
        }
        #elseif os(macOS)
        ToolbarItem(placement: .principal) {
            TierListQuickMenu(app: app)
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 360)
        }
        #endif

        // Debug Demo button (DEBUG builds only, all platforms)
        #if DEBUG
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                app.showDesignDemo = true
            } label: {
                Label("Design Demo", systemImage: "square.grid.3x3")
            }
            .accessibilityIdentifier("Toolbar_DesignDemo")
        }
        #elseif os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                app.showDesignDemo = true
            } label: {
                Label("Design Demo", systemImage: "square.grid.3x3")
            }
            .accessibilityIdentifier("Toolbar_DesignDemo")
            .help("View Tier Row Design Options")
        }
        #elseif os(tvOS)
        ToolbarItem(placement: .automatic) {
            Button {
                app.showDesignDemo = true
            } label: {
                Label("Design Demo", systemImage: "square.grid.3x3")
            }
            .accessibilityIdentifier("Toolbar_DesignDemo")
        }
        #endif
        #endif

        // Primary actions - iOS uses topBarTrailing, macOS uses automatic
        #if os(iOS)
        ToolbarItemGroup(placement: .topBarTrailing) {
            primaryActionButtons
        }
        #elseif os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            primaryActionButtons
        }
        #endif

        // iOS-only bottom bar for multi-select mode
        #if os(iOS)
        ToolbarItemGroup(placement: .bottomBar) {
            if editMode?.wrappedValue == .active {
                let count = app.selection.count
                Label("\(count) Selected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .accessibilityIdentifier("Toolbar_SelectionCount")

                Menu {
                    ForEach(app.tierOrder, id: \.self) { tier in
                        let label = app.displayLabel(for: tier)
                        Button(label) {
                            app.batchMove(Array(app.selection), to: tier)
                        }
                        .disabled(app.isTierLocked(tier))
                    }
                    Divider()
                    Button("Move to Unranked") {
                        app.batchMove(Array(app.selection), to: "unranked")
                    }
                } label: {
                    Label("Move…", systemImage: "arrow.up.right.square")
                }
                .disabled(app.selection.isEmpty)
                .accessibilityIdentifier("Toolbar_MoveSelection")

                Button {
                    app.clearSelection()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .disabled(app.selection.isEmpty)
                .accessibilityIdentifier("Toolbar_ClearSelection")
            }
        }
        #endif

        // Secondary actions menu (macOS/tvOS only - iOS uses trailing Actions menu)
        #if os(macOS) || os(tvOS)
        SecondaryToolbarActions(
            app: app,
            onShowSave: { showingSaveDialog = true },
            onShowLoad: { showingLoadDialog = true },
            onShowExportFormat: handleExportFormatSelection,
            onImportJSON: { importingJSON = true },
            onImportCSV: { showingImportSheet = true },
            onShowSettings: { showingSettings = true },
        )
        #endif

        // Sheet presentations (iOS-specific vs macOS/tvOS)
        #if os(iOS)
        BottomToolbarSheets(
            app: app,
            exportText: $exportText,
            showingSettings: $showingSettings,
            showingExportFormatSheet: $showingExportFormatSheet,
            selectedExportFormat: $selectedExportFormat,
            exportingJSON: $exportingJSON,
            importingJSON: $importingJSON,
            jsonDoc: $jsonDoc,
            showingImportSheet: $showingImportSheet,
            showingSaveDialog: $showingSaveDialog,
            showingLoadDialog: $showingLoadDialog,
            saveFileName: $saveFileName,
        )
        #else
        MacAndTVToolbarSheets(
            app: app,
            showingSaveDialog: $showingSaveDialog,
            showingLoadDialog: $showingLoadDialog,
            saveFileName: $saveFileName,
            showingSettings: $showingSettings,
        )
        #endif
    }

    func handleExportFormatSelection(_ format: ExportFormat) {
        selectedExportFormat = format
        #if os(iOS)
        if format == .json {
            jsonDoc = TiersDocument(tiers: app.tiers)
            exportingJSON = true
        } else {
            showingExportFormatSheet = true
        }
        #else
        showingExportFormatSheet = true
        #endif
    }

    // MARK: Private

    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif
    @State private var exportText: String = ""
    @State private var showingSettings = false
    @State private var showingExportFormatSheet = false
    @State private var selectedExportFormat: ExportFormat = .text
    @State private var exportingJSON = false
    @State private var importingJSON = false
    #if os(iOS)
    @State private var jsonDoc = TiersDocument()
    #endif
    @State private var showingImportSheet = false
    @State private var showingSaveDialog = false
    @State private var showingLoadDialog = false
    @State private var saveFileName = ""

    @ViewBuilder
    private var primaryActionButtons: some View {
        // 1. Card Size Menu (all platforms - Label for Icon+Text support)
        #if !os(tvOS)
        Menu {
            ForEach(CardDensityPreference.allCases, id: \.self) { density in
                Button {
                    print("🔍 [Toolbar] Card Size handler: \(density.displayName)")
                    app.setCardDensityPreference(density)
                } label: {
                    Label(
                        density.displayName,
                        systemImage: app.cardDensityPreference == density ? "checkmark" : "",
                    )
                }
            }
        } label: {
            Label("Card Size", systemImage: app.cardDensityPreference.symbolName)
        }
        .accessibilityIdentifier("Toolbar_CardSize")
        #if os(macOS)
            .help("Card Size")
        #endif
        #endif

        // 2. Sort Menu (macOS only)
        #if os(macOS)
        Menu {
            // Current sort mode indicator
            Section {
                Label(
                    "Current: \(app.globalSortMode.displayName)",
                    systemImage: "checkmark.circle",
                )
            }

            Divider()

            // Manual order
            Button {
                app.setGlobalSortMode(.custom)
            } label: {
                Label(
                    "Manual Order",
                    systemImage: app.globalSortMode.isCustom ? "checkmark" : "",
                )
            }

            // Alphabetical
            Button {
                app.setGlobalSortMode(.alphabetical(ascending: true))
            } label: {
                let isSelected = {
                    if case let .alphabetical(asc) = app.globalSortMode, asc {
                        return true
                    }
                    return false
                }()
                Label("A → Z", systemImage: isSelected ? "checkmark" : "")
            }

            Button {
                app.setGlobalSortMode(.alphabetical(ascending: false))
            } label: {
                let isSelected = {
                    if case let .alphabetical(asc) = app.globalSortMode, !asc {
                        return true
                    }
                    return false
                }()
                Label("Z → A", systemImage: isSelected ? "checkmark" : "")
            }

            // Discovered attributes
            let discovered = app.discoverSortableAttributes()
            if !discovered.isEmpty {
                Divider()

                ForEach(Array(discovered.keys.sorted()), id: \.self) { key in
                    if let type = discovered[key] {
                        Menu(key.capitalized) {
                            Button {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: true, type: type))
                            } label: {
                                let isSelected = {
                                    if
                                        case let .byAttribute(k, asc, _) = app.globalSortMode,
                                        k == key, asc
                                    {
                                        return true
                                    }
                                    return false
                                }()
                                Label("\(key.capitalized) ↑", systemImage: isSelected ? "checkmark" : "")
                            }

                            Button {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: false, type: type))
                            } label: {
                                let isSelected = {
                                    if
                                        case let .byAttribute(k, asc, _) = app.globalSortMode,
                                        k == key, !asc
                                    {
                                        return true
                                    }
                                    return false
                                }()
                                Label("\(key.capitalized) ↓", systemImage: isSelected ? "checkmark" : "")
                            }
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("Toolbar_Sort")
        .help("Sort items by different criteria")
        #endif

        // 3. Apply Sort Button (macOS only - shows when sort is active)
        #if os(macOS)
        if !app.globalSortMode.isCustom {
            Button {
                app.applyGlobalSortToCustom()
            } label: {
                Label("Apply Sort", systemImage: "checkmark.circle.fill")
            }
            .accessibilityIdentifier("Toolbar_ApplySort")
            .help("Apply current sort to manual order")
        }
        #endif

        // 4. HeadToHead (iOS/macOS)
        #if !os(tvOS)
        Button {
            print("🔍 [Toolbar] HeadToHead handler triggered")
            app.startHeadToHead()
        } label: {
            Label("HeadToHead", systemImage: "person.line.dotted.person.fill")
        }
        .disabled(!app.canStartHeadToHead)
        .accessibilityIdentifier("Toolbar_HeadToHead")
        #if os(iOS)
            .keyboardShortcut("r", modifiers: [.command])
        #elseif os(macOS)
            .keyboardShortcut("h", modifiers: [.control, .command])
            .help("Start HeadToHead ranking (⌃⌘H)")
        #endif
        #endif

        // 5. Analysis (iOS/macOS)
        #if !os(tvOS)
        Button {
            app.toggleAnalysis()
        } label: {
            Label(
                "Analysis",
                systemImage: app.showingAnalysis ? "chart.bar.fill" : "chart.bar",
            )
        }
        .disabled(!app.canShowAnalysis && !app.showingAnalysis)
        .accessibilityIdentifier("Toolbar_Analysis")
        #if os(iOS)
            .keyboardShortcut("i", modifiers: [.command])
        #elseif os(macOS)
            .keyboardShortcut("a", modifiers: [.command, .option])
            .help(app.showingAnalysis ? "Hide Analysis (⌥⌘A)" : "Show Analysis (⌥⌘A)")
        #endif
        #endif

        // 6. Themes (iOS/macOS)
        #if !os(tvOS)
        Button {
            app.toggleThemePicker()
        } label: {
            Label("Themes", systemImage: "paintpalette")
        }
        .accessibilityIdentifier("Toolbar_Themes")
        #if !os(tvOS)
            .keyboardShortcut("t", modifiers: [.command, .option])
        #if os(macOS)
            .help("Browse tier themes (⌥⌘T)")
        #endif
        #endif
        #endif

        // 7. Apple Intelligence (all platforms)
        if AIGenerationState.isSupportedOnCurrentPlatform {
            Button {
                app.toggleAIChat()
            } label: {
                Label("Apple Intelligence", systemImage: "sparkles")
            }
            .accessibilityIdentifier("Toolbar_AIChat")
            #if os(macOS)
                .help("Chat with Apple Intelligence")
            #endif
        }

        // 8. Multi-Select (iOS only)
        #if os(iOS)
        let multiSelectActive = editMode?.wrappedValue == .active
        Button {
            let isActive = editMode?.wrappedValue == .active
            withAnimation(.easeInOut(duration: 0.18)) {
                editMode?.wrappedValue = isActive ? .inactive : .active
            }
            if isActive {
                app.clearSelection()
            }
        } label: {
            Label(
                multiSelectActive ? "Done" : "Select",
                systemImage: multiSelectActive ? "checkmark.rectangle.stack.fill" : "rectangle.stack.badge.plus",
            )
            .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.borderedProminent)
        .tint(multiSelectActive ? Color.accentColor : Color.secondary.opacity(0.35))
        .accessibilityIdentifier("Toolbar_MultiSelect")
        .accessibilityLabel(multiSelectActive ? "Finish selection" : "Start selection")
        .accessibilityValue(multiSelectActive ? "\(app.selection.count) items selected" : "")
        .keyboardShortcut("e", modifiers: [.command])
        #endif
    }

    // Helper methods for sort mode matching
    private func matchesMode(_ mode: GlobalSortMode) -> Bool {
        switch (app.globalSortMode, mode) {
        case (.custom, .custom):
            true
        case let (.alphabetical(asc1), .alphabetical(asc2)):
            asc1 == asc2
        default:
            false
        }
    }

    private func matchesAttributeMode(key: String, ascending: Bool) -> Bool {
        if case let .byAttribute(k, asc, _) = app.globalSortMode {
            return k == key && asc == ascending
        }
        return false
    }

}

// MARK: - SecondaryToolbarActions

struct SecondaryToolbarActions: ToolbarContent {

    // MARK: Internal

    @Bindable var app: AppState

    var onShowSave: () -> Void = {}
    var onShowLoad: () -> Void = {}
    var onShowExportFormat: (ExportFormat) -> Void = { _ in }
    var onImportJSON: () -> Void = {}
    var onImportCSV: () -> Void = {}
    var onShowSettings: () -> Void = {}

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            Menu("Actions") {
                ForEach(app.tierOrder, id: \.self) { tier in
                    let isTierEmpty = (app.tiers[tier]?.isEmpty ?? true)
                    Button("Clear \(app.displayLabel(for: tier)) Tier") { app.clearTier(tier) }
                        .disabled(isTierEmpty)
                }
                Divider()
                Button("Randomize") { app.randomize() }
                    .disabled(!app.canRandomizeItems)
                Button("Reset All", role: .destructive) { app.reset() }
                Divider()
                fileOperationsMenu
                exportImportMenu
                Divider()
                Button("Settings") { onShowSettings() }
            }
        }
    }

    // MARK: Private

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(tvOS)
        .automatic
        #else
        .secondaryAction
        #endif
    }

    private var fileOperationsMenu: some View {
        Menu("File Operations") {
            Button("Save Locally") { try? app.save() }
            #if !os(tvOS)
                .keyboardShortcut("s", modifiers: [.command])
            #endif
            Button("Load Saved") { _ = app.load() }
            #if !os(tvOS)
                .keyboardShortcut("o", modifiers: [.command])
            #endif
            Divider()
            Button("Save to File...") { onShowSave() }
            #if !os(tvOS)
                .keyboardShortcut("S", modifiers: [.command, .shift])
            #endif
            Button("Load from File...") { onShowLoad() }
            #if !os(tvOS)
                .keyboardShortcut("O", modifiers: [.command, .shift])
            #endif
            Button("Browse Tier Lists") { app.presentTierListBrowser() }
        }
    }

    private var exportImportMenu: some View {
        Menu("Export & Import") {
            Menu("Export As...") {
                Button("Text Format") { onShowExportFormat(.text) }
                Button("JSON Format") { onShowExportFormat(.json) }
                Button("Markdown Format") { onShowExportFormat(.markdown) }
                Button("CSV Format") { onShowExportFormat(.csv) }
                Button("PNG Image") { onShowExportFormat(.png) }
                #if !os(tvOS)
                Button("PDF Document") { onShowExportFormat(.pdf) }
                #endif
            }
            #if os(iOS)
            Menu("Import From...") {
                Button("JSON File") { onImportJSON() }
                Button("CSV File") { onImportCSV() }
            }
            #endif
        }
    }
}

#if os(iOS)
@MainActor
extension AppState: ToolbarExportCoordinating {}
#endif
