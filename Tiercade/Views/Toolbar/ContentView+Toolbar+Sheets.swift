import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

import TiercadeCore

// MARK: - Sheet Presentations for Toolbar

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
        self.tiers = try JSONDecoder().decode(Items.self, from: data)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tiers)
        return .init(regularFileWithContents: data)
    }
}
#endif

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
                    SettingsView(app: app)
                }
                .sheet(isPresented: $showingExportFormatSheet) {
                    ExportFormatSheetView(
                        coordinator: app,
                        exportFormat: selectedExportFormat,
                        isPresented: $showingExportFormatSheet,
                    )
                }
                .fileExporter(
                    isPresented: $exportingJSON,
                    document: jsonDoc,
                    contentType: .json,
                    defaultFilename: "tiers.json",
                ) { result in
                    switch result {
                    case let .failure(error):
                        app.showToast(
                            type: .error,
                            title: "JSON Export Failed",
                            message: error.localizedDescription,
                        )
                    case .success:
                        app.showToast(
                            type: .success,
                            title: "JSON Export Complete",
                            message: "File saved successfully",
                        )
                    }
                }
                .fileImporter(
                    isPresented: $importingJSON,
                    allowedContentTypes: [.json],
                ) { result in
                    if case let .success(url) = result {
                        Task {
                            do {
                                try await app.importFromJSON(url: url)
                            } catch {
                                app.showToast(
                                    type: .error,
                                    title: "Import Failed",
                                    message: error.localizedDescription,
                                )
                            }
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingImportSheet,
                    allowedContentTypes: [.commaSeparatedText, .text],
                ) { result in
                    if case let .success(url) = result {
                        Task {
                            do {
                                try await app.importFromCSV(url: url)
                            } catch {
                                app.showToast(
                                    type: .error,
                                    title: "Import Failed",
                                    message: error.localizedDescription,
                                )
                            }
                        }
                    }
                }
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        guard !saveFileName.isEmpty else {
                            return
                        }
                        do {
                            try app.saveToFile(named: saveFileName)
                            app.showToast(
                                type: .success,
                                title: "Save Complete",
                                message: "Saved \(saveFileName).json",
                            )
                        } catch {
                            app.showToast(
                                type: .error,
                                title: "Save Failed",
                                message: error.localizedDescription,
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
                            if app.loadFromFile(named: fileName) {}
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Select a tier list file to load.")
                }
        }
    }
}
#endif

#if !os(iOS)
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
                        guard !saveFileName.isEmpty else {
                            return
                        }
                        do {
                            try app.saveToFile(named: saveFileName)
                            app.showToast(
                                type: .success,
                                title: "Save Complete",
                                message: "Saved \(saveFileName).json",
                            )
                        } catch {
                            app.showToast(
                                type: .error,
                                title: "Save Failed",
                                message: error.localizedDescription,
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
                            if app.loadFromFile(named: fileName) {}
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
