import SwiftUI
import TiercadeCore

// MainAppView: Top-level composition that was split out during modularization.
// It composes SidebarView, TierGridView, ToolbarView and overlays (from the
// ContentView+*.swift modular files).

struct MainAppView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
#if os(macOS) || targetEnvironment(macCatalyst)
            NavigationSplitView {
                SidebarView(tierOrder: app.tierOrder)
                    .environmentObject(app)
            } content: {
                TierGridView(tierOrder: app.tierOrder)
                    .environmentObject(app)
            } detail: {
                EmptyView()
            }
            .toolbar { ToolbarView(app: app) }
#else
            // For iOS/tvOS use a simple VStack with toolbar at the top
            VStack(spacing: 0) {
#if os(tvOS)
                // tvOS: provide a simple view-based toolbar so essential actions remain reachable
                TVToolbarView(app: app)
                    .padding(.vertical, 8)
#else
                // ToolbarView is ToolbarContent (not a View) on some platforms; avoid embedding it directly on tvOS
                HStack {
                    // On non-tvOS platforms we can still include toolbar-like controls if needed.
                    // Keep this minimal so it builds across platforms.
                    Text("")
                }
                .environmentObject(app)
#endif

                TierGridView(tierOrder: app.tierOrder)
                    .environmentObject(app)
            }
#endif
        }
        .overlay {
            // Compose overlays here so they appear on all platforms (including tvOS)
            ZStack {
                // Progress indicator (centered)
                if app.isLoading {
                    ProgressIndicatorView(isLoading: app.isLoading, message: app.loadingMessage, progress: app.operationProgress)
                        .zIndex(50)
                }

                // Quick Rank overlay
                QuickRankOverlay(app: app)
                    .zIndex(40)

                #if os(tvOS)
                // Quick Move overlay for tvOS Play/Pause accelerator
                QuickMoveOverlay(app: app)
                    .zIndex(45)
                // Item Menu overlay (primary action)
                ItemMenuOverlay(app: app)
                    .zIndex(46)
                #endif

                // Head-to-Head overlay
                HeadToHeadOverlay(app: app)
                    .zIndex(40)

                // Toast messages (bottom)
                if let toast = app.currentToast {
                    VStack {
                        Spacer()
                        ToastView(toast: toast)
                            .padding()
                    }
                    .zIndex(60)
                }

                #if os(tvOS)
                VStack { Spacer(); TVActionBar(app: app) }
                    .zIndex(30)
                #endif

                // Detail overlay (all platforms)
                if let detail = app.detailItem {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        VStack {
                            DetailView(item: detail)
                            Button("Close") { app.detailItem = nil }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                    .transition(.opacity)
                    .zIndex(55)
                }
            }
        }
    }
}

// Small preview
#Preview("Main") { MainAppView() }

// Simple tvOS-friendly toolbar exposing essential actions as buttons.
struct TVToolbarView: View {
    @ObservedObject var app: AppState

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { app.undo() }) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .buttonStyle(GhostButtonStyle())

            Button(action: { app.redo() }) { Label("Redo", systemImage: "arrow.uturn.forward") }
                .buttonStyle(GhostButtonStyle())

            Divider()

            Button(action: { app.randomize() }) { Label("Randomize", systemImage: "shuffle") }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("Toolbar_Randomize")

            Button(action: { app.reset() }) { Label("Reset", systemImage: "trash") }
                .buttonStyle(GhostButtonStyle())
                .accessibilityIdentifier("Toolbar_Reset")

            Spacer()

            Button(action: { app.startH2H() }) { Label("H2H", systemImage: "bolt.horizontal") }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("Toolbar_H2H")

            Button(action: { app.toggleAnalysis() }) { Label("Analyze", systemImage: "chart.bar") }
                .buttonStyle(GhostButtonStyle())
                .accessibilityIdentifier("Toolbar_Analyze")
        }
        .padding(.horizontal, Metrics.grid)
    }
}
