import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Toolbar and small toolbar pieces

#if os(iOS)
// JSON FileDocument for saving/loading tiers in toolbar-related flows
struct TiersDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var tiers: Items = [:]
    init() {}
    init(tiers: Items) { self.tiers = tiers }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.tiers = try JSONDecoder().decode(Items.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tiers)
        return .init(regularFileWithContents: data)
    }
}
#endif

struct ToolbarView: ToolbarContent {
    @ObservedObject var app: AppState
    @State private var exportText: String = ""
    @State private var showingSaveDialog = false
    @State private var showingLoadDialog = false
    @State private var saveFileName = ""
    @State private var selectedLoadFile = ""
    @State private var showingExportFormatSheet = false
    @State private var showingImportSheet = false
    @State private var selectedExportFormat = ExportFormat.text
    #if os(iOS)
    @State private var showingShare = false
    @State private var exportingJSON = false
    @State private var jsonDoc = TiersDocument()
    #endif
    @State private var importingJSON = false
    @State private var showingSettings = false
    var body: some ToolbarContent {
        PrimaryToolbarActions(app: app)
        SecondaryToolbarActions(app: app,
                                onShowSave: {
                                    saveFileName = app.currentFileName ?? "MyTierList"
                                    showingSaveDialog = true
                                },
                                onShowLoad: {
                                    showingLoadDialog = true
                                },
                                onShowExportFormat: { fmt in
                                    selectedExportFormat = fmt
                                    showingExportFormatSheet = true
                                },
                                onImportJSON: {
                                    importingJSON = true
                                },
                                onImportCSV: {
                                    showingImportSheet = true
                                },
                                onShowSettings: {
                                    showingSettings = true
                                })
        #if os(iOS)
        BottomToolbarSheets(app: app,
                           exportText: $exportText,
                           showingShare: $showingShare,
                           showingSettings: $showingSettings,
                           showingExportFormatSheet: $showingExportFormatSheet,
                           exportingJSON: $exportingJSON,
                           importingJSON: $importingJSON,
                           jsonDoc: $jsonDoc,
                           showingImportSheet: $showingImportSheet,
                           showingSaveDialog: $showingSaveDialog,
                           showingLoadDialog: $showingLoadDialog,
                           saveFileName: $saveFileName)
        #else
        MacAndTVToolbarSheets(app: app, showingSaveDialog: $showingSaveDialog, showingLoadDialog: $showingLoadDialog, saveFileName: $saveFileName, showingSettings: $showingSettings)
        #endif
    }
}

struct PrimaryToolbarActions: ToolbarContent {
    @ObservedObject var app: AppState
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { app.undo() }) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!app.canUndo)
                .buttonStyle(GhostButtonStyle())
                #if !os(tvOS)
                .keyboardShortcut("z", modifiers: [.command])
                #endif
            Button(action: { app.redo() }) { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!app.canRedo)
                .buttonStyle(GhostButtonStyle())
                #if !os(tvOS)
                .keyboardShortcut("Z", modifiers: [.command, .shift])
                #endif
        }
    }
}

struct SecondaryToolbarActions: ToolbarContent {
    @ObservedObject var app: AppState
    var onShowSave: () -> Void = {}
    var onShowLoad: () -> Void = {}
    var onShowExportFormat: (ExportFormat) -> Void = { _ in }
    var onImportJSON: () -> Void = {}
    var onImportCSV: () -> Void = {}
    var onShowSettings: () -> Void = {}

    var body: some ToolbarContent {
        // .secondaryAction is unavailable on tvOS; fall back to .automatic there
        let placement: ToolbarItemPlacement = {
            #if os(tvOS)
            return .automatic
            #else
            return .secondaryAction
            #endif
        }()
        ToolbarItemGroup(placement: placement) {
            Menu("Actions") {
                Button("Clear S Tier") { app.clearTier("S") }
                Button("Clear A Tier") { app.clearTier("A") }
                Button("Clear B Tier") { app.clearTier("B") }
                Button("Clear C Tier") { app.clearTier("C") }
                Button("Clear D Tier") { app.clearTier("D") }
                Button("Clear F Tier") { app.clearTier("F") }
                Divider()
                Button("Randomize") { app.randomize() }
                Button("Reset All", role: .destructive) { app.reset() }
                Divider()
                Menu("File Operations") {
                    Button("Save Locally") { _ = app.save() }
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
                Button("Head-to-Head") { app.startH2H() }
                #if !os(tvOS)
                    .keyboardShortcut("h", modifiers: [.command])
                #endif
                Button("Analysis") { app.toggleAnalysis() }
                #if !os(tvOS)
                    .keyboardShortcut("a", modifiers: [.command])
                #endif
                Button("Settings") { onShowSettings() }
            }
        }
    }
}

#if os(iOS)
struct BottomToolbarSheets: ToolbarContent {
    @ObservedObject var app: AppState
    @Binding var exportText: String
    @Binding var showingShare: Bool
    @Binding var showingSettings: Bool
    @Binding var showingExportFormatSheet: Bool
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
                .sheet(isPresented: $showingShare) { ShareSheet(activityItems: [exportText]) }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .sheet(isPresented: $showingExportFormatSheet) { ExportFormatSheetView(app: app, exportFormat: .text, isPresented: $showingExportFormatSheet) }
                .fileExporter(isPresented: $exportingJSON, document: jsonDoc, contentType: .json, defaultFilename: "tiers.json") { result in
                    if case .failure(let err) = result { app.showToast(type: .error, title: "JSON Export Failed", message: err.localizedDescription) }
                    else { app.showToast(type: .success, title: "JSON Export Complete", message: "File saved successfully") }
                }
                .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
                    if case .success(let url) = result { Task { await app.importFromJSON(url: url) } }
                }
                .fileImporter(isPresented: $showingImportSheet, allowedContentTypes: [.commaSeparatedText, .text]) { result in
                    if case .success(let url) = result { Task { await app.importFromCSV(url: url) } }
                }
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") { if !saveFileName.isEmpty { _ = app.saveToFile(named: saveFileName) } }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Enter a name for your tier list file.") }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) { if app.loadFromFile(named: fileName) { } }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Select a tier list file to load.") }
        }
    }
}
#else
struct MacAndTVToolbarSheets: ToolbarContent {
    @ObservedObject var app: AppState
    @Binding var showingSaveDialog: Bool
    @Binding var showingLoadDialog: Bool
    @Binding var saveFileName: String
    @Binding var showingSettings: Bool
    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            EmptyView()
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") { if !saveFileName.isEmpty { _ = app.saveToFile(named: saveFileName) } }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Enter a name for your tier list file.") }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) { if app.loadFromFile(named: fileName) { } }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Select a tier list file to load.") }
                .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }
}
#endif

#if os(iOS)
// Export format selection sheet for iOS (kept here because it ties to toolbar state)
struct ExportFormatSheetView: View {
    @ObservedObject var app: AppState
    let exportFormat: ExportFormat
    @Binding var isPresented: Bool
    @State private var isExporting = false
    @State private var exportedData: Data?
    @State private var exportFileName: String = ""
    @State private var showingFileExporter = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export Format")
                        .font(.headline)
                    Text(formatDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(Metrics.grid)

                if app.isLoading {
                    ProgressView("Preparing export...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Button("Export to Files") {
                            Task {
                                await exportToFiles()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isExporting)

                        Button("Share") {
                            Task {
                                await shareExport()
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(isExporting)
                    }
                    .padding(Metrics.grid)
                }

                Spacer()
            }
            .padding(Metrics.grid * 2)
            .navigationTitle("Export Tier List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: ExportDocument(data: exportedData ?? Data(), filename: exportFileName),
            contentType: contentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(_):
                app.showToast(type: .success, title: "Export Complete", message: "File saved successfully")
            case .failure(let error):
                app.showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            }
            isPresented = false
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private var formatDescription: String {
        switch exportFormat {
        case .text:
            return "Plain text format with tiers and items listed in readable format"
        case .json:
            return "JSON format with complete data structure, perfect for importing back later"
        case .markdown:
            return "Markdown format with formatted tables and headers, great for documentation"
        case .csv:
            return "CSV format suitable for spreadsheets and data analysis"
        }
    }

    private var contentType: UTType {
        switch exportFormat {
        case .text:
            return .plainText
        case .json:
            return .json
        case .markdown:
            return .plainText
        case .csv:
            return .commaSeparatedText
        }
    }

    private func exportToFiles() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        if let (data, filename) = await app.exportToFormat(exportFormat) {
            await MainActor.run {
                exportedData = data
                exportFileName = filename
                showingFileExporter = true
            }
        }
    }

    private func shareExport() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        if let (data, filename) = await app.exportToFormat(exportFormat) {
            await MainActor.run {
                // Create temporary file for sharing
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    shareItems = [tempURL]
                    showingShareSheet = true
                } catch {
                    app.showToast(type: .error, title: "Export Failed", message: "Could not prepare file: \(error.localizedDescription)")
                }
                isPresented = false
            }
        }
    }
}

// Document wrapper for file export (kept with toolbar file logic)
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data
    let filename: String

    init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.filename = "export"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// UIKit share sheet wrapper for iOS/iPadOS
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
