import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toolbar and supporting components

internal struct ToolbarView: ToolbarContent {
    @Bindable var app: AppState
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

    internal var body: some ToolbarContent {
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

        // Primary actions - iOS uses topBarTrailing, macOS uses automatic
        #if os(iOS)
        ToolbarItemGroup(placement: .topBarTrailing) {
            primaryActionButtons
        }
        #elseif os(macOS)
        ToolbarItemGroup(placement: .automatic) {
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
            onShowSettings: { showingSettings = true }
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
            saveFileName: $saveFileName
        )
        #else
        MacAndTVToolbarSheets(
            app: app,
            showingSaveDialog: $showingSaveDialog,
            showingLoadDialog: $showingLoadDialog,
            saveFileName: $saveFileName,
            showingSettings: $showingSettings
        )
        #endif
    }

    @ViewBuilder
    private var primaryActionButtons: some View {
        // 1. New Tier List (all platforms)
        Button {
            app.presentTierListCreator()
        } label: {
            Label("New Tier List…", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("Toolbar_NewTierList")
        #if os(macOS)
        .help("Create a new tier list (⇧⌘N)")
        #endif

        // 2. Card Size Menu (all platforms - Label for Icon+Text support)
        #if !os(tvOS)
        Menu {
            ForEach(CardDensityPreference.allCases, id: \.self) { density in
                Button {
                    print("🔍 [Toolbar] Card Size handler: \(density.displayName)")
                    app.setCardDensityPreference(density)
                } label: {
                    Label(
                        density.displayName,
                        systemImage: app.cardDensityPreference == density ? "checkmark" : ""
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

        // 3. Head-to-Head (iOS/macOS)
        #if !os(tvOS)
        Button {
            print("🔍 [Toolbar] H2H handler triggered")
            app.startH2H()
        } label: {
            Label("Head-to-Head", systemImage: "person.line.dotted.person.fill")
        }
        .disabled(!app.canStartHeadToHead)
        .accessibilityIdentifier("Toolbar_H2H")
        #if os(macOS)
        .keyboardShortcut("h", modifiers: [.command, .shift])
        .help("Start head-to-head ranking (⇧⌘H)")
        #endif
        #endif

        // 4. Analysis (iOS/macOS)
        #if !os(tvOS)
        Button {
            app.toggleAnalysis()
        } label: {
            Label(
                "Analysis",
                systemImage: app.showingAnalysis ? "chart.bar.fill" : "chart.bar"
            )
        }
        .disabled(!app.canShowAnalysis && !app.showingAnalysis)
        .accessibilityIdentifier("Toolbar_Analysis")
        #if os(macOS)
        .keyboardShortcut("a", modifiers: [.command, .option])
        .help(app.showingAnalysis ? "Hide Analysis (⌥⌘A)" : "Show Analysis (⌥⌘A)")
        #endif
        #endif

        // 5. Themes (iOS/macOS)
        #if !os(tvOS)
        Button {
            app.toggleThemePicker()
        } label: {
            Label("Themes", systemImage: "paintpalette")
        }
        .accessibilityIdentifier("Toolbar_Themes")
        #if os(macOS)
        .keyboardShortcut("t", modifiers: [.command, .option])
        .help("Browse tier themes (⌥⌘T)")
        #endif
        #endif

        // 6. Sort Menu (iOS/macOS)
        #if !os(tvOS)
        Menu {
            Section {
                Label("Current: \(app.globalSortMode.displayName)", systemImage: "checkmark.circle")
            }

            Divider()

            Button {
                app.setGlobalSortMode(.custom)
            } label: {
                Label("Manual Order", systemImage: app.globalSortMode.isCustom ? "checkmark" : "")
            }

            Menu("Alphabetical") {
                Button {
                    app.setGlobalSortMode(.alphabetical(ascending: true))
                } label: {
                    Label("A → Z", systemImage: matchesMode(.alphabetical(ascending: true)) ? "checkmark" : "")
                }
                Button {
                    app.setGlobalSortMode(.alphabetical(ascending: false))
                } label: {
                    Label("Z → A", systemImage: matchesMode(.alphabetical(ascending: false)) ? "checkmark" : "")
                }
            }

            let discovered = app.discoverSortableAttributes()
            if !discovered.isEmpty {
                Divider()
                ForEach(Array(discovered.keys.sorted()), id: \.self) { key in
                    Menu(key.capitalized) {
                        Button {
                            if let type = discovered[key] {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: true, type: type))
                            }
                        } label: {
                            Label("Ascending ↑", systemImage: matchesAttributeMode(key: key, ascending: true) ? "checkmark" : "")
                        }
                        Button {
                            if let type = discovered[key] {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: false, type: type))
                            }
                        } label: {
                            Label("Descending ↓", systemImage: matchesAttributeMode(key: key, ascending: false) ? "checkmark" : "")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("Toolbar_Sort")
        #if os(macOS)
        .help("Sort items")
        #endif
        #endif

        // 7. Apply Sort Button (iOS/macOS - shows when sort is active)
        #if !os(tvOS)
        if !app.globalSortMode.isCustom {
            Button {
                app.applyGlobalSortToCustom()
            } label: {
                Label("Apply Sort", systemImage: "checkmark.circle.fill")
            }
            .accessibilityIdentifier("Toolbar_ApplySort")
            #if os(macOS)
            .help("Apply current sort to manual order")
            #endif
        }
        #endif

        // 8. Apple Intelligence (all platforms)
        if AppleIntelligenceService.isSupportedOnCurrentPlatform {
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

        // 7. Multi-Select (iOS only)
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
                systemImage: multiSelectActive ? "checkmark.rectangle.stack.fill" : "rectangle.stack.badge.plus"
            )
            .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.borderedProminent)
        .tint(multiSelectActive ? Color.accentColor : Color.secondary.opacity(0.35))
        .accessibilityIdentifier("Toolbar_MultiSelect")
        .accessibilityLabel(multiSelectActive ? "Finish selection" : "Start selection")
        .accessibilityValue(multiSelectActive ? "\(app.selection.count) items selected" : "")
        #endif
    }

    // Helper methods for sort mode matching
    private func matchesMode(_ mode: GlobalSortMode) -> Bool {
        switch (app.globalSortMode, mode) {
        case (.custom, .custom):
            return true
        case (.alphabetical(let asc1), .alphabetical(let asc2)):
            return asc1 == asc2
        default:
            return false
        }
    }

    private func matchesAttributeMode(key: String, ascending: Bool) -> Bool {
        if case .byAttribute(let k, let asc, _) = app.globalSortMode {
            return k == key && asc == ascending
        }
        return false
    }

    #if os(iOS)
    // iOS title menu content (tap navigation title to reveal)
    @ViewBuilder
    internal var titleMenuContent: some View {
        Button {
            app.startH2H()
        } label: {
            Label("Head-to-Head", systemImage: "person.line.dotted.person.fill")
        }
        .disabled(!app.canStartHeadToHead)
        .accessibilityIdentifier("TitleMenu_H2H")

        Button {
            app.toggleAnalysis()
        } label: {
            Label(
                app.showingAnalysis ? "Hide Analysis" : "Show Analysis",
                systemImage: app.showingAnalysis ? "chart.bar.fill" : "chart.bar"
            )
        }
        .disabled(!app.canShowAnalysis && !app.showingAnalysis)
        .accessibilityIdentifier("TitleMenu_Analysis")

        Button {
            app.toggleThemePicker()
        } label: {
            Label("Themes", systemImage: "paintpalette")
        }
        .accessibilityIdentifier("TitleMenu_Themes")

        Menu("Card Size") {
            ForEach(CardDensityPreference.allCases, id: \.self) { density in
                Button {
                    app.setCardDensityPreference(density)
                } label: {
                    Label(
                        density.displayName,
                        systemImage: app.cardDensityPreference == density ? "checkmark" : ""
                    )
                }
            }
        }
        .accessibilityIdentifier("TitleMenu_CardSize")
    }
    #endif

    private func handleExportFormatSelection(_ format: ExportFormat) {
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
}

#if os(iOS)
internal struct TiersDocument: FileDocument {
    internal static var readableContentTypes: [UTType] { [.json] }
    internal var tiers: Items = [:]

    internal init() {}
    internal init(tiers: Items) { self.tiers = tiers }

    internal init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        tiers = try JSONDecoder().decode(Items.self, from: data)
    }

    internal func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tiers)
        return .init(regularFileWithContents: data)
    }
}
#endif

internal struct SecondaryToolbarActions: ToolbarContent {
    @Bindable var app: AppState
    internal var onShowSave: () -> Void = {}
    internal var onShowLoad: () -> Void = {}
    internal var onShowExportFormat: (ExportFormat) -> Void = { _ in }
    internal var onImportJSON: () -> Void = {}
    internal var onImportCSV: () -> Void = {}
    internal var onShowSettings: () -> Void = {}

    internal var body: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            // Sort menu - appears first for prominence
            sortMenu

            // Apply Global Sort button (only when sort is active)
            if !app.globalSortMode.isCustom {
                Button {
                    app.applyGlobalSortToCustom()
                } label: {
                    Label("Apply Global Sort", systemImage: "checkmark.circle.fill")
                }
                .accessibilityIdentifier("Toolbar_ApplySort")
                #if os(macOS)
                .help("Save current sort order as custom order")
                #endif
            }

            Menu("Actions") {
                ForEach(["S", "A", "B", "C", "D", "F"], id: \.self) { tier in
                    let isTierEmpty = (app.tiers[tier]?.isEmpty ?? true)
                    Button("Clear \(tier) Tier") { app.clearTier(tier) }
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
            Button("Create New Tier List...") { app.presentTierListCreator() }
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

    private var sortMenu: some View {
        Menu {
            // Current sort mode indicator
            Section {
                Label(
                    "Current: \(app.globalSortMode.displayName)",
                    systemImage: "checkmark.circle"
                )
            }

            Divider()

            // Manual order
            Button {
                app.setGlobalSortMode(.custom)
            } label: {
                Label(
                    "Manual Order",
                    systemImage: app.globalSortMode.isCustom ? "checkmark" : ""
                )
            }

            // Alphabetical
            Button {
                app.setGlobalSortMode(.alphabetical(ascending: true))
            } label: {
                let isSelected = {
                    if case .alphabetical(let asc) = app.globalSortMode, asc { return true }
                    return false
                }()
                Label("A → Z", systemImage: isSelected ? "checkmark" : "")
            }

            Button {
                app.setGlobalSortMode(.alphabetical(ascending: false))
            } label: {
                let isSelected = {
                    if case .alphabetical(let asc) = app.globalSortMode, !asc { return true }
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
                                    if case .byAttribute(let k, let asc, _) = app.globalSortMode,
                                       k == key, asc { return true }
                                    return false
                                }()
                                Label("\(key.capitalized) ↑", systemImage: isSelected ? "checkmark" : "")
                            }

                            Button {
                                app.setGlobalSortMode(.byAttribute(key: key, ascending: false, type: type))
                            } label: {
                                let isSelected = {
                                    if case .byAttribute(let k, let asc, _) = app.globalSortMode,
                                       k == key, !asc { return true }
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
        #if os(macOS)
        .help("Sort items by different criteria")
        #endif
    }
}

#if os(iOS)
internal struct BottomToolbarSheets: ToolbarContent {
    @Bindable var app: AppState
    @Binding var exportText: String
    @Binding var showingSettings: Bool
    @Binding var showingExportFormatSheet: Bool
    @Binding var selectedExportFormat: ExportFormat
    @Binding var exportingJSON: Bool
    @Binding var importingJSON: Bool
    @Binding var jsonDoc: TiersDocument
    @Binding var showingImportSheet: Bool
    @Binding var showingSaveDialog: Bool
    @Binding var showingLoadDialog: Bool
    @Binding var saveFileName: String

    internal var body: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            EmptyView()
                .sheet(isPresented: $showingSettings) {
                    SettingsView(app: app)
                }
                .sheet(isPresented: $showingExportFormatSheet) {
                    ExportFormatSheetView(
                        coordinator: app,
                        exportFormat: selectedExportFormat,
                        isPresented: $showingExportFormatSheet
                    )
                }
                .fileExporter(
                    isPresented: $exportingJSON,
                    document: jsonDoc,
                    contentType: .json,
                    defaultFilename: "tiers.json"
                ) { result in
                    switch result {
                    case let .failure(error):
                        app.showToast(
                            type: .error,
                            title: "JSON Export Failed",
                            message: error.localizedDescription
                        )
                    case .success:
                        app.showToast(
                            type: .success,
                            title: "JSON Export Complete",
                            message: "File saved successfully"
                        )
                    }
                }
                .fileImporter(
                    isPresented: $importingJSON,
                    allowedContentTypes: [.json]
                ) { result in
                    if case .success(let url) = result {
                        Task {
                            do {
                                try await app.importFromJSON(url: url)
                            } catch {
                                app.showToast(
                                    type: .error,
                                    title: "Import Failed",
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingImportSheet,
                    allowedContentTypes: [.commaSeparatedText, .text]
                ) { result in
                    if case .success(let url) = result {
                        Task {
                            do {
                                try await app.importFromCSV(url: url)
                            } catch {
                                app.showToast(
                                    type: .error,
                                    title: "Import Failed",
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }
                }
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        guard !saveFileName.isEmpty else { return }
                        do {
                            try app.saveToFile(named: saveFileName)
                            app.showToast(
                                type: .success,
                                title: "Save Complete",
                                message: "Saved \(saveFileName).json"
                            )
                        } catch {
                            app.showToast(
                                type: .error,
                                title: "Save Failed",
                                message: error.localizedDescription
                            )
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) { }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Select a tier list file to load.")
                }
        }
    }
}
#else
internal struct MacAndTVToolbarSheets: ToolbarContent {
    @Bindable var app: AppState
    @Binding var showingSaveDialog: Bool
    @Binding var showingLoadDialog: Bool
    @Binding var saveFileName: String
    @Binding var showingSettings: Bool

    internal var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            EmptyView()
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        guard !saveFileName.isEmpty else { return }
                        do {
                            try app.saveToFile(named: saveFileName)
                            app.showToast(
                                type: .success,
                                title: "Save Complete",
                                message: "Saved \(saveFileName).json"
                            )
                        } catch {
                            app.showToast(
                                type: .error,
                                title: "Save Failed",
                                message: error.localizedDescription
                            )
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) { }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Select a tier list file to load.")
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(app: app)
                }
        }
    }
}
#endif

#if os(iOS)
@MainActor
extension AppState: ToolbarExportCoordinating {}
#endif
