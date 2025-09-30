import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toolbar and supporting components

#if os(iOS)
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
        }
    }

    private var exportImportMenu: some View {
        Menu("Export & Import") {
            Menu("Export As...") {
                Button("Text Format") { onShowExportFormat(.text) }
                Button("JSON Format") { onShowExportFormat(.json) }
                Button("Markdown Format") { onShowExportFormat(.markdown) }
                Button("CSV Format") { onShowExportFormat(.csv) }
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
                    SettingsView()
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
                        Task { await app.importFromJSON(url: url) }
                    }
                }
                .fileImporter(
                    isPresented: $showingImportSheet,
                    allowedContentTypes: [.commaSeparatedText, .text]
                ) { result in
                    if case .success(let url) = result {
                        Task { await app.importFromCSV(url: url) }
                    }
                }
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        guard !saveFileName.isEmpty else { return }
                        _ = app.saveToFile(named: saveFileName)
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
                        if !saveFileName.isEmpty {
                            try? app.saveToFile(named: saveFileName)
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
                    SettingsView()
                }
        }
    }
}
#endif

#if os(iOS)
@MainActor
extension AppState: ToolbarExportCoordinating {}
#endif
