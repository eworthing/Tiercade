#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import TiercadeCore

@MainActor
protocol ToolbarExportCoordinating: ObservableObject {
    var isLoading: Bool { get }
    func exportToFormat(_ format: ExportFormat) async -> (Data, String)?
    func showToast(type: ToastType, title: String, message: String?)
}

struct ExportFormatSheetView<Coordinator: ToolbarExportCoordinating>: View {
    @ObservedObject var coordinator: Coordinator
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
                informationSection
                contentSection
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
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

                Button("Share") { Task { await shareExport() } }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(isExporting)
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

        if let (data, filename) = await coordinator.exportToFormat(exportFormat) {
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

        if let (data, filename) = await coordinator.exportToFormat(exportFormat) {
            await MainActor.run {
                let tempURL = FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(filename)
                do {
                    try data.write(to: tempURL)
                    shareItems = [tempURL]
                    showingShareSheet = true
                } catch {
                    coordinator.showToast(
                        type: .error,
                        title: "Export Failed",
                        message: "Could not prepare file: \(error.localizedDescription)"
                    )
                }
                isPresented = false
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
