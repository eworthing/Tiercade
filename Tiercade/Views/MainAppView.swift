import SwiftUI
import TiercadeCore
// HIG-aligned tvOS layout metrics
#if os(tvOS)
import Foundation
#endif

// MainAppView: Top-level composition that was split out during modularization.
// It composes SidebarView, TierGridView, ToolbarView and overlays (from the
// ContentView+*.swift modular files).

struct MainAppView: View {
    @EnvironmentObject var app: AppState
    #if os(tvOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

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
            // For iOS/tvOS show content full-bleed and inject bars via safe area insets
            ZStack {
                TierGridView(tierOrder: app.tierOrder)
                    .environmentObject(app)
                    // Add content padding to avoid overlay bars overlap
                    .padding(.top, TVMetrics.contentTopInset)
                    .padding(.bottom, TVMetrics.contentBottomInset)
            }
            #if os(tvOS)
            // Top toolbar (overlay so it doesn't reduce content area)
            .overlay(alignment: .top) {
                TVToolbarView(app: app)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: TVMetrics.topBarHeight)
                    .background(.thinMaterial)
                    .overlay(Divider().opacity(0.15), alignment: .bottom)
            }
            // Bottom action bar (safe area inset to avoid covering focused rows)
            .overlay(alignment: .bottom) {
                TVActionBar(app: app)
                    .frame(maxWidth: .infinity)
                    .frame(height: TVMetrics.bottomBarHeight)
                    .background(.thinMaterial)
                    .overlay(Divider().opacity(0.15), alignment: .top)
            }
            #else
            // ToolbarView is ToolbarContent (not a View) on some platforms; avoid embedding it directly on tvOS
            .overlay(alignment: .top) {
                HStack { Text("") }
                    .environmentObject(app)
            }
            #endif
#endif
        }
#if os(tvOS)
        .task { FocusUtils.seedFocus() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { FocusUtils.seedFocus() }
        }
#endif
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

                // Bottom action bar is inset on tvOS via safeAreaInset above; no overlay here

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
    // Seed and manage initial focus for tvOS toolbar controls
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable {
        case undo, redo, randomize, reset, h2h, analyze
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { app.undo() }) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .buttonStyle(.tvRemote(.secondary))
                .disabled(!app.canUndo)
                .focused($focusedControl, equals: .undo)

            Button(action: { app.redo() }) { Label("Redo", systemImage: "arrow.uturn.forward") }
                .buttonStyle(.tvRemote(.secondary))
                .disabled(!app.canRedo)
                .focused($focusedControl, equals: .redo)

            Divider()

            Button(action: { app.randomize() }) { Label("Randomize", systemImage: "shuffle") }
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_Randomize")
                .focused($focusedControl, equals: .randomize)

            Button(action: { app.reset() }) { Label("Reset", systemImage: "trash") }
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_Reset")
                .focused($focusedControl, equals: .reset)

            Spacer(minLength: 0)

            Button(action: { app.startH2H() }) { Label("H2H", systemImage: "bolt.horizontal") }
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_H2H")
                .focused($focusedControl, equals: .h2h)

            Button(action: { app.toggleAnalysis() }) { Label("Analyze", systemImage: "chart.bar") }
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_Analyze")
                .focused($focusedControl, equals: .analyze)
        }
        .lineLimit(1)
        .padding(.horizontal, TVMetrics.barHorizontalPadding)
        .padding(.vertical, TVMetrics.barVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: TVMetrics.topBarHeight)
        .fixedSize(horizontal: false, vertical: true)
        #if os(tvOS)
        .focusSection()
        // Don't seed default focus here; let grid own initial focus for tvOS
        #endif
    }
}
