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
    enum DetailFocus: Hashable { case close }
    #endif

    var body: some View {
    @Bindable var app = app
    let detailPresented = app.detailItem != nil
    let headToHeadPresented = app.h2hActive
    let themeCreatorPresented = app.showThemeCreator
    let itemMenuPresented = app.itemMenuTarget != nil
    let quickMovePresented = app.quickMoveTarget != nil
    // Note: ThemePicker, TierListBrowser, and Analytics now use .fullScreenCover()
    // which provides automatic focus containment via separate presentation context
    #if os(tvOS)
    let modalBlockingFocus = headToHeadPresented || detailPresented || themeCreatorPresented || itemMenuPresented || quickMovePresented
    #else
    let modalBlockingFocus = detailPresented || headToHeadPresented || themeCreatorPresented
    #endif

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
                    .allowsHitTesting(!modalBlockingFocus)
                // Note: Don't use .disabled() as it removes elements from accessibility tree
                // Only block hit testing when modals are active
            }
            #if os(tvOS)
            // Top toolbar (overlay so it doesn't reduce content area)
            .overlay(alignment: .top) {
                TVToolbarView(app: app, modalActive: modalBlockingFocus)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: TVMetrics.topBarHeight)
                    .background(.thinMaterial)
                    .overlay(Divider().opacity(0.15), alignment: .bottom)
                    .allowsHitTesting(!modalBlockingFocus)
                    .accessibilityElement(children: .contain)
                // Note: Don't use .disabled() as it removes elements from accessibility tree
                // Only block hit testing when modals are active
            }
            // Bottom action bar (safe area inset to avoid covering focused rows)
            .overlay(alignment: .bottom) {
                TVActionBar(app: app)
                    .allowsHitTesting(!modalBlockingFocus)
                    .accessibilityElement(children: .contain)
                // Note: Don't use .disabled() as it removes elements from accessibility tree
                // Only block hit testing when modals are active
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { FocusUtils.seedFocus() }
        }
        .onExitCommand {
            if app.itemMenuTarget != nil {
                app.dismissItemMenu()
            } else if app.quickMoveTarget != nil {
                app.cancelQuickMove()
            } else if app.showThemeCreator {
                app.cancelThemeCreation(returnToThemePicker: false)
            } else if app.showingTierListBrowser {
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
                        ThemePickerOverlay(appState: app)
                            .zIndex(54)
                    } else {
                        ThemePickerOverlay(appState: app)
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
    var modalActive: Bool = false
    // Seed and manage initial focus for tvOS toolbar controls
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable {
        case undo, redo, randomize, reset, library, h2h, analytics, theme
    }

    private var buildTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "Build: \(formatter.string(from: buildDate))"
    }

    private var buildDate: Date {
        // Use compile time - this gets updated on every build
        #if DEBUG
        return Date()
        #else
        return Bundle.main.object(forInfoDictionaryKey: "BuildDate") as? Date ?? Date()
        #endif
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

            Divider()
                .frame(height: 28)

            Spacer(minLength: 28)

            TierListQuickMenu(app: app)
                .focused($focusedControl, equals: .library)
                .focusTooltip("Tier Library")

            Spacer(minLength: 28)

            Divider()
                .frame(height: 28)

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

            Spacer(minLength: 32)

            // Build timestamp for development
            Text(buildTimestamp)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(0.6)
                .fixedSize()
        }
        .padding(.horizontal, TVMetrics.barHorizontalPadding)
        .padding(.vertical, TVMetrics.barVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: TVMetrics.topBarHeight)
        .fixedSize(horizontal: false, vertical: true)
        #if os(tvOS)
        .focusSection()
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
