import SwiftUI
#if os(iOS) || targetEnvironment(macCatalyst)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toolbar and supporting components

struct ToolbarView: ToolbarContent {
    @Bindable var app: AppState
    @Environment(\.editMode) private var editMode
    @State private var exportText: String = ""
    @State private var showingSettings = false
    @State private var showingExportFormatSheet = false
    @State private var selectedExportFormat: ExportFormat = .text
    @State private var exportingJSON = false
    @State private var importingJSON = false
    #if os(iOS) || targetEnvironment(macCatalyst)
    @State private var jsonDoc = TiersDocument()
    #endif
    @State private var showingImportSheet = false
    @State private var showingSaveDialog = false
    @State private var showingLoadDialog = false
    @State private var saveFileName = ""

    var body: some ToolbarContent {
        #if os(iOS) || targetEnvironment(macCatalyst)
#if targetEnvironment(macCatalyst)
        ToolbarItem(placement: .principal) {
            TierListQuickMenu(app: app)
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 360)
        }
#else
        ToolbarItemGroup(placement: .topBarLeading) {
            TierListQuickMenu(app: app)
                .frame(minWidth: 200)
        }
        #endif

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                app.presentTierListCreator()
            } label: {
                Label("New Tier List…", systemImage: "square.and.pencil")
            }
            .accessibilityIdentifier("Toolbar_NewTierList")
#if targetEnvironment(macCatalyst)
            .help("Create a new tier list (⇧⌘N)")
#endif

            Button {
                app.toggleAnalysis()
            } label: {
                Image(systemName: app.showingAnalysis ? "chart.bar.fill" : "chart.bar")
                    .accessibilityLabel(app.showingAnalysis ? "Close Analysis" : "Open Analysis")
            }
            .disabled(!app.canShowAnalysis && !app.showingAnalysis)
            .accessibilityIdentifier("Toolbar_Analysis")
#if targetEnvironment(macCatalyst)
            .help(app.showingAnalysis ? "Close analysis (⌘A)" : "Open analysis (⌘A)")
#endif

            Button {
                app.toggleThemePicker()
            } label: {
                Image(systemName: "paintpalette")
                    .accessibilityLabel("Themes")
            }
            .accessibilityIdentifier("Toolbar_Themes")
#if targetEnvironment(macCatalyst)
            .help("Browse themes (⌘T)")
#endif

            if AppleIntelligenceService.isSupportedOnCurrentPlatform {
                Button {
                    app.toggleAIChat()
                } label: {
                    Label("Apple Intelligence", systemImage: "sparkles")
                }
                .accessibilityIdentifier("Toolbar_AIChat")
#if targetEnvironment(macCatalyst)
                .help("Chat with Apple Intelligence")
#endif
            }

            Button {
                app.startH2H()
            } label: {
                Image(systemName: "rectangle.grid.2x2")
                    .accessibilityLabel("Head-to-Head")
            }
            .disabled(!app.canStartHeadToHead)
            .accessibilityIdentifier("Toolbar_H2H")
#if targetEnvironment(macCatalyst)
            .help("Start head-to-head (⌘H)")
#endif

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
                    multiSelectActive ? "Done" : "Multi-Select",
                    systemImage: multiSelectActive ? "checkmark.rectangle.stack.fill" : "rectangle.stack.badge.plus"
                )
                .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderedProminent)
            .tint(multiSelectActive ? Color.accentColor : Color.secondary.opacity(0.35))
            .accessibilityIdentifier("Toolbar_MultiSelect")
            .accessibilityLabel(multiSelectActive ? "Finish Multi-Select" : "Start Multi-Select")
            .accessibilityValue(multiSelectActive ? "\(app.selection.count) items selected" : "")
        }

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

        SecondaryToolbarActions(
            app: app,
            onShowSave: { showingSaveDialog = true },
            onShowLoad: { showingLoadDialog = true },
            onShowExportFormat: handleExportFormatSelection,
            onImportJSON: { importingJSON = true },
            onImportCSV: { showingImportSheet = true },
            onShowSettings: { showingSettings = true }
        )

        #if os(iOS) || targetEnvironment(macCatalyst)
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

    private func handleExportFormatSelection(_ format: ExportFormat) {
        selectedExportFormat = format
        #if os(iOS) || targetEnvironment(macCatalyst)
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

#if os(iOS) || targetEnvironment(macCatalyst)
struct TiersDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var tiers: Items = [:]

    init() {}
    init(tiers: Items) { self.tiers = tiers }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        tiers = try JSONDecoder().decode(Items.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tiers)
        return .init(regularFileWithContents: data)
    }
}
#endif

struct SecondaryToolbarActions: ToolbarContent {
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
                Button("Head-to-Head") { app.startH2H() }
                    .disabled(!app.canStartHeadToHead)
                    #if !os(tvOS)
                    .keyboardShortcut("h", modifiers: [.command])
                #endif
                Button("Analysis") { app.toggleAnalysis() }
                    .disabled(!app.showingAnalysis && !app.canShowAnalysis)
                    #if !os(tvOS)
                    .keyboardShortcut("a", modifiers: [.command])
                #endif
                Divider()
                Button("Tier Themes...") { app.toggleThemePicker() }
                    #if !os(tvOS)
                    .keyboardShortcut("t", modifiers: [.command])
                #endif
                Button("New Tier List...") { app.presentTierListCreator() }
                    #if !os(tvOS)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                #endif
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
            #if os(iOS) || targetEnvironment(macCatalyst)
            Menu("Import From...") {
                Button("JSON File") { onImportJSON() }
                Button("CSV File") { onImportCSV() }
            }
            #endif
        }
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
struct BottomToolbarSheets: ToolbarContent {
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

    var body: some ToolbarContent {
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
struct MacAndTVToolbarSheets: ToolbarContent {
    @Bindable var app: AppState
    @Binding var showingSaveDialog: Bool
    @Binding var showingLoadDialog: Bool
    @Binding var saveFileName: String
    @Binding var showingSettings: Bool

    var body: some ToolbarContent {
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

#if os(iOS) || targetEnvironment(macCatalyst)
@MainActor
extension AppState: ToolbarExportCoordinating {}
#endif
