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
    @State private var editMode: EditMode = .inactive
    #if os(tvOS)
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var detailFocus: DetailFocus?
    enum DetailFocus: Hashable { case close }
    @Namespace private var glassNamespace
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
    @Bindable var app = app
    let detailPresented = app.detailItem != nil
    let headToHeadPresented = app.h2hActive
    let themeCreatorPresented = app.showThemeCreator
    let tierCreatorPresented = app.showTierListCreator
    let quickMovePresented = app.quickMoveTarget != nil
    // Note: ThemePicker, TierListBrowser, and Analytics now use .fullScreenCover()
    // which provides automatic focus containment via separate presentation context
    #if os(tvOS)
    let modalBlockingFocus = headToHeadPresented
        || detailPresented
        || themeCreatorPresented
        || quickMovePresented
        || app.showThemePicker
        || tierCreatorPresented
    #else
    let modalBlockingFocus = detailPresented || headToHeadPresented || themeCreatorPresented || tierCreatorPresented
    #endif

        return Group {
            #if os(tvOS)
            tvOSPrimaryContent(modalBlockingFocus: modalBlockingFocus)
            #elseif os(macOS) || targetEnvironment(macCatalyst)
            macSplitView(modalBlockingFocus: modalBlockingFocus)
            #elseif os(iOS)
            if horizontalSizeClass == .regular {
                regularWidthSplitView(modalBlockingFocus: modalBlockingFocus)
            } else {
                compactStack(modalBlockingFocus: modalBlockingFocus)
            }
            #else
            platformPrimaryContent(modalBlockingFocus: modalBlockingFocus)
            #endif
        }
        #if os(tvOS)
        .task { FocusUtils.seedFocus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { FocusUtils.seedFocus() }
        }
        .onExitCommand {
            if app.quickMoveTarget != nil {
                app.cancelQuickMove()
            } else if app.showThemeCreator {
                app.cancelThemeCreation(returnToThemePicker: false)
            } else if app.showTierListCreator {
                app.cancelTierListCreator()
            } else if app.showingTierListBrowser {
                app.dismissTierListBrowser()
            } else if app.showAnalyticsSidebar {
                app.closeAnalyticsSidebar()
            } else if app.h2hActive {
                app.cancelH2H(fromExitCommand: true)
            } else if detailPresented {
                app.detailItem = nil
            } else if editMode == .active {
                // Exit selection mode when Menu button pressed with no overlays active
                editMode = .inactive
                app.clearSelection()
            }
        }
        #endif
        .overlay {
            // Compose overlays here so they appear on all platforms (including tvOS)
            ZStack { overlayStack }
        }
        #if !os(tvOS)
        .sheet(item: Binding(
            get: { app.detailItem },
            set: { app.detailItem = $0 }
        )) { detail in
            NavigationStack {
                DetailView(item: detail)
                    .navigationTitle(detail.name ?? detail.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { app.detailItem = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        #endif
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
            Text("This will randomly redistribute all items across tiers.")
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
        .fullScreenCover(isPresented: Binding(
            get: { app.showTierListCreator },
            set: { app.showTierListCreator = $0 }
        )) {
            if let draft = app.tierListCreatorDraft {
                TierListProjectWizard(appState: app, draft: draft, context: app.tierListWizardContext)
            }
        }
        #if !os(tvOS)
        .sheet(isPresented: Binding(
            get: { app.showingAnalysis },
            set: { app.showingAnalysis = $0 }
        )) {
            AnalysisView(app: app)
        }
        #endif
    }

    // MARK: - Overlay Composition
    @ViewBuilder
    private var overlayStack: some View {
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
        // Quick Move overlay (unified item actions overlay)
        QuickMoveOverlay(app: app)
            .zIndex(45)
        #endif

        // Head-to-Head overlay
        MatchupArenaOverlay(app: app)
            .zIndex(40)

        #if os(tvOS)
        if app.showAnalyticsSidebar {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                AnalyticsSidebarView()
                    .frame(maxHeight: .infinity)
            }
            .allowsHitTesting(true)
            .zIndex(52)
        }
        #endif

        if app.showingTierListBrowser {
            TierListBrowserScene(app: app)
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
                ThemeLibraryOverlay()
                    .zIndex(54)
            } else {
                ThemeLibraryOverlay()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(54)
            }
        }

        if app.showThemeCreator, let draft = app.themeDraft {
            AccessibilityBridgeView()

            ThemeCreatorOverlay(appState: app, draft: draft)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(55)
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

        // Detail overlay (all platforms)
        if let detail = app.detailItem {
            detailOverlay(for: detail)
        }
    }

    @ViewBuilder
    private func detailOverlay(for detail: Item) -> some View {
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
        .transition(
            .move(edge: .trailing)
                .combined(with: .opacity)
        )
        .zIndex(55)
        #endif
    }

    // MARK: - Platform Navigation Structures

    #if os(macOS) || targetEnvironment(macCatalyst)
    @ViewBuilder
    private func macSplitView(modalBlockingFocus: Bool) -> some View {
        NavigationSplitView {
            List(app.tierOrder, id: \.self) { tier in
                Text("Sidebar • " + tier)
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            Text("Debug Detail")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.yellow.opacity(0.2))
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("Tiercade Debug")
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Split Toolbar Test") {
                    print("Split toolbar tapped")
                }
            }
        }
    }
    #endif

    #if os(iOS)
    @ViewBuilder
    private func regularWidthSplitView(modalBlockingFocus: Bool) -> some View {
        NavigationSplitView {
            List(app.tierOrder, id: \.self) { tier in
                Text("Sidebar • " + tier)
            }
        } detail: {
            Text("Debug Detail")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.yellow.opacity(0.2))
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("Tiercade Debug")
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Split Toolbar Test") {
                    print("iPad toolbar tapped")
                }
            }
        }
    }

    @ViewBuilder
    private func compactStack(modalBlockingFocus: Bool) -> some View {
        Text("Debug Detail")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yellow.opacity(0.2))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Stack Toolbar Test") {
                        print("Stack toolbar tapped")
                    }
                }
            }
    }
    #endif

    // MARK: - Platform Specific Content

    @ViewBuilder
    private func tierGridLayer(modalBlockingFocus: Bool) -> some View {
        ZStack {
            TierGridView(tierOrder: app.tierOrder)
                .environment(app)
                .environment(\.editMode, $editMode)
                // Add content padding to avoid overlay bars overlap
                #if os(tvOS)
                .padding(.top, TVMetrics.contentTopInset)
                .padding(.bottom, TVMetrics.contentBottomInset)
                #else
                .padding(.top, Metrics.grid * 6)
                .padding(.bottom, Metrics.grid * 3)
                #endif
                .allowsHitTesting(!modalBlockingFocus)
            // Note: Don't use .disabled() as it removes elements from accessibility tree
            // Only block hit testing when modals are active
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    #if os(tvOS)
    @ViewBuilder
    private func tvOSPrimaryContent(modalBlockingFocus: Bool) -> some View {
        tierGridLayer(modalBlockingFocus: modalBlockingFocus)
            .overlay(alignment: .top) {
                TVToolbarView(
                    app: app,
                    modalActive: modalBlockingFocus,
                    editMode: $editMode,
                    glassNamespace: glassNamespace
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: TVMetrics.topBarHeight)
                .allowsHitTesting(!modalBlockingFocus)
                .accessibilityElement(children: .contain)
            }
            .overlay(alignment: .bottom) {
                TVActionBar(app: app, glassNamespace: glassNamespace)
                    .environment(\.editMode, $editMode)
                    .allowsHitTesting(!modalBlockingFocus)
                    .accessibilityElement(children: .contain)
            }
            #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                BuildInfoView()
                    .padding(.trailing, TVMetrics.barHorizontalPadding)
                    .padding(.bottom, TVMetrics.barVerticalPadding + 4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            #endif
    }
    #else
    @ViewBuilder
    private func platformPrimaryContent(modalBlockingFocus: Bool) -> some View {
        Text("Platform Debug Content")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.2))
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

#if os(tvOS)
// Simple tvOS-friendly toolbar exposing essential actions as buttons.
#endif
