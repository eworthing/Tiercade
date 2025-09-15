//
//  ContentView.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct AppTier: Identifiable, Hashable { let id: String; var name: String }

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastMessage
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.title2)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let message = toast.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    .padding(.horizontal, Metrics.grid * 2)
    .padding(.vertical, Metrics.grid * 1.5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
        #if os(macOS)
        .focusable(true)
        .accessibilityAddTraits(.isModal)
        #endif
    }
}

// MARK: - Progress Indicator View

struct ProgressIndicatorView: View {
    let isLoading: Bool
    let message: String
    let progress: Double
    
    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal, Metrics.grid * 2)
                .padding(.vertical, Metrics.grid * 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Drag Target Highlight

struct DragTargetHighlight: View {
    let isTarget: Bool
    let color: Color

    var body: some View {
        if isTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )
                .shadow(color: color.opacity(0.45), radius: 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTarget)
        }
    }
}

struct ContentView: View {
    @StateObject private var app = AppState()
    @State private var showingAddItems = false
    #if os(tvOS)
    private var canStartH2HFromRemote: Bool { app.quickRankTarget == nil && !app.h2hActive }
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if (UIDevice.current.userInterfaceIdiom == .pad) {
                NavigationSplitView {
                    SidebarView(tierOrder: app.tierOrder)
                } detail: {
                    HStack(spacing: 0) {
                        TierGridView(tierOrder: app.tierOrder)
                        InspectorView()
                    }
                }
            } else {
                AdaptiveLayout {
                    SidebarView(tierOrder: app.tierOrder)
                    TierGridView(tierOrder: app.tierOrder)
                    InspectorView()
                }
            }
            #else
            AdaptiveLayout {
                SidebarView(tierOrder: app.tierOrder)
                TierGridView(tierOrder: app.tierOrder)
                InspectorView()
            }
            #endif
        }
    .environmentObject(app)
    .toolbar { ToolbarView(app: app) }
    .overlay(alignment: .bottom) { QuickRankOverlay(app: app) }
    .overlay { HeadToHeadOverlay(app: app) }
    .overlay(alignment: .top) {
        if let toast = app.currentToast {
                Button(action: { app.dismissToast() }) {
                    ToastView(toast: toast)
                        .padding(.top, Metrics.toolbarH + Metrics.grid * 2) // Account for toolbar
                        .padding(.horizontal, Metrics.grid * 2)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(toast.title)
                .accessibilityHint("Dismiss toast")
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    .overlay(alignment: .center) {
        ProgressIndicatorView(
            isLoading: app.isLoading,
            message: app.loadingMessage,
            progress: app.operationProgress
        )
    }
    .overlay(alignment: .topTrailing) { 
        PersistenceStatusView(app: app)
            .padding(.top, Metrics.toolbarH + Metrics.grid)
            .padding(.trailing, Metrics.grid * 2)
    }
    .sheet(isPresented: $app.showingAnalysis) {
        AnalysisView(app: app)
    }
    .sheet(isPresented: $showingAddItems) {
        AddItemsView(isPresented: $showingAddItems)
            .environmentObject(app)
    }
        #if os(tvOS)
        .onPlayPauseCommand(perform: {
            if canStartH2HFromRemote { app.startH2H() }
        })
        #endif
    }
}

// MARK: - Adaptive container for iPhone/iPad/tvOS
struct AdaptiveLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.scenePhase) private var scene
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > 700 || hSize == .regular
            Group {
                if isWide {
                    HStack(spacing: 0) { content() }
                } else {
                    VStack(spacing: 0) { content() }
                }
            }
            .animation(.snappy, value: isWide)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

// MARK: - Sidebar (filters/summary)
struct SidebarView: View {
    @EnvironmentObject var app: AppState
    let tierOrder: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Survivor Tier List").font(.largeTitle.bold())
                Spacer()
                Button(action: { /* stub: show add dialog */ }) {
                    Label("Add Items", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            
            // Enhanced Search Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Search & Filter").font(.headline)
                
                #if !os(tvOS)
                TextField("Search contestants...", text: $app.searchQuery)
                    .textFieldStyle(.roundedBorder)
                
                // Search processing indicator
                if app.isProcessingSearch {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Processing search...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
                #endif
                
                // Quick Filter Buttons
                HStack(spacing: 8) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        Button(filter.rawValue) {
                            app.activeFilter = filter
                        }
                        .buttonStyle(GhostButtonStyle())
                        .controlSize(.small)
                        .background(app.activeFilter == filter ? Color.accentColor.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(app.activeFilter == filter ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            
            Divider()
            
            // Stats Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics").font(.headline)
                HStack { 
                    Text("Total:"); 
                    Spacer()
                    Text("\(tierOrder.flatMap { app.tiers[$0] ?? [] }.count + (app.tiers["unranked"]?.count ?? 0))").bold() 
                }
                HStack { 
                    Text("Ranked:"); 
                    Spacer()
                    Text("\(tierOrder.flatMap { app.tiers[$0] ?? [] }.count)").bold() 
                }
                HStack { 
                    Text("Unranked:"); 
                    Spacer()
                    Text("\(app.tiers["unranked"]?.count ?? 0)").bold() 
                }
                if !app.searchQuery.isEmpty {
                    HStack { 
                        Text("Filtered:"); 
                        Spacer()
                        Text("\(app.allContestants().count)").bold().foregroundColor(.accentColor)
                    }
                }
            }
            
            Divider()
            
            // Tier List
            ScrollView { 
                VStack(alignment: .leading, spacing: 4) { 
                    ForEach(tierOrder, id: \.self) { t in 
                        HStack {
                            Label(t, systemImage: "flag")
                            Spacer()
                            Text("\(app.tiers[t]?.count ?? 0)")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } 
                } 
            }
            Divider()
            ItemTrayView()
        }
        .padding(Metrics.grid * 2)
    .frame(minWidth: 280)
    .panel()
    }
}

// MARK: - Persistence Status
struct PersistenceStatusView: View {
    @ObservedObject var app: AppState
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let fileName = app.currentFileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 4) {
                if app.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            if let lastSaved = app.lastSavedTime {
                Text("Last saved: \(lastSaved, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    .padding(Metrics.grid)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .opacity(app.hasUnsavedChanges || app.currentFileName != nil ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: app.hasUnsavedChanges)
        .animation(.easeInOut(duration: 0.2), value: app.currentFileName)
    }
}

// MARK: - Toolbar
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
    @State private var importingJSON = false
    @State private var jsonDoc = TiersDocument()
    #endif
    @State private var showingSettings = false
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
        ToolbarItemGroup(placement: .secondaryAction) {
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
                    Button("Save to File...") { 
                        saveFileName = app.currentFileName ?? "MyTierList"
                        showingSaveDialog = true 
                    }
                    #if !os(tvOS)
                        .keyboardShortcut("S", modifiers: [.command, .shift])
                    #endif
                    Button("Load from File...") { 
                        showingLoadDialog = true 
                    }
                    #if !os(tvOS)
                        .keyboardShortcut("O", modifiers: [.command, .shift])
                    #endif
                }
                Menu("Export & Import") {
                    Menu("Export As...") {
                        Button("Text Format") { 
                            selectedExportFormat = .text
                            showingExportFormatSheet = true 
                        }
                        Button("JSON Format") { 
                            selectedExportFormat = .json
                            showingExportFormatSheet = true 
                        }
                        Button("Markdown Format") { 
                            selectedExportFormat = .markdown
                            showingExportFormatSheet = true 
                        }
                        Button("CSV Format") { 
                            selectedExportFormat = .csv
                            showingExportFormatSheet = true 
                        }
                    }
                    #if os(iOS)
                    Menu("Import From...") {
                        Button("JSON File") { 
                            importingJSON = true 
                        }
                        Button("CSV File") { 
                            showingImportSheet = true 
                        }
                    }
                    #endif
                }
                #if os(iOS)
                // Legacy export for backwards compatibility
                Button("Export Text") {
                    exportText = app.exportText()
                    showingShare = true
                }
                #if !os(tvOS)
                .keyboardShortcut("e", modifiers: [.command])
                #endif
                #else
                Button("Export Text") {
                    exportText = app.exportText()
                    print(exportText)
                }
                #if !os(tvOS)
                .keyboardShortcut("e", modifiers: [.command])
                #endif
                #endif
                Divider()
                Button("Head-to-Head") { app.startH2H() }
                #if !os(tvOS)
                    .keyboardShortcut("h", modifiers: [.command])
                #endif
                Button("Analysis") { app.toggleAnalysis() }
                #if !os(tvOS)
                    .keyboardShortcut("a", modifiers: [.command])
                #endif
                Button("Settings") { showingSettings = true }
            }
        }
        #if os(iOS)
        // For iOS/iPadOS quick text export
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
                        exportFormat: selectedExportFormat,
                        isPresented: $showingExportFormatSheet
                    )
                }
                .fileExporter(isPresented: $exportingJSON, document: jsonDoc, contentType: .json, defaultFilename: "tiers.json") { result in
                    if case .failure(let err) = result { 
                        app.showToast(type: .error, title: "JSON Export Failed", message: err.localizedDescription)
                    } else {
                        app.showToast(type: .success, title: "JSON Export Complete", message: "File saved successfully")
                    }
                }
                .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
                    if case .success(let url) = result {
                        Task {
                            await app.importFromJSON(url: url)
                        }
                    }
                }
                .fileImporter(isPresented: $showingImportSheet, allowedContentTypes: [.commaSeparatedText, .text]) { result in
                    if case .success(let url) = result {
                        Task {
                            await app.importFromCSV(url: url)
                        }
                    }
                }
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        if !saveFileName.isEmpty {
                            if app.saveToFile(named: saveFileName) {
                                // Success feedback could be added here
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) {
                                // Success feedback could be added here
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Select a tier list file to load.")
                }
        }
        #else
        // For macOS and tvOS
        ToolbarItem(placement: .automatic) {
            EmptyView()
                .alert("Save Tier List", isPresented: $showingSaveDialog) {
                    TextField("File Name", text: $saveFileName)
                    Button("Save") {
                        if !saveFileName.isEmpty {
                            if app.saveToFile(named: saveFileName) {
                                // Success feedback could be added here
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Enter a name for your tier list file.")
                }
                .alert("Load Tier List", isPresented: $showingLoadDialog) {
                    ForEach(app.getAvailableSaveFiles(), id: \.self) { fileName in
                        Button(fileName) {
                            if app.loadFromFile(named: fileName) {
                                // Success feedback could be added here
                            }
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
        #endif
    }
}

#if os(iOS)
// Export format selection sheet for iOS
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
            return "Plain text format with tiers and contestants listed in readable format"
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

// Document wrapper for file export
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

// MARK: - Tier grid
struct TierGridView: View {
    @EnvironmentObject var app: AppState
    let tierOrder: [String]
    private var columns: [GridItem] { Array(repeating: GridItem(.adaptive(minimum: 180), spacing: 12), count: 1) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(tierOrder, id: \.self) { tier in
                    TierRowView(tier: tier)
                }
                UnrankedView()
            }
            .padding(Metrics.grid * 2)
        }
        .background(
            LinearGradient(gradient: .survivorBackground, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

struct TierRowView: View {
    @EnvironmentObject var app: AppState
    let tier: String
    #if os(tvOS)
    @FocusState private var focusedCardId: String?
    #endif
    
    var filteredCards: [TLContestant] {
        let allCards = app.tiers[tier] ?? []
        
        // Apply global filter
        switch app.activeFilter {
        case .all:
            break // Show all from this tier
        case .ranked:
            if tier == "unranked" { return [] } // Hide unranked when filter is "ranked"
        case .unranked:
            if tier != "unranked" { return [] } // Hide ranked tiers when filter is "unranked"
        }
        
        // Apply search filter
        return app.applySearchFilter(to: allCards)
    }
    
    var body: some View {
        if !filteredCards.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                HStack {
                    Text(tier)
                        .font(TypeScale.h3)
                        .foregroundColor(Palette.text)
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredCards.count)/\(app.tiers[tier]?.count ?? 0)")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    }
                }
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(filteredCards, id: \.id) { c in
                            CardView(contestant: c)
                            #if !os(tvOS)
                                .draggable(c.id)
                            #else
                                .focused($focusedCardId, equals: c.id)
                            #endif
                        }
                    }
                    .padding(.bottom, Metrics.grid * 0.5)
                }
                #if os(tvOS)
                .onAppear { focusedCardId = filteredCards.first?.id }
                #endif
            }
            .padding(Metrics.grid * 1.5)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == tier, color: Palette.tierColor(tier))
            }
            #if !os(tvOS)
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: tier) }
                app.setDragTarget(nil) // Clear drag target
                app.setDragging(nil)
                return true
            } isTargeted: { isTargeted in
                app.setDragTarget(isTargeted ? tier : nil)
            }
            #endif
        }
    }
}

struct UnrankedView: View {
    @EnvironmentObject var app: AppState
    #if os(tvOS)
    @FocusState private var focusedCardId: String?
    #endif
    
    var filteredContestants: [TLContestant] {
        let allUnranked = app.tiers["unranked"] ?? []
        
        // Apply global filter
        switch app.activeFilter {
        case .all, .unranked:
            break // Show unranked
        case .ranked:
            return [] // Hide unranked when filter is "ranked"
        }
        
        // Apply search filter
        return app.applySearchFilter(to: allUnranked)
    }
    
    var body: some View {
        if !filteredContestants.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.grid) {
                HStack { 
                    Text("Unranked")
                        .font(TypeScale.h3)
                        .foregroundColor(Palette.text)
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredContestants.count)/\(app.tiers["unranked"]?.count ?? 0)")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    } else {
                        Text("\(filteredContestants.count)")
                            .font(TypeScale.label)
                            .foregroundColor(Palette.textDim)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)]) {
                    ForEach(filteredContestants, id: \.id) { c in
                        CardView(contestant: c)
                        #if !os(tvOS)
                            .draggable(c.id)
                        #else
                            .focused($focusedCardId, equals: c.id)
                        #endif
                    }
                }
            }
        .padding(Metrics.grid * 1.5)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary))
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == "unranked", color: Palette.tierColor("F"))
            }
            #if !os(tvOS)
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: "unranked") }
                app.setDragTarget(nil) // Clear drag target
                app.setDragging(nil)
                return true
            } isTargeted: { isTargeted in
                app.setDragTarget(isTargeted ? "unranked" : nil)
            }
            #else
            .onAppear { focusedCardId = filteredContestants.first?.id }
            #endif
        }
    }
}

struct CardView: View {
    let contestant: TLContestant
    @EnvironmentObject var app: AppState
    var body: some View {
        Button(action: { app.beginQuickRank(contestant) }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .frame(minWidth: 120, idealWidth: 140, minHeight: 72, idealHeight: 88)
                    .overlay(
                        Group {
                            if let thumb = contestant.thumbUri, let url = URL(string: thumb) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                                            .overlay(Text((contestant.name ?? contestant.id).prefix(12)).font(.headline).foregroundStyle(.white))
                                    @unknown default:
                                        RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                                    }
                                }
                                .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Palette.brand)
                                    .overlay(Text((contestant.name ?? contestant.id).prefix(12)).font(.headline).foregroundStyle(.white))
                            }
                        }
                    )
                Text("S \(contestant.season ?? "?")").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(Metrics.grid)
            .card()
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(app.draggingId == contestant.id ? 0.98 : 1.0)
        .shadow(color: Color.black.opacity(app.draggingId == contestant.id ? 0.45 : 0.1), radius: app.draggingId == contestant.id ? 20 : 6, x: 0, y: app.draggingId == contestant.id ? 12 : 4)
        .contentShape(Rectangle())
        .accessibilityLabel(contestant.name ?? contestant.id)
#if os(macOS)
        .focusable(true)
        .accessibilityAddTraits(.isButton)
#endif
#if !os(tvOS)
        .onDrag {
            app.setDragging(contestant.id)
            return NSItemProvider(object: NSString(string: contestant.id))
        }
#endif
#if os(tvOS)
        .focusable(true)
        .onPlayPauseCommand {
            // Show a simple contextual menu using Quick Rank tiers as move targets
            app.beginQuickRank(contestant)
        }
        .contextMenu {
            ForEach(app.tierOrder, id: \.self) { t in
                Button("Move to \(t)") { app.move(contestant.id, to: t) }
            }
        }
#endif
    }
}

private extension Gradient {
    static var survivorBackground: Gradient { .init(colors: [Color.black.opacity(0.6), Color.blue.opacity(0.2)]) }
}

#Preview("iPhone") { ContentView() }
#Preview("iPad") { ContentView() }
#if os(tvOS)
#Preview("tvOS") { ContentView() }
#endif

// MARK: - Quick Rank overlay
struct QuickRankOverlay: View {
    @ObservedObject var app: AppState
    var body: some View {
        if let c = app.quickRankTarget {
            VStack(spacing: 12) {
                Text("Quick Rank: \(c.name ?? c.id)").font(.headline)
                HStack(spacing: 8) {
                    ForEach(app.tierOrder, id: \.self) { t in
                        Button(t) { app.commitQuickRank(to: t) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    Button("Cancel", role: .cancel) { app.cancelQuickRank() }
                        .accessibilityHint("Cancel quick rank")
                }
            }
            .padding(Metrics.grid * 1.5)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(Metrics.grid)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Make the Quick Rank overlay focusable and treated as a modal for accessibility
            #if os(macOS) || os(tvOS)
            .focusable(true)
            .accessibilityAddTraits(.isModal)
            #endif
        }
    }
}

// MARK: - JSON FileDocument
#if os(iOS)
struct TiersDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var tiers: TLTiers = [:]
    init() {}
    init(tiers: TLTiers) { self.tiers = tiers }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.tiers = try JSONDecoder().decode(TLTiers.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tiers)
        return .init(regularFileWithContents: data)
    }
}
#endif

// MARK: - Head-to-Head overlay
struct HeadToHeadOverlay: View {
    @ObservedObject var app: AppState
    var body: some View {
        if app.h2hActive {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { /* block background interaction */ }
                    .accessibilityHidden(true)
                VStack(spacing: 16) {
                    Text("Head-to-Head").font(.headline)
                    if let pair = app.h2hPair {
                        HStack(spacing: 16) {
                            H2HButton(contestant: pair.0) { app.voteH2H(winner: pair.0) }
                            Text("vs").font(.headline)
                            H2HButton(contestant: pair.1) { app.voteH2H(winner: pair.1) }
                        }
                    } else {
                        Text("No more pairs. Tap Finish.").foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Finish") { app.finishH2H() }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Cancel", role: .cancel) { app.h2hActive = false }
                            .accessibilityHint("Cancel head to head and return to the main view")
                    }
                }
                .padding(Metrics.grid)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(Metrics.grid * 2)
                .accessibilityElement(children: .contain)
                // Ensure the modal captures focus on macOS/tvOS
                #if os(macOS) || os(tvOS)
                .focusable(true)
                .accessibilityAddTraits(.isModal)
                #else
                .accessibilityAddTraits(.isModal)
                #endif
            }
            .transition(.opacity)
        }
    }
}

struct H2HButton: View {
    let contestant: TLContestant
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor)
                    .frame(minWidth: 140, idealWidth: 160, minHeight: 88, idealHeight: 100)
                    .overlay(Text((contestant.name ?? contestant.id).prefix(14)).font(.headline).foregroundStyle(.white))
                Text(contestant.season ?? "?").font(.caption)
            }
            .padding(Metrics.grid)
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(contestant.name ?? contestant.id)
        .buttonStyle(GhostButtonStyle())
    }
}


// MARK: - Analysis & Statistics Views

struct AnalysisView: View {
    @ObservedObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let analysis = app.analysisData {
                        AnalysisContentView(analysis: analysis)
                    } else if app.isLoading {
                        ProgressView("Generating analysis...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.fill")
                                .font(TypeScale.h2)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            Text("No Analysis Available")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Generate analysis to see tier distribution and insights")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Generate Analysis") {
                                Task {
                                    await app.generateAnalysis()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .controlSize(.large)
                        }
                        .padding(Metrics.grid * 2)
                    }
                }
                .padding(Metrics.grid * 2)
            }
            .navigationTitle("Tier Analysis")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await app.generateAnalysis()
                        }
                    }
                    .disabled(app.isLoading)
                }
            }
#endif
        }
    }
}

struct AnalysisContentView: View {
    let analysis: TierAnalysisData
    
    var body: some View {
        VStack(spacing: 24) {
            // Overall Statistics
            OverallStatsView(analysis: analysis)
            
            // Tier Distribution Chart
            TierDistributionChartView(distribution: analysis.tierDistribution)
            
            // Balance Score
            BalanceScoreView(score: analysis.balanceScore)
            
            // Insights
            InsightsView(insights: analysis.insights)
        }
    }
}

struct OverallStatsView: View {
    let analysis: TierAnalysisData
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Overall Statistics")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCardView(
                    title: "Total Contestants", 
                    value: "\(analysis.totalContestants)",
                    icon: "person.3.fill"
                )
                
                StatCardView(
                    title: "Most Populated",
                    value: analysis.mostPopulatedTier ?? "—",
                    icon: "arrow.up.circle.fill"
                )
                
                StatCardView(
                    title: "Unranked",
                    value: "\(analysis.unrankedCount)",
                    icon: "questionmark.circle.fill"
                )
            }
        }
    .padding(Metrics.grid * 2)
    .panel()
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Palette.text)
                .accessibilityHidden(true)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    .padding(Metrics.grid)
        .card()
    }
}

struct TierDistributionChartView: View {
    let distribution: [TierDistributionData]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Tier Distribution")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(distribution) { tier in
                    TierBarView(tierData: tier)
                }
            }
        }
    .padding(Metrics.grid * 2)
    .panel()
    }
}

struct TierBarView: View {
    let tierData: TierDistributionData
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Tier \(tierData.tier)")
                    .font(.headline)
                    .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                Text("\(tierData.count) contestants")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("(\(tierData.percentage, specifier: "%.1f")%)")
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                HStack {
                    Rectangle()
                        .fill(tierColor(for: tierData.tier))
                        .frame(width: max(geometry.size.width * (tierData.percentage / 100), 4))
                        .animation(.easeInOut(duration: 0.6), value: tierData.percentage)
                    
                    Spacer()
                }
            }
            .frame(height: 8)
    }
    .padding(.horizontal, Metrics.grid * 2)
    }
    
    private func tierColor(for tier: String) -> Color {
        switch tier {
        case "S": return .red
        case "A": return .orange
        case "B": return .yellow
        case "C": return .green
        case "D": return .blue
        case "F": return .purple
        default: return .gray
        }
    }
}

struct BalanceScoreView: View {
    let score: Double
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Balance Score")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ZStack {
                    let strokeColor: Color = {
#if canImport(UIKit)
                        return Color(UIColor.systemGray4)
#else
                        return Palette.surfHi
#endif
                    }()

                    Circle()
                        .stroke(strokeColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(scoreColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: score)
                    
                    VStack {
                        Text("\(score, specifier: "%.0f")")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor)
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(scoreDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
                .padding(Metrics.grid * 2)
    .panel()
    }
    
    private var scoreColor: Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .orange }
        else { return .red }
    }
    
    private var scoreDescription: String {
        if score >= 80 { return "Excellent balance across all tiers" }
        else if score >= 60 { return "Good distribution with room for improvement" }
        else { return "Uneven distribution - consider rebalancing" }
    }
}

struct InsightsView: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights & Recommendations")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: Metrics.grid) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(insight)
                            .font(TypeScale.body)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, Metrics.grid)
                    .padding(.vertical, Metrics.grid * 0.5)
                    .card()
                }
            }
        }
            .padding(Metrics.grid * 2)
    .panel()
    }
}
