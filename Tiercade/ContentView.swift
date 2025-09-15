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
                #if os(iOS)
                Button("Export JSON") {
                    jsonDoc = TiersDocument(tiers: app.tiers)
                    exportingJSON = true
                }
                Button("Import JSON") { importingJSON = true }
                #endif
                Button("Export Text") {
                    exportText = app.exportText()
                    #if os(iOS)
                    showingShare = true
                    #else
                    // tvOS: no share sheet; just log for now
                    print(exportText)
                    #endif
                }
                #if !os(tvOS)
                .keyboardShortcut("e", modifiers: [.command])
                #endif
                Divider()
                Button("Head-to-Head") { app.startH2H() }
                #if !os(tvOS)
                    .keyboardShortcut("h", modifiers: [.command])
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
                .fileExporter(isPresented: $exportingJSON, document: jsonDoc, contentType: .json, defaultFilename: "tiers.json") { result in
                    if case .failure(let err) = result { print("Export failed: \(err)") }
                }
                .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
                    if case .success(let url) = result {
                        if let data = try? Data(contentsOf: url),
                           let tiers = try? JSONDecoder().decode(TLTiers.self, from: data) {
                            app.tiers = tiers
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
