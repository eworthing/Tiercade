import SwiftUI
import TiercadeCore
// HIG-aligned tvOS layout metrics
#if os(tvOS)
import Foundation
#endif

// MainAppView: Top-level composition that was split out during modularization.
// It composes SidebarView, TierGridView, ToolbarView and overlays (from the
// ContentView+*.swift modular files).

internal struct MainAppView: View {
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

    internal var body: some View {
        @Bindable var app = app
        let detailPresented = app.detailItem != nil
        let headToHeadPresented = app.h2hActive
        let themeCreatorPresented = app.showThemeCreator
        let tierCreatorPresented = app.showTierListCreator
        let quickMovePresented = app.quickMoveTarget != nil
        let aiChatPresented = app.showAIChat && AppleIntelligenceService.isSupportedOnCurrentPlatform
        // Note: ThemePicker, TierListBrowser, and Analytics now use .fullScreenCover()
        // which provides automatic focus containment via separate presentation context
        #if os(tvOS)
        let modalBlockingFocus = headToHeadPresented
            || detailPresented
            || themeCreatorPresented
            || quickMovePresented
            || app.showThemePicker
            || tierCreatorPresented
            || aiChatPresented
        #else
        let modalBlockingFocus = detailPresented
            || headToHeadPresented
            || themeCreatorPresented
            || tierCreatorPresented
            || aiChatPresented
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
        .onExitCommand { handleBackCommand() }
        #endif
        .overlay {
            // Compose overlays here so they appear on all platforms (including tvOS)
            ZStack { overlayStack }
        }
        #if !os(tvOS)
        .overlay(alignment: .topLeading) {
            Button(action: { handleBackCommand() }, label: {
                EmptyView()
            })
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        #endif
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
        if app.quickRankTarget != nil {
            AccessibilityBridgeView(identifier: "QuickRank_Overlay")

            QuickRankOverlay(app: app)
                .zIndex(40)
        }

        #if os(tvOS)
        // Quick Move overlay (unified item actions overlay)
        QuickMoveOverlay(app: app)
            .zIndex(45)
        #endif

        // Head-to-Head overlay
        if app.h2hActive {
            AccessibilityBridgeView(identifier: "MatchupOverlay_Root")

            MatchupArenaOverlay(app: app)
                .zIndex(40)
        }

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

        // AI Chat overlay
        if app.showAIChat && AppleIntelligenceService.isSupportedOnCurrentPlatform {
            AccessibilityBridgeView(identifier: "AIChat_Overlay")

            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .onTapGesture {
                        app.closeAIChat()
                    }

                AIChatOverlay()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(55)
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
            SidebarView(tierOrder: app.tierOrder)
                .allowsHitTesting(!modalBlockingFocus)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .toolbar { ToolbarView(app: app) }
                .navigationTitle("Tiercade")
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarRole(.editor)
    }
    #endif

    #if os(iOS)
    @ViewBuilder
    private func regularWidthSplitView(modalBlockingFocus: Bool) -> some View {
        NavigationSplitView {
            SidebarView(tierOrder: app.tierOrder)
                .allowsHitTesting(!modalBlockingFocus)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .toolbar { ToolbarView(app: app) }
                .navigationTitle("Tiercade")
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarRole(.editor)
    }

    @ViewBuilder
    private func compactStack(modalBlockingFocus: Bool) -> some View {
        NavigationStack {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .navigationTitle("Tiercade")
        }
        .toolbarRole(.automatic)
        .toolbar { ToolbarView(app: app) }
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
        ZStack {
            // Grid content - no focus section on Catalyst for keyboard navigation
            #if os(tvOS)
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .focusSection()
            #else
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
            #endif

            // Toolbar overlay (already has its own focus section)
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

            // Action bar - no focus section on Catalyst for keyboard navigation
            #if os(tvOS)
            TVActionBar(app: app, glassNamespace: glassNamespace)
                .environment(\.editMode, $editMode)
                .allowsHitTesting(!modalBlockingFocus)
                .accessibilityElement(children: .contain)
                .focusSection()
            #else
            TVActionBar(app: app, glassNamespace: glassNamespace)
                .environment(\.editMode, $editMode)
                .allowsHitTesting(!modalBlockingFocus)
                .accessibilityElement(children: .contain)
            #endif
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
        NavigationStack {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .navigationTitle("Tiercade")
        }
        .toolbarRole(.automatic)
        .toolbar { ToolbarView(app: app) }
    }
    #endif
}

private extension MainAppView {
    func handleBackCommand() {
        if handleOverlayDismissals() { return }
        if handleQuickActionDismissals() { return }
        if handleCreatorDismissals() { return }
        if handleModeDismissals() { return }
    }

    private func handleOverlayDismissals() -> Bool {
        if app.showAIChat {
            app.closeAIChat()
            return true
        }
        if app.showingTierListBrowser {
            app.dismissTierListBrowser()
            return true
        }
        if app.showAnalyticsSidebar {
            app.closeAnalyticsSidebar()
            return true
        }
        return false
    }

    private func handleQuickActionDismissals() -> Bool {
        if app.quickRankTarget != nil {
            app.cancelQuickRank()
            return true
        }
        if app.quickMoveTarget != nil {
            app.cancelQuickMove()
            return true
        }
        if app.h2hActive {
            app.cancelH2H(fromExitCommand: true)
            return true
        }
        return false
    }

    private func handleCreatorDismissals() -> Bool {
        if app.showThemeCreator {
            app.cancelThemeCreation(returnToThemePicker: false)
            return true
        }
        if app.showTierListCreator {
            app.cancelTierListCreator()
            return true
        }
        return false
    }

    private func handleModeDismissals() -> Bool {
        if app.detailItem != nil {
            app.detailItem = nil
            return true
        }
        if editMode == .active {
            editMode = .inactive
            app.clearSelection()
            return true
        }
        return false
    }
}

// Small preview
#Preview("Main") { MainAppView() }

// File-scoped helper to expose an immediate accessibility element for UI tests.
private struct AccessibilityBridgeView: View {
    internal let identifier: String

    internal init(identifier: String = "ThemePicker_Overlay") {
        self.identifier = identifier
    }

    internal var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .accessibilityHidden(false)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
    }
}

#if os(tvOS)
// Simple tvOS-friendly toolbar exposing essential actions as buttons.
#endif
