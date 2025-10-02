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
    @Environment(\.resetFocus) private var resetFocus
    @Namespace private var focusNamespace
    @FocusState private var focusedRegion: FocusRegion?
    @FocusState private var detailFocus: DetailFocus?
    @State private var didBootstrapFocus = false
    @State private var lastBaseRegion: FocusRegion = .grid
    enum DetailFocus: Hashable { case close }
    #endif

    var body: some View {
        let detailPresented = app.detailItem != nil
        let headToHeadPresented = app.h2hActive
        let quickRankPresented = app.quickRankTarget != nil
        let tierListBrowserPresented = app.showingTierListBrowser
        let themePickerPresented = app.showThemePicker
        #if os(tvOS)
    _ = app.quickMoveTarget != nil
    _ = app.itemMenuTarget != nil
    _ = app.showAnalyticsSidebar
        let overlayRegion = determineOverlayRegion()
        let modalBlockingFocus = overlayRegion != nil
        #else
        let baseModal = detailPresented || headToHeadPresented || themePickerPresented
        let modalBlockingFocus = baseModal || quickRankPresented || tierListBrowserPresented
        #endif
        return platformContent(overlayBlockingFocus: modalBlockingFocus)
        #if os(tvOS)
        .focusScope(focusNamespace)
        .task {
            FocusUtils.seedFocus()
            bootstrapInitialFocus(for: overlayRegion)
        }
        .onAppear {
            alignFocus(to: overlayRegion)
        }
        .onChange(of: overlayRegion) { _, newValue in
            alignFocus(to: newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                FocusUtils.seedFocus()
                alignFocus(to: overlayRegion)
            }
        }
        .onChange(of: focusedRegion) { _, newValue in
            if let region = newValue, !region.isOverlay {
                lastBaseRegion = region
            }
        }
        .onExitCommand {
            if app.showingTierListBrowser {
                app.dismissTierListBrowser()
            } else if app.showAnalyticsSidebar {
                app.closeAnalyticsSidebar()
            } else if app.h2hActive {
                app.cancelH2H(fromExitCommand: true)
            } else if detailPresented {
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
                    #if os(tvOS)
                    .focused($focusedRegion, equals: .quickRank)
                    .prefersDefaultFocus(in: focusNamespace)
                    #endif
                    .zIndex(40)

                #if os(tvOS)
                // Quick Move overlay for tvOS Play/Pause accelerator
                QuickMoveOverlay(app: app)
                    .focused($focusedRegion, equals: .quickMove)
                    .prefersDefaultFocus(in: focusNamespace)
                    .zIndex(45)
                // Item Menu overlay (primary action)
                ItemMenuOverlay(app: app)
                    .focused($focusedRegion, equals: .itemMenu)
                    .prefersDefaultFocus(in: focusNamespace)
                    .zIndex(46)
                #endif

                // Head-to-Head overlay
                HeadToHeadOverlay(app: app)
                    #if os(tvOS)
                    .focused($focusedRegion, equals: .headToHead)
                    .prefersDefaultFocus(in: focusNamespace)
                    #endif
                    .zIndex(40)

                #if os(tvOS)
                if app.showAnalyticsSidebar {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        AnalyticsSidebarView()
                            .frame(maxHeight: .infinity)
                    }
                    .allowsHitTesting(true)
                    .focused($focusedRegion, equals: .analytics)
                    .prefersDefaultFocus(in: focusNamespace)
                    .zIndex(52)
                }
                #endif

                if app.showingTierListBrowser {
                    TierListBrowserScene(app: app)
                        #if os(tvOS)
                        .focused($focusedRegion, equals: .tierBrowser)
                        .prefersDefaultFocus(in: focusNamespace)
                        #endif
                        .transition(.opacity)
                        .zIndex(53)
                }

                // Theme picker overlay
                if app.showThemePicker {
                    AccessibilityBridgeView()

                    // In UI tests, avoid transitions so the overlay appears in the
                    // accessibility tree immediately. Transitions can delay when
                    // XCTest sees elements, causing flaky existence checks.
                    if ProcessInfo.processInfo.arguments.contains("-uiTest") {
                        ThemePickerOverlay(appState: app)
                            #if os(tvOS)
                            .focused($focusedRegion, equals: .themePicker)
                            .prefersDefaultFocus(in: focusNamespace)
                            #endif
                            .zIndex(54)
                    } else {
                        ThemePickerOverlay(appState: app)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            #if os(tvOS)
                            .focused($focusedRegion, equals: .themePicker)
                            .prefersDefaultFocus(in: focusNamespace)
                            #endif
                            .zIndex(54)
                    }
                }

                // Toast messages (bottom)
                if let toast = app.currentToast {
                    VStack {
                        Spacer()
                        ToastView(toast: toast)
                            .padding()
                    }
                    .zIndex(60)
                }

                // Build timestamp (DEBUG only, bottom-right corner)
                #if DEBUG
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        BuildInfoView()
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
                .zIndex(61)
                .allowsHitTesting(false)
                #endif

                // Bottom action bar is inset on tvOS via safeAreaInset above; no overlay here

                // Detail overlay (all platforms)
                if let detail = app.detailItem {
                    #if os(tvOS)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        DetailSidebarView(item: detail, focus: $detailFocus)
                            .frame(maxHeight: .infinity)
                    }
                    .focusSection()
                    .defaultFocus($detailFocus, .close)
                    .onAppear { detailFocus = .close }
                    .onDisappear { detailFocus = nil }
                    .focused($focusedRegion, equals: .detail)
                    .prefersDefaultFocus(in: focusNamespace)
                    .transition(
                        .move(edge: .trailing)
                            .combined(with: .opacity)
                    )
                    .zIndex(55)
                    #else
                    ZStack {
                        Color.black.opacity(0.55).ignoresSafeArea()
                        VStack(spacing: 24) {
                            DetailView(item: detail)
                                .frame(maxWidth: 720)

                            Button("Close") { app.detailItem = nil }
                                .buttonStyle(.bordered)
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
                    }
                    .transition(.opacity)
                    .zIndex(55)
                    #endif
                }
            }
        }
        .alert("Randomize Tiers?", isPresented: Binding(
            get: { app.showRandomizeConfirmation },
            set: { app.showRandomizeConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {
                app.showRandomizeConfirmation = false
            }
            Button("Randomize", role: .destructive) {
                app.showRandomizeConfirmation = false
                app.performRandomize()
            }
        } message: {
            Text("This will randomly redistribute all items across tiers. This action cannot be undone.")
        }
        .alert("Reset Tier List?", isPresented: Binding(
            get: { app.showResetConfirmation },
            set: { app.showResetConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {
                app.showResetConfirmation = false
            }
            Button("Reset", role: .destructive) {
                app.showResetConfirmation = false
                app.performReset(showToast: true)
            }
        } message: {
            Text("This will delete all items and reset the tier list. This action cannot be undone.")
        }
    }
}

private extension MainAppView {
    @ViewBuilder
    func platformContent(overlayBlockingFocus: Bool) -> some View {
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
                .disabled(overlayBlockingFocus)
            #if os(tvOS)
                .focusSection()
                .focused($focusedRegion, equals: .grid)
                .prefersDefaultFocus(in: focusNamespace)
            #endif
        }
        #if os(tvOS)
        // Top toolbar (overlay so it doesn't reduce content area)
        .overlay(alignment: .top) {
            TVToolbarView(app: app)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: TVMetrics.topBarHeight)
                .background(.thinMaterial)
                .overlay(Divider().opacity(0.15), alignment: .bottom)
                .focused($focusedRegion, equals: .toolbar)
                .prefersDefaultFocus(in: focusNamespace)
                .disabled(overlayBlockingFocus)
                .accessibilityElement(children: AccessibilityChildBehavior.contain)
        }
        // Bottom action bar (safe area inset to avoid covering focused rows)
        .overlay(alignment: .bottom) {
            TVActionBar(app: app)
                .focused($focusedRegion, equals: .actionBar)
                .prefersDefaultFocus(in: focusNamespace)
                .disabled(overlayBlockingFocus)
                .accessibilityElement(children: AccessibilityChildBehavior.contain)
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
    private func determineOverlayRegion() -> FocusRegion? {
        let candidates: [FocusRegion?] = [
            app.h2hActive ? .headToHead : nil,
            app.detailItem != nil ? .detail : nil,
            app.showThemePicker ? .themePicker : nil,
            app.showingTierListBrowser ? .tierBrowser : nil,
            app.itemMenuTarget != nil ? .itemMenu : nil,
            app.quickMoveTarget != nil ? .quickMove : nil,
            app.quickRankTarget != nil ? .quickRank : nil,
            app.showAnalyticsSidebar ? .analytics : nil
        ]
        return candidates.compactMap { $0 }.first
    }

    @MainActor
    private func alignFocus(to overlay: FocusRegion?) {
        let target: FocusRegion = {
            if let overlay {
                return overlay
            }
            return lastBaseRegion
        }()
        if focusedRegion != target {
            focusedRegion = target
        }
        resetFocus(in: focusNamespace)
    }

    @MainActor
    private func bootstrapInitialFocus(for overlay: FocusRegion?) {
        guard !didBootstrapFocus else { return }
        didBootstrapFocus = true
        alignFocus(to: overlay)
    }
    #endif
}

// Small preview
#Preview("Main") { MainAppView() }

// File-scoped helper to expose an immediate accessibility element for UI tests.
private struct AccessibilityBridgeView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier("ThemePicker_Overlay")
            .accessibilityHidden(false)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
    }
}

// Simple tvOS-friendly toolbar exposing essential actions as buttons.
struct TVToolbarView: View {
    @Bindable var app: AppState
    // Seed and manage initial focus for tvOS toolbar controls
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable {
        case undo, redo, library, randomize, reset, tierMenu, h2h, analytics, theme
    }

    var body: some View {
        let randomizeEnabled = app.canRandomizeItems
        let headToHeadEnabled = app.canStartHeadToHead
        let analyticsActive = app.showAnalyticsSidebar
        let analyticsEnabled = analyticsActive || app.canShowAnalysis
        let randomizeHint = randomizeEnabled
            ? "Randomly distribute items across tiers"
            : "Add more items before randomizing tiers"
        let randomizeTooltip = randomizeEnabled ? "Randomize" : "Add more items to randomize"
        let headToHeadHint = headToHeadEnabled
            ? "Start head-to-head comparisons"
            : "Add at least two items before starting head-to-head"
        let headToHeadTooltip = headToHeadEnabled ? "Head to Head" : "Add two items to start"
        let analyticsHint: String = {
            if analyticsEnabled {
                return analyticsActive
                    ? "Hide analytics"
                    : "View tier distribution and balance score"
            }
            return "Add items before opening analytics"
        }()
        let analyticsTooltip = analyticsActive ? "Hide Analytics" : "Show Analytics"
        HStack(spacing: 16) {
            Button(action: { app.undo() }, label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .disabled(!app.canUndo)
            .focused($focusedControl, equals: .undo)
            .accessibilityLabel("Undo")
            .focusTooltip("Undo")

            Button(action: { app.redo() }, label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .disabled(!app.canRedo)
            .focused($focusedControl, equals: .redo)
            .accessibilityLabel("Redo")
            .focusTooltip("Redo")

            Divider()

            Button(action: { app.presentTierListBrowser() }, label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .focused($focusedControl, equals: .library)
            .accessibilityIdentifier("Toolbar_BundledLibrary")
            .accessibilityLabel("Bundled Tier Lists")
            .accessibilityHint("Browse built-in tier lists to start ranking")
            .focusTooltip("Tier Library")
            .disabled(app.showingTierListBrowser)

            Button(action: { app.randomize() }, label: {
                Image(systemName: "shuffle")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
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
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_Reset")
            .focused($focusedControl, equals: .reset)
            .accessibilityLabel("Reset")
            .focusTooltip("Reset")

            TierListQuickMenu(app: app)
                .focused($focusedControl, equals: .tierMenu)
                .focusTooltip("Choose tier list")
                .padding(.leading, 12)

            Spacer(minLength: 0)

            Button(action: { app.startH2H() }, label: {
                Image(systemName: "person.line.dotted.person.fill")
                    .font(.system(size: Metrics.toolbarIconSize * 0.9))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_H2H")
            .disabled(!headToHeadEnabled)
            .focused($focusedControl, equals: .h2h)
            .accessibilityLabel("Head to Head")
            .accessibilityHint(headToHeadHint)
            .focusTooltip(headToHeadTooltip)

            Button(action: { app.toggleAnalyticsSidebar() }, label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_Analytics")
            .disabled(!analyticsEnabled)
            .focused($focusedControl, equals: .analytics)
            .accessibilityLabel("Analytics")
            .accessibilityValue(analyticsActive ? "Visible" : "Hidden")
            .accessibilityHint(analyticsHint)
            .focusTooltip(analyticsTooltip)

            Button(action: { app.toggleThemePicker() }, label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_ThemePicker")
            .focused($focusedControl, equals: .theme)
            .accessibilityLabel("Tier Themes")
            .accessibilityHint("Choose a color theme for your tiers")
            .focusTooltip("Tier Themes")
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
        .onChange(of: app.showAnalyticsSidebar) { _, isPresented in
            if !isPresented {
                focusedControl = .analytics
            }
        }
        .onAppear {
            // In UI test mode, seed toolbar focus to the theme button to make tests deterministic
            if ProcessInfo.processInfo.arguments.contains("-uiTest") {
                focusedControl = .theme
            }
        }
    }
}
