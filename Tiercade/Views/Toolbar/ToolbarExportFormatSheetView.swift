#if !os(tvOS)
import Observation
import SwiftUI
import TiercadeCore
import UniformTypeIdentifiers

@MainActor
protocol ToolbarExportCoordinating: AnyObject, Observable {
    var isLoading: Bool { get }
    func exportToFormat(_ format: ExportFormat) async throws(ExportError) -> (Data, String)
    func showToast(type: ToastType, title: String, message: String?)
}

struct ExportFormatSheetView<Coordinator: ToolbarExportCoordinating>: View {
    @Bindable var coordinator: Coordinator
    let exportFormat: ExportFormat
    @Binding var isPresented: Bool
    @State private var isExporting = false
    @State private var exportedData: Data?
    @State private var exportFileName: String = ""
    @State private var showingFileExporter = false
    @State private var shareFileURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                informationSection
                contentSection
                Spacer()
            }
            .padding(Metrics.grid * 2)
            .navigationTitle("Export Tier List")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresented = false }
                    }
                }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: ExportDocument(
                data: exportedData ?? Data(),
                filename: exportFileName,
            ),
            contentType: contentType,
            defaultFilename: exportFileName,
        ) { result in
            switch result {
            case .success:
                coordinator.showToast(
                    type: .success,
                    title: "Export Complete",
                    message: "File saved successfully",
                )
            case let .failure(error):
                coordinator.showToast(
                    type: .error,
                    title: "Export Failed",
                    message: error.localizedDescription,
                )
            }
            isPresented = false
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if coordinator.isLoading {
            ProgressView("Preparing export...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Button("Export to Files") { Task { await exportToFiles() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isExporting)

                if let shareURL = shareFileURL {
                    ShareLink(
                        item: shareURL,
                        subject: Text("Tier List Export"),
                        message: Text("Sharing tier list in \(exportFormat.displayName) format"),
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle())
                } else {
                    Button("Share") { Task { await prepareShareFile() } }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(isExporting)
                }
            }
            .padding(Metrics.grid)
        }
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export Format")
                .font(.headline)
            Text(formatDescription)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(Metrics.grid)
    }

    private var formatDescription: String {
        switch exportFormat {
        case .text:
            "Plain text format with tiers and items listed in readable format"
        case .json:
            "JSON format with complete data structure, perfect for importing back later"
        case .markdown:
            "Markdown format with formatted tables and headers, great for documentation"
        case .csv:
            "CSV format suitable for spreadsheets and data analysis"
        case .png:
            "High-resolution PNG image export"
        case .pdf:
            "PDF render with vector text and layout"
        }
    }

    private var contentType: UTType {
        switch exportFormat {
        case .text:
            .plainText
        case .json:
            .json
        case .markdown:
            .plainText
        case .csv:
            .commaSeparatedText
        case .png:
            .png
        case .pdf:
            .pdf
        }
    }

    private func exportToFiles() async {
        guard !isExporting else {
            return
        }
        isExporting = true
        defer { isExporting = false }

        do {
            let (data, filename) = try await coordinator.exportToFormat(exportFormat)
            await MainActor.run {
                exportedData = data
                exportFileName = filename
                showingFileExporter = true
            }
        } catch {
            await MainActor.run {
                coordinator.showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    private func prepareShareFile() async {
        guard !isExporting else {
            return
        }
        isExporting = true
        defer { isExporting = false }

        do {
            let (data, filename) = try await coordinator.exportToFormat(exportFormat)
            await MainActor.run {
                let tempURL = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    shareFileURL = tempURL
                } catch {
                    coordinator.showToast(
                        type: .error,
                        title: "Export Failed",
                        message: "Could not prepare file: \(error.localizedDescription)",
                    )
                }
            }
        } catch {
            await MainActor.run {
                coordinator.showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            }
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

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
