#if !os(tvOS)
import SwiftUI
import UniformTypeIdentifiers
import Observation
import TiercadeCore

@MainActor
internal protocol ToolbarExportCoordinating: AnyObject, Observable {
    var isLoading: Bool { get }
    func exportToFormat(_ format: ExportFormat) async throws(ExportError) -> (Data, String)
    func showToast(type: ToastType, title: String, message: String?)
}

internal struct ExportFormatSheetView<Coordinator: ToolbarExportCoordinating>: View {
    @Bindable var coordinator: Coordinator
    internal let exportFormat: ExportFormat
    @Binding var isPresented: Bool
    @State private var isExporting = false
    @State private var exportedData: Data?
    @State private var exportFileName: String = ""
    @State private var showingFileExporter = false
    @State private var shareFileURL: URL?

    internal var body: some View {
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
                filename: exportFileName
            ),
            contentType: contentType,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success:
                coordinator.showToast(
                    type: .success,
                    title: "Export Complete",
                    message: "File saved successfully"
                )
            case .failure(let error):
                coordinator.showToast(
                    type: .error,
                    title: "Export Failed",
                    message: error.localizedDescription
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
                        message: Text("Sharing tier list in \(exportFormat.displayName) format")
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
            return "Plain text format with tiers and items listed in readable format"
        case .json:
            return "JSON format with complete data structure, perfect for importing back later"
        case .markdown:
            return "Markdown format with formatted tables and headers, great for documentation"
        case .csv:
            return "CSV format suitable for spreadsheets and data analysis"
        case .png:
            return "High-resolution PNG image export"
        case .pdf:
            return "PDF render with vector text and layout"
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
        case .png:
            return .png
        case .pdf:
            return .pdf
        }
    }

    private func exportToFiles() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let (data, filename) = try await coordinator.exportToFormat(exportFormat)
            await MainActor.run {
                exportedData = data
                exportFileName = filename
                showingFileExporter = true
            }
        } catch let error as ExportError {
            await MainActor.run {
                coordinator.showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    private func prepareShareFile() async {
        guard !isExporting else { return }
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
                        message: "Could not prepare file: \(error.localizedDescription)"
                    )
                }
            }
        } catch let error as ExportError {
            await MainActor.run {
                coordinator.showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            }
        }
    }
}

internal struct ExportDocument: FileDocument {
    internal static var readableContentTypes: [UTType] { [.data] }

    internal let data: Data
    internal let filename: String

    internal init(data: Data, filename: String) {
        self.data = data
        self.filename = filename
    }

    internal init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
        self.filename = "export"
    }

    internal func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
