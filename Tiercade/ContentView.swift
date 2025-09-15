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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
    
    var body: some View {
        if isTarget {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTarget)
        }
    }
}

struct ContentView: View {
    @StateObject private var app = AppState()
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
                    TierGridView(tierOrder: app.tierOrder)
                }
            } else {
                AdaptiveLayout {
                    SidebarView(tierOrder: app.tierOrder)
                    TierGridView(tierOrder: app.tierOrder)
                }
            }
            #else
            AdaptiveLayout {
                SidebarView(tierOrder: app.tierOrder)
                TierGridView(tierOrder: app.tierOrder)
            }
            #endif
        }
    .environmentObject(app)
    .toolbar { ToolbarView(app: app) }
    .overlay(alignment: .bottom) { QuickRankOverlay(app: app) }
    .overlay { HeadToHeadOverlay(app: app) }
    .overlay(alignment: .top) {
        if let toast = app.currentToast {
            ToastView(toast: toast)
                .padding(.top, 80) // Account for toolbar
                .padding(.horizontal, 20)
                .onTapGesture {
                    app.dismissToast()
                }
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
            .padding(.top, 60) // Account for toolbar
            .padding(.trailing, 20)
    }
    .sheet(isPresented: $app.showingAnalysis) {
        AnalysisView(app: app)
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
            Text("Survivor Tier List").font(.largeTitle.bold())
            
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
                        .buttonStyle(.bordered)
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
        }
        .padding()
        .frame(minWidth: 280)
        .background(.thinMaterial)
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
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
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
        .padding(8)
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
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { app.undo() }) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!app.canUndo)
            #if !os(tvOS)
                .keyboardShortcut("z", modifiers: [.command])
            #endif
            Button(action: { app.redo() }) { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!app.canRedo)
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
            }
        }
        #if os(iOS)
        // For iOS/iPadOS quick text export
        ToolbarItem(placement: .bottomBar) {
            EmptyView()
                .sheet(isPresented: $showingShare) {
                    ShareSheet(activityItems: [exportText])
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
                .padding()
                
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
                        .buttonStyle(.borderedProminent)
                        .disabled(isExporting)
                        
                        Button("Share") {
                            Task {
                                await shareExport()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isExporting)
                    }
                    .padding()
                }
                
                Spacer()
            }
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
            .padding()
        }
        .background(
            LinearGradient(gradient: .survivorBackground, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

struct TierRowView: View {
    @EnvironmentObject var app: AppState
    let tier: String
    
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tier).font(.title2.bold())
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredCards.count)/\(app.tiers[tier]?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(filteredCards, id: \.id) { c in
                            CardView(contestant: c)
                            #if !os(tvOS)
                                .draggable(c.id)
                            #endif
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == tier)
            }
            #if !os(tvOS)
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: tier) }
                app.setDragTarget(nil) // Clear drag target
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
            VStack(alignment: .leading, spacing: 8) {
                HStack { 
                    Text("Unranked").font(.title2.bold())
                    Spacer()
                    if !app.searchQuery.isEmpty || app.activeFilter != .all {
                        Text("\(filteredContestants.count)/\(app.tiers["unranked"]?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(filteredContestants.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary))
            .overlay {
                DragTargetHighlight(isTarget: app.dragTargetTier == "unranked")
            }
            #if !os(tvOS)
            .dropDestination(for: String.self) { items, _ in
                if let id = items.first { app.move(id, to: "unranked") }
                app.setDragTarget(nil) // Clear drag target
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
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor)
                .frame(width: 140, height: 88)
                .overlay(Text((contestant.name ?? contestant.id).prefix(12)).font(.headline).foregroundStyle(.white))
            Text("S \(contestant.season ?? "?")").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        .contentShape(Rectangle())
        .onTapGesture { app.beginQuickRank(contestant) }
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
                            .buttonStyle(.borderedProminent)
                    }
                    Button("Cancel", role: .cancel) { app.cancelQuickRank() }
                }
            }
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            .buttonStyle(.borderedProminent)
                        Button("Cancel", role: .cancel) { app.h2hActive = false }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
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
                    .frame(width: 160, height: 100)
                    .overlay(Text((contestant.name ?? contestant.id).prefix(14)).font(.headline).foregroundStyle(.white))
                Text(contestant.season ?? "?").font(.caption)
            }
            .padding(8)
        }
        .buttonStyle(.bordered)
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
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
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
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Tier Analysis")
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
        .padding(.horizontal)
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
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 8)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 20)
                        
                        Text(insight)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
