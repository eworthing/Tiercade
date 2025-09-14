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

struct ContentView: View {
    @StateObject private var app = AppState()

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
        .toolbar { ToolbarView() }
        .overlay(alignment: .bottom) { QuickRankOverlay() }
        .overlay { HeadToHeadOverlay() }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Survivor Tier List").font(.largeTitle.bold())
            TextField("Search unranked…", text: $app.searchQuery)
            #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
            #endif
            HStack { Text("Unranked:"); Text("\(app.tiers["unranked"]?.count ?? 0)").bold() }
            Divider()
            ScrollView { VStack(alignment: .leading) { ForEach(tierOrder, id: \.self) { t in Label(t, systemImage: "flag") } } }
        }
        .padding()
        .frame(minWidth: 260)
        .background(.thinMaterial)
    }
}

struct ToolbarView: ToolbarContent {
    @EnvironmentObject var app: AppState
    @State private var exportText: String = ""
    #if os(iOS)
    @State private var showingShare = false
    @State private var exportingJSON = false
    @State private var importingJSON = false
    @State private var jsonDoc = TiersDocument()
    #endif
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu("Actions") {
                Button("Clear S Tier") { app.clearTier("S") }
                Button("Clear A Tier") { app.clearTier("A") }
                Button("Clear B Tier") { app.clearTier("B") }
                Button("Clear C Tier") { app.clearTier("C") }
                Button("Clear D Tier") { app.clearTier("D") }
                Button("Clear F Tier") { app.clearTier("F") }
                Divider()
                Button("Reset All", role: .destructive) { app.reset() }
                Button("Save Locally") { _ = app.save() }
                #if !os(tvOS)
                    .keyboardShortcut("s", modifiers: [.command])
                #endif
                Button("Load Saved") { _ = app.load() }
                #if !os(tvOS)
                    .keyboardShortcut("o", modifiers: [.command])
                #endif
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
    var cards: [TLContestant] { app.tiers[tier] ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tier).font(.title2.bold())
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(cards, id: \.id) { c in
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
        #if !os(tvOS)
        .dropDestination(for: String.self) { items, _ in
            if let id = items.first { app.move(id, to: tier) }
            return true
        }
        #endif
    }
}

struct UnrankedView: View {
    @EnvironmentObject var app: AppState
    var filtered: [TLContestant] {
        let q = app.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (app.tiers["unranked"] ?? []).filter { q.isEmpty || ($0.name ?? "").lowercased().contains(q) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Unranked").font(.title2.bold()); Spacer(); Text("\(filtered.count)") }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)]) {
                ForEach(filtered, id: \.id) { c in
                    CardView(contestant: c)
                    #if !os(tvOS)
                        .draggable(c.id)
                    #endif
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary))
    #if !os(tvOS)
    .dropDestination(for: String.self) { _, _ in false }
    #endif
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
    @EnvironmentObject var app: AppState
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
    @EnvironmentObject var app: AppState
    var body: some View {
        if app.h2hActive {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { /* block background interaction */ }
                VStack(spacing: 16) {
                    Text("Head-to-Head").font(.title2.bold())
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
