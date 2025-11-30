import SwiftUI
import TiercadeCore
#if os(tvOS)
import Foundation
#endif

// MARK: - MainAppView

// MainAppView: Top-level composition that was split out during modularization.
// It composes SidebarView, TierGridView, ToolbarView and overlays (from the
// ContentView+*.swift modular files).

struct MainAppView: View {

    // MARK: Internal

    var body: some View {
        @Bindable var app = app
        // Note: Modal overlays (ThemePicker, TierListBrowser, HeadToHead, Analytics)
        // use .fullScreenCover() which provides automatic focus containment via separate
        // presentation context. This follows Apple's recommended pattern for modal presentations.
        // Use centralized overlay blocking check from AppState for remaining ZStack overlays
        let modalBlockingFocus = app.blocksBackgroundFocus

        platformContent(modalBlockingFocus: modalBlockingFocus)
        #if os(iOS) || os(tvOS)
            .environment(\.editMode, $editMode)
        #endif
        #if os(tvOS)
        .task { FocusUtils.seedFocus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                FocusUtils.seedFocus()
            }
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
        .applyDetailSheet(app: app)
            .applyAlerts(app: app)
            .applyModalPresentations(app: app)
    }

    // MARK: Private

    @Environment(AppState.self) private var app: AppState
    #if os(iOS) || os(tvOS)
    @State private var editMode: EditMode = .inactive
    #endif
    #if os(tvOS)
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var detailFocus: DetailFocus?
    enum DetailFocus: Hashable { case close }
    @Namespace private var glassNamespace
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    // MARK: - Overlay Composition

    @ViewBuilder
    private var overlayStack: some View {
        if app.isLoading {
            ProgressIndicatorView(
                isLoading: app.isLoading,
                message: app.loadingMessage,
                progress: app.operationProgress,
            )
            .zIndex(OverlayZIndex.progress)
        }

        // Quick Rank overlay (tvOS only - other platforms use modal)
        #if os(tvOS)
        if app.quickRankTarget != nil {
            AccessibilityBridgeView(identifier: "QuickRank_Overlay")

            QuickRankOverlay(app: app)
                .zIndex(OverlayZIndex.standardOverlay)
        }
        #endif

        if app.headToHead.isActive {
            AccessibilityBridgeView(identifier: "HeadToHeadOverlay_Root")
        }

        // Note: TierMove, HeadToHead, AnalyticsSidebar, TierListBrowser,
        // and ThemePicker are presented as fullScreenCover modals for proper focus containment
        // (see modal presentations after body)

        if app.aiGeneration.showAIChat, AIGenerationState.isSupportedOnCurrentPlatform {
            AccessibilityBridgeView(identifier: "AIChat_Overlay")

            ZStack {
                Palette.bg.opacity(0.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .accessibilityHidden(true) // Dimmer is tap-to-dismiss; explicit close button exists in overlay
                    .onTapGesture {
                        app.closeAIChat()
                    }

                AIChatOverlay(ai: app.aiGeneration)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(OverlayZIndex.modalOverlay)
        }

        if let toast = app.currentToast {
            VStack {
                Spacer()
                ToastView(toast: toast)
                    .padding()
            }
            .zIndex(OverlayZIndex.toast)
        }

        if let detail = app.overlays.detailItem {
            detailOverlay(for: detail)
        }

        // Accessibility bridge for Tier Move sheet across platforms.
        // Ensures immediate accessibility presence instead of attaching IDs to containers.
        if app.overlays.quickMoveTarget != nil {
            AccessibilityBridgeView(identifier: "TierMove_Sheet")
        }

        // Accessibility bridge for Theme Picker overlay.
        if app.overlays.showThemePicker {
            AccessibilityBridgeView(identifier: "ThemePicker_Overlay")
        }
    }

    // MARK: - Content Helpers

    @ViewBuilder
    private func platformContent(modalBlockingFocus: Bool) -> some View {
        Group {
            #if os(tvOS)
            tvOSPrimaryContent(modalBlockingFocus: modalBlockingFocus)
            #elseif os(macOS)
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
                .combined(with: .opacity),
        )
        .zIndex(OverlayZIndex.detailSidebar)
        #endif
    }

    // MARK: - Platform Navigation Structures

    #if os(macOS)
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
        #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                BuildInfoView()
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        #endif
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
                .navigationTitle("Tiercade")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarView(app: app) }
                .toolbarTitleMenu {
                    ToolbarView(app: app).titleMenuContent
                }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarRole(.editor)
        #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                BuildInfoView()
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        #endif
    }

    @ViewBuilder
    private func compactStack(modalBlockingFocus: Bool) -> some View {
        NavigationStack {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .navigationTitle("Tiercade")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarView(app: app) }
                .toolbarTitleMenu {
                    ToolbarView(app: app).titleMenuContent
                }
                .toolbarRole(.automatic)
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
                BuildInfoView()
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        #endif
    }
    #endif

    // MARK: - Platform Specific Content

    @ViewBuilder
    private func tierGridLayer(modalBlockingFocus: Bool) -> some View {
        TierGridView(tierOrder: app.tierOrder)
            .environment(app)
        #if os(iOS)
            .environment(\.editMode, $editMode)
            .padding(.top, Metrics.grid * 2) // Reduced for iOS to avoid nav bar overlap
            .padding(.bottom, Metrics.grid * 3)
        #elseif os(tvOS)
            .padding(.top, TVMetrics.contentTopInset)
            .padding(.bottom, TVMetrics.contentBottomInset)
        #else
            .padding(.top, Metrics.grid * 2)
            .padding(.bottom, Metrics.grid * 3)
        #endif
            .allowsHitTesting(!modalBlockingFocus)
            // Note: Don't use .disabled() as it removes elements from accessibility tree
            // Only block hit testing when modals are active
            .frame(maxWidth: .infinity, alignment: .top) // Removed maxHeight to let NavigationStack manage sizing
    }

    #if os(tvOS)
    @ViewBuilder
    private func tvOSPrimaryContent(modalBlockingFocus: Bool) -> some View {
        ZStack {
            tierGridLayer(modalBlockingFocus: modalBlockingFocus)
                .focusSection()
        }
        .overlay(alignment: .top) {
            TVToolbarView(
                app: app,
                modalActive: modalBlockingFocus,
                editMode: $editMode,
                glassNamespace: glassNamespace,
            )
            .frame(maxWidth: .infinity)
            .frame(height: TVMetrics.topBarHeight)
            .allowsHitTesting(!modalBlockingFocus)
            .accessibilityElement(children: .contain)
        }
        .overlay(alignment: .bottom) {
            // Action bar pinned to bottom edge (shown in edit mode)
            TVActionBar(app: app, glassNamespace: glassNamespace)
                .environment(\.editMode, $editMode)
                .allowsHitTesting(!modalBlockingFocus)
                .accessibilityElement(children: .contain)
                .focusSection()
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

extension MainAppView {
    private func handleBackCommand() {
        if handleOverlayDismissals() {
            return
        }
        if handleQuickActionDismissals() {
            return
        }
        if handleCreatorDismissals() {
            return
        }
        if handleModeDismissals() {
            return
        }
    }

    private func handleOverlayDismissals() -> Bool {
        if app.aiGeneration.showAIChat {
            app.closeAIChat()
            return true
        }
        if app.overlays.showThemePicker {
            app.dismissThemePicker()
            return true
        }
        if app.overlays.showTierListBrowser {
            app.dismissTierListBrowser()
            return true
        }
        if app.overlays.showAnalyticsSidebar {
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
        if app.overlays.quickMoveTarget != nil {
            app.cancelQuickMove()
            return true
        }
        if app.headToHead.isActive {
            app.cancelHeadToHead(fromExitCommand: true)
            return true
        }
        return false
    }

    private func handleCreatorDismissals() -> Bool {
        if app.overlays.showThemeCreator {
            app.cancelThemeCreation(returnToThemePicker: false)
            return true
        }
        if app.overlays.showTierListCreator {
            app.cancelTierListCreator()
            return true
        }
        return false
    }

    private func handleModeDismissals() -> Bool {
        if app.overlays.detailItem != nil {
            app.overlays.detailItem = nil
            return true
        }
        #if os(iOS) || os(tvOS)
        if editMode == .active {
            editMode = .inactive
            app.clearSelection()
            return true
        }
        #endif
        return false
    }
}

// MARK: - MainAppViewPreview

@MainActor
private struct MainAppViewPreview: View {
    private let appState = AppState(inMemory: true)

    var body: some View {
        MainAppView()
            .environment(appState)
    }
}

#Preview("Main – Light") {
    MainAppViewPreview()
        .preferredColorScheme(.light)
}

#Preview("Main – Dark") {
    MainAppViewPreview()
        .preferredColorScheme(.dark)
}

// MARK: - AccessibilityBridgeView

// File-scoped helper to expose an immediate accessibility element for UI tests.
private struct AccessibilityBridgeView: View {
    let identifier: String

    init(identifier: String = "ThemePicker_Overlay") {
        self.identifier = identifier
    }

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .accessibilityHidden(false)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
    }
}
