import SwiftUI

// MARK: - View Modifier Extensions for Modal Presentations

extension View {
    @ViewBuilder
    func applyDetailSheet(app: AppState) -> some View {
        self
        #if !os(tvOS)
        .sheet(item: Binding(
            get: { app.overlays.detailItem },
            set: { app.overlays.detailItem = $0 },
        )) { detail in
            NavigationStack {
                DetailView(item: detail)
                    .navigationTitle(detail.name ?? detail.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { app.overlays.detailItem = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        #endif
    }

    @ViewBuilder
    func applyAlerts(app: AppState) -> some View {
        alert("Randomize Tiers?", isPresented: Binding(
            get: { app.showRandomizeConfirmation },
            set: { app.showRandomizeConfirmation = $0 },
        )) {
            Button("Cancel", role: .cancel) { app.showRandomizeConfirmation = false }
            Button("Randomize", role: .destructive) {
                app.showRandomizeConfirmation = false
                app.performRandomize()
            }
        } message: {
            Text("This will randomly redistribute all items across tiers.")
        }
        .alert("Reset Tier List?", isPresented: Binding(
            get: { app.showResetConfirmation },
            set: { app.showResetConfirmation = $0 },
        )) {
            Button("Cancel", role: .cancel) { app.showResetConfirmation = false }
            Button("Reset", role: .destructive) {
                app.showResetConfirmation = false
                app.performReset(showToast: true)
            }
        } message: {
            Text("This will delete all items and reset the tier list. This action cannot be undone.")
        }
    }

    @ViewBuilder
    func applyModalPresentations(app: AppState) -> some View {
        applyTierListCreatorModal(app: app)
            .applyAnalysisModal(app: app)
            .applyFocusContainedModals(app: app)
            .applyAnalyticsSidebarModal(app: app)
            .applyThemeCreatorAndMoveModals(app: app)
            .applyDebugModals(app: app)
    }

    // MARK: - Modal Presentation Helpers

    @ViewBuilder
    func applyTierListCreatorModal(app: AppState) -> some View {
        #if os(macOS)
        sheet(isPresented: Binding(
            get: { app.overlays.showTierListCreator },
            set: { app.overlays.showTierListCreator = $0 },
        )) {
            if let draft = app.tierListCreatorDraft {
                TierListProjectWizard(appState: app, draft: draft, context: app.tierListWizardContext)
            }
        }
        #else
        fullScreenCover(isPresented: Binding(
            get: { app.overlays.showTierListCreator },
            set: { app.overlays.showTierListCreator = $0 },
        )) {
            if let draft = app.tierListCreatorDraft {
                TierListProjectWizard(appState: app, draft: draft, context: app.tierListWizardContext)
            }
        }
        #endif
    }

    @ViewBuilder
    func applyAnalysisModal(app: AppState) -> some View {
        #if !os(tvOS)
        sheet(isPresented: Binding(
            get: { app.showingAnalysis },
            set: { app.showingAnalysis = $0 },
        )) {
            AnalysisView(app: app)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyFocusContainedModals(app: AppState) -> some View {
        #if os(macOS)
        sheet(isPresented: Binding(
            get: { app.overlays.showTierListBrowser },
            set: { app.overlays.showTierListBrowser = $0 },
        )) {
            TierListBrowserScene(app: app)
        }
        .sheet(isPresented: Binding(
            get: { app.overlays.showThemePicker },
            set: { app.overlays.showThemePicker = $0 },
        )) {
            ThemeLibraryOverlay()
        }
        .sheet(isPresented: Binding(
            get: { app.headToHead.isActive },
            set: { if !$0 {
                app.cancelHeadToHead()
            } },
        )) {
            HeadToHeadOverlay(app: app)
        }
        #else
        fullScreenCover(isPresented: Binding(
            get: { app.overlays.showTierListBrowser },
            set: { app.overlays.showTierListBrowser = $0 },
        )) {
            TierListBrowserScene(app: app)
        }
        .fullScreenCover(isPresented: Binding(
            get: { app.overlays.showThemePicker },
            set: { app.overlays.showThemePicker = $0 },
        )) {
            ThemeLibraryOverlay()
        }
        .fullScreenCover(isPresented: Binding(
            get: { app.headToHead.isActive },
            set: { if !$0 {
                app.cancelHeadToHead()
            } },
        )) {
            HeadToHeadOverlay(app: app)
        }
        #endif
    }

    @ViewBuilder
    func applyAnalyticsSidebarModal(app: AppState) -> some View {
        #if os(tvOS)
        fullScreenCover(isPresented: Binding(
            get: { app.overlays.showAnalyticsSidebar },
            set: { app.overlays.showAnalyticsSidebar = $0 },
        )) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                AnalyticsSidebarView()
                    .frame(maxHeight: .infinity)
            }
        }
        .fullScreenCover(item: Binding(
            get: { app.overlays.quickMoveTarget },
            set: { app.overlays.quickMoveTarget = $0 },
        )) { _ in
            TierMoveSheet(app: app)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyThemeCreatorAndMoveModals(app: AppState) -> some View {
        #if os(macOS)
        sheet(isPresented: Binding(
            get: { app.overlays.showThemeCreator },
            set: { app.overlays.showThemeCreator = $0 },
        )) {
            if let draft = app.theme.themeDraft {
                ThemeCreatorOverlay(appState: app, draft: draft)
            }
        }
        .sheet(item: Binding(
            get: { app.overlays.quickMoveTarget },
            set: { app.overlays.quickMoveTarget = $0 },
        )) { _ in
            TierMoveSheet(app: app)
        }
        .sheet(item: Binding(
            get: { app.quickRankTarget },
            set: { app.quickRankTarget = $0 },
        )) { _ in
            QuickRankOverlay(app: app)
        }
        #else
        fullScreenCover(isPresented: Binding(
            get: { app.overlays.showThemeCreator },
            set: { app.overlays.showThemeCreator = $0 },
        )) {
            if let draft = app.theme.themeDraft {
                ThemeCreatorOverlay(appState: app, draft: draft)
            }
        }
        .fullScreenCover(item: Binding(
            get: { app.overlays.quickMoveTarget },
            set: { app.overlays.quickMoveTarget = $0 },
        )) { _ in
            TierMoveSheet(app: app)
        }
        .fullScreenCover(item: Binding(
            get: { app.quickRankTarget },
            set: { app.quickRankTarget = $0 },
        )) { _ in
            QuickRankOverlay(app: app)
        }
        #endif
    }

    @ViewBuilder
    func applyDebugModals(app: AppState) -> some View {
        #if DEBUG
        sheet(isPresented: Binding(
            get: { app.showDesignDemo },
            set: { app.showDesignDemo = $0 },
        )) {
            TierMoveDesignDemo()
        }
        #else
        self
        #endif
    }
}
