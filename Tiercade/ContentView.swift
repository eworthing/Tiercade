//
//  ContentView.swift
//  Tiercade
//
//  Created by PL on 9/14/25.
//

import SwiftUI

struct AppTier: Identifiable, Hashable { let id: String; var name: String }

struct ContentView: View {
    @StateObject private var app = AppState()

    var body: some View {
        AdaptiveLayout {
            SidebarView(tierOrder: app.tierOrder)
            TierGridView(tierOrder: app.tierOrder)
        }
        .environmentObject(app)
        .toolbar { ToolbarView() }
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
                .textFieldStyle(.roundedBorder)
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
    @State private var showingShare = false
    @State private var exportText: String = ""
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button(action: { app.undo() }) { Label("Undo", systemImage: "arrow.uturn.backward") }.disabled(!app.canUndo)
            Button(action: { app.redo() }) { Label("Redo", systemImage: "arrow.uturn.forward") }.disabled(!app.canRedo)
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
                Button("Load Saved") { _ = app.load() }
                Button("Export Text") {
                    exportText = app.exportText()
                    showingShare = true
                }
            }
        }
        #if os(iOS)
        // For iOS/iPadOS quick text export
        ToolbarItem(placement: .bottomBar) {
            EmptyView()
                .sheet(isPresented: $showingShare) {
                    ShareSheet(activityItems: [exportText])
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
                            .draggable(c.id)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        .dropDestination(for: String.self) { items, _ in
            if let id = items.first { app.move(id, to: tier) }
            return true
        }
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
                        .draggable(c.id)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary))
        .dropDestination(for: String.self) { _, _ in false }
    }
}

struct CardView: View {
    let contestant: TLContestant
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
        .onTapGesture { /* selection or quick rank handling later */ }
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
