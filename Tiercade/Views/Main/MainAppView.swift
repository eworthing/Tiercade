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
    @Environment(AppState.self) private var app: AppState
    #if os(tvOS)
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var detailFocus: DetailFocus?
    private enum DetailFocus: Hashable { case close }
    #endif

    var body: some View {
        let detailPresented = app.detailItem != nil

        return Group {
            #if os(macOS) || targetEnvironment(macCatalyst)
            NavigationSplitView {
                SidebarView(tierOrder: app.tierOrder)
                    .environment(app)
            } content: {
                TierGridView(tierOrder: app.tierOrder)
                    .environment(app)
            } detail: {
                EmptyView()
            }
            .toolbar { ToolbarView(app: app) }
            #else
            // For iOS/tvOS show content full-bleed and inject bars via safe area insets
            ZStack {
                TierGridView(tierOrder: app.tierOrder)
                    .environment(app)
                    // Add content padding to avoid overlay bars overlap
                    .padding(.top, TVMetrics.contentTopInset)
                    .padding(.bottom, TVMetrics.contentBottomInset)
                    .allowsHitTesting(!detailPresented)
                    .disabled(detailPresented)
            }
            #if os(tvOS)
            // Top toolbar (overlay so it doesn't reduce content area)
            .overlay(alignment: .top) {
                TVToolbarView(app: app)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: TVMetrics.topBarHeight)
                    .background(.thinMaterial)
                    .overlay(Divider().opacity(0.15), alignment: .bottom)
                    .allowsHitTesting(!detailPresented)
                    .disabled(detailPresented)
            }
            // Bottom action bar (safe area inset to avoid covering focused rows)
            .overlay(alignment: .bottom) {
                TVActionBar(app: app)
                    .frame(maxWidth: .infinity)
                    .frame(height: TVMetrics.bottomBarHeight)
                    .background(.thinMaterial)
                    .overlay(Divider().opacity(0.15), alignment: .top)
                    .allowsHitTesting(!detailPresented)
                    .disabled(detailPresented)
            }
            #else
            // ToolbarView is ToolbarContent (not a View) on some platforms; avoid embedding it directly on tvOS
            .overlay(alignment: .top) {
            HStack { Text("") }
            .environment(app)
            }
            #endif
            #endif
        }
        #if os(tvOS)
        .task { FocusUtils.seedFocus() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { FocusUtils.seedFocus() }
        }
        .onExitCommand {
            if detailPresented {
                app.detailItem = nil
            }
        }
        #endif
        .overlay {
            // Compose overlays here so they appear on all platforms (including tvOS)
            ZStack {
                // Progress indicator (centered)
                if app.isLoading {
                    ProgressIndicatorView(
                        isLoading: app.isLoading,
                        message: app.loadingMessage,
                        progress: app.operationProgress
                    )
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
                        Color.black.opacity(0.55).ignoresSafeArea()
                        VStack(spacing: 24) {
                            DetailView(item: detail)
                                .frame(maxWidth: 720)

                            Button("Close") { app.detailItem = nil }
                                #if os(tvOS)
                                .buttonStyle(.tvRemote(.secondary))
                                .focused($detailFocus, equals: .close)
                                #else
                                .buttonStyle(.bordered)
                                #endif
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 36)
                        .frame(maxWidth: 820)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
                        )
                        .accessibilityAddTraits(.isModal)
                        #if os(tvOS)
                        .focusSection()
                        .defaultFocus($detailFocus, .close)
                        .onAppear { detailFocus = .close }
                        .onDisappear { detailFocus = nil }
                        #endif
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
    @Bindable var app: AppState
    // Seed and manage initial focus for tvOS toolbar controls
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable {
        case undo, redo, randomize, reset, h2h, analyze
    }

    var body: some View {
        let randomizeEnabled = app.canRandomizeItems
        let headToHeadEnabled = app.canStartHeadToHead
        let analysisActive = app.showingAnalysis
        let analysisEnabled = analysisActive || app.canShowAnalysis
        let randomizeHint = randomizeEnabled
            ? "Randomly distribute items across tiers"
            : "Add more items before randomizing tiers"
        let randomizeTooltip = randomizeEnabled ? "Randomize" : "Add more items to randomize"
        let headToHeadHint = headToHeadEnabled
            ? "Start head-to-head comparisons"
            : "Add at least two items before starting head-to-head"
        let headToHeadTooltip = headToHeadEnabled ? "Head to Head" : "Add two items to start"
        let analysisHint: String = {
            if analysisEnabled {
                return analysisActive ? "Hide tier analysis" : "Show insights about your tiers"
            }
            return "Add items before opening analysis"
        }()
        let analysisTooltip = analysisActive ? "Hide Analysis" : "Show Analysis"
        HStack(spacing: 16) {
            Button(action: { app.undo() }, label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .disabled(!app.canUndo)
                .focused($focusedControl, equals: .undo)
                .accessibilityLabel("Undo")
                .focusTooltip("Undo")

            Button(action: { app.redo() }, label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .disabled(!app.canRedo)
                .focused($focusedControl, equals: .redo)
                .accessibilityLabel("Redo")
                .focusTooltip("Redo")

            Divider()

            Button(action: { app.randomize() }, label: {
                Image(systemName: "shuffle")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .disabled(!randomizeEnabled)
                .accessibilityIdentifier("Toolbar_Randomize")
                .focused($focusedControl, equals: .randomize)
                .accessibilityLabel("Randomize")
                .accessibilityHint(randomizeHint)
                .focusTooltip(randomizeTooltip)

            Button(action: { app.reset() }, label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_Reset")
                .focused($focusedControl, equals: .reset)
                .accessibilityLabel("Reset")
                .focusTooltip("Reset")

            Spacer(minLength: 0)

            Button(action: { app.startH2H() }, label: {
                Image(systemName: "bolt.horizontal")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_H2H")
                .disabled(!headToHeadEnabled)
                .focused($focusedControl, equals: .h2h)
                .accessibilityLabel("Head to Head")
                .accessibilityHint(headToHeadHint)
                .focusTooltip(headToHeadTooltip)

            Button(action: { app.toggleAnalysis() }, label: {
                Image(systemName: analysisActive ? "chart.bar.fill" : "chart.bar")
                    .frame(width: 32, height: 32)
            })
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_Analyze")
                .disabled(!analysisEnabled)
                .focused($focusedControl, equals: .analyze)
                .accessibilityLabel("Analyze")
                .accessibilityValue(analysisActive ? "Visible" : "Hidden")
                .accessibilityHint(analysisHint)
                .focusTooltip(analysisTooltip)
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
