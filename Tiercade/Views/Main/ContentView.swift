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

struct AppTier: Identifiable, Hashable { let id: String; var name: String }
// (Several view components — ToastView, ProgressIndicatorView, DragTargetHighlight,
// QuickRank / H2H overlays, toolbar, sidebar and grid subviews — were moved to
// smaller files under `Tiercade/Views/ContentView+*.swift` to reduce compile
// specialization cost and keep this file focused. See those files for implementations.)

struct ContentView: View {
    @State private var app = AppState()
    @State private var showingAddItems = false
    #if os(tvOS)
    private var canStartH2HFromRemote: Bool {
        app.quickRankTarget == nil && app.canStartHeadToHead
    }
    #endif

    var body: some View {
        MainAppView()
            .environment(app)
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
    static var tierListBackground: Gradient { .init(colors: [Color.black.opacity(0.6), Color.blue.opacity(0.2)]) }
}

#Preview("iPhone") { ContentView() }
#Preview("iPad") { ContentView() }
#if os(tvOS)
#Preview("tvOS") { ContentView() }
#endif

// MARK: - Quick Rank overlay
// QuickRankOverlay (and the other overlays like HeadToHeadOverlay, ToastView,
// etc.) were moved to `Tiercade/Views/ContentView+Overlays.swift`.

// MARK: - JSON FileDocument
// Head-to-head, quick-rank and overlay components are implemented in
// `Tiercade/Views/ContentView+Overlays.swift`.

// Analysis and statistics views were moved to `Tiercade/Views/ContentView+Analysis.swift`
// to reduce compile-time specialization. See that file for the implementations.
