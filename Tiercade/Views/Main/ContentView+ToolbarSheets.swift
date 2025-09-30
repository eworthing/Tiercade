// Legacy toolbar sheets moved to `Tiercade/Views/Toolbar/ContentView+Toolbar.swift`.
// Wrapped in `#if false` to avoid duplicate symbol definitions during the transition.
#if false
import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

// MARK: - Toolbar Sheets

#if os(iOS)
struct LoadSheetView: View {
    @Bindable var app: AppState
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
                .sheet(isPresented: $showingShare) {
                    ShareSheet(activityItems: [exportText])
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showingExportFormatSheet) {
                    ExportFormatSheetView(
                        app: app,
                        exportFormat: .text,
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
                .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
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
                .alert(
                    "Save Tier List",
                    isPresented: $showingSaveDialog
                ) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        guard !saveFileName.isEmpty else { return }
                        _ = app.saveToFile(named: saveFileName)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert(
                    "Load Tier List",
                    isPresented: $showingLoadDialog
                ) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) { }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Select a tier list file to load.")
                }
        }
    }
}
#else
struct SaveSheetView: View {
    @Bindable var app: AppState
    @Binding var showingSaveDialog: Bool
    @Binding var showingLoadDialog: Bool
    @Binding var saveFileName: String
    @Binding var showingSettings: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            EmptyView()
                .alert(
                    "Save Tier List",
                    isPresented: $showingSaveDialog
                ) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        if !saveFileName.isEmpty {
                            _ = app.saveToFile(named: saveFileName)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert(
                    "Load Tier List",
                    isPresented: $showingLoadDialog
                ) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) { }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
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
#endif // legacy toolbar sheets disabled

#if os(iOS)
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
        NavigationStack {
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
                            Task { await exportToFiles() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isExporting)

                        Button("Share") {
                            Task { await shareExport() }
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
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: ExportDocument(
                data: exportedData ?? Data(),
                filename: exportFileName
            ),
            contentType: contentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                app.showToast(
                    type: .success,
                    title: "Export Complete",
                    message: "File saved successfully"
                )
            case .failure(let error):
                app.showToast(
                    type: .error,
                    title: "Export Failed",
                    message: error.localizedDescription
                )
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

        do {
            let (data, filename) = try await app.exportToFormat(exportFormat)
            await MainActor.run {
                exportedData = data
                exportFileName = filename
                showingFileExporter = true
            }
        } catch let error as ExportError {
            await MainActor.run {
                switch error {
                case .formatNotSupported(let format):
                    app.showErrorToast("Export Failed", message: "Format '\(format.displayName)' not supported")
                case .dataEncodingFailed(let reason):
                    app.showErrorToast("Export Failed", message: "Encoding failed: \(reason)")
                case .insufficientData:
                    app.showErrorToast("Export Failed", message: "No data to export")
                case .renderingFailed(let reason):
                    app.showErrorToast("Export Failed", message: "Rendering failed: \(reason)")
                case .invalidConfiguration:
                    app.showErrorToast("Export Failed", message: "Invalid configuration")
                }
            }
        }
    }

    private func shareExport() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let (data, filename) = try await app.exportToFormat(exportFormat)
            await writeAndShareFile(data: data, filename: filename)
        } catch let error as ExportError {
            await handleExportError(error)
        }
    }

    private func writeAndShareFile(data: Data, filename: String) async {
        await MainActor.run {
            let tempURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent(filename)
            do {
                try data.write(to: tempURL)
                shareItems = [tempURL]
                showingShareSheet = true
            } catch {
                app.showToast(
                    type: .error,
                    title: "Export Failed",
                    message: "Could not prepare file: \(error.localizedDescription)"
                )
            }
            isPresented = false
        }
    }

    private func handleExportError(_ error: ExportError) async {
        await MainActor.run {
            let message = getErrorMessage(for: error)
            app.showErrorToast("Export Failed", message: message)
            isPresented = false
        }
    }

    private func getErrorMessage(for error: ExportError) -> String {
        switch error {
        case .formatNotSupported(let format):
            return "Format '\(format.displayName)' not supported"
        case .dataEncodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .insufficientData:
            return "No data to export"
        case .renderingFailed(let reason):
            return "Rendering failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid configuration"
        }
    }
}

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
        FileWrapper(regularFileWithContents: data)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
