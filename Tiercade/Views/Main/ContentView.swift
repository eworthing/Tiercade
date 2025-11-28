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

import TiercadeCore

internal struct AppTier: Identifiable, Hashable { let id: String; var name: String }
// (Several view components — ToastView, ProgressIndicatorView, DragTargetHighlight,
// QuickRank / HeadToHead overlays, toolbar, sidebar and grid subviews — were moved to
// smaller files under `Tiercade/Views/ContentView+*.swift` to reduce compile
// specialization cost and keep this file focused. See those files for implementations.)

internal struct ContentView: View {
    @Environment(AppState.self) private var app
    @Environment(\.undoManager) private var undoManager
    @State private var showingAddItems = false
    #if os(tvOS)
    private var canStartHeadToHeadFromRemote: Bool {
        app.quickRankTarget == nil && app.canStartHeadToHead
    }
    #endif

    internal var body: some View {
        MainAppView()
            .task {
                app.updateUndoManager(undoManager)
            }
            .onChange(of: undoManager) { _, newValue in
                app.updateUndoManager(newValue)
            }
    }
}

#if os(iOS)
// ExportDocument and ShareSheet are defined in the modular toolbar file
#endif

// MARK: - Tier grid
// Implementations for TierGridView, TierRowView, UnrankedView, CardView and
// ThumbnailView were moved to `Tiercade/Views/ContentView+TierGrid.swift`.
// Keeping this small pointer here so the file remains easy to scan.

private extension Gradient {
    static var tierListBackground: Gradient { .init(colors: [Palette.bg.opacity(0.6), Palette.brand.opacity(0.2)]) }
}

// MARK: - Previews

@MainActor
private struct ContentViewPreview: View {
    private let appState = AppState(inMemory: true)

    var body: some View {
        ContentView()
            .environment(appState)
    }
}

#Preview("iPhone") {
    ContentViewPreview()
}

#Preview("iPad") {
    ContentViewPreview()
}

#if os(tvOS)
#Preview("tvOS") {
    ContentViewPreview()
}
#endif

// MARK: - Quick Rank overlay
// QuickRankOverlay (and the other overlays like HeadToHeadOverlay, ToastView,
// etc.) were moved to `Tiercade/Views/ContentView+Overlays.swift`.

// MARK: - JSON FileDocument
// HeadToHead, quick-rank and overlay components are implemented in
// `Tiercade/Views/ContentView+Overlays.swift`.

// Analysis and statistics views were moved to `Tiercade/Views/ContentView+Analysis.swift`
// to reduce compile-time specialization. See that file for the implementations.
