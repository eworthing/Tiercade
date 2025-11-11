import SwiftUI

#if os(tvOS)
internal struct TVToolbarView: View {
    @Bindable var app: AppState
    internal var modalActive: Bool = false
    @Binding var editMode: EditMode
    internal var glassNamespace: Namespace.ID
    // Seed and manage initial focus for tvOS toolbar controls
    @FocusState private var focusedControl: Control?
    @State private var showingSortPicker = false

    private enum Control: Hashable {
        case undo, redo, randomize, reset, library, newTierList, multiSelect, headToHead, analytics, sort, applySort, density, theme, aiChat
    }

    internal var body: some View {
        let randomizeEnabled = app.canRandomizeItems
        let headToHeadEnabled = app.canStartHeadToHead
        let analyticsActive = app.overlays.showAnalyticsSidebar
        let analyticsEnabled = analyticsActive || app.canShowAnalysis
        let randomizeHint = randomizeEnabled
            ? "Randomly distribute items across tiers"
            : "Add more items before randomizing tiers"
        let randomizeTooltip = randomizeEnabled ? "Randomize" : "Add more items to randomize"
        let headToHeadHint = headToHeadEnabled
            ? "Start HeadToHead comparisons"
            : "Add at least two items before starting HeadToHead"
        let headToHeadTooltip = headToHeadEnabled ? "Start HeadToHead" : "Add two items to start"
        let analyticsHint: String = {
            if analyticsEnabled {
                return analyticsActive
                    ? "Hide analytics"
                    : "View tier distribution and balance score"
            }
            return "Add items before opening analytics"
        }()
        let analyticsTooltip = analyticsActive ? "Hide Analytics" : "Show Analytics"
        let cardDensityValue = app.cardDensityPreference
        let undoEnabled = app.canUndo
        let redoEnabled = app.canRedo
        let undoHint = undoEnabled ? "Undo last change" : "Nothing to undo"
        let redoHint = redoEnabled ? "Redo last change" : "Nothing to redo"
        HStack(spacing: 16) {
            Button(action: { app.undo() }, label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .disabled(!undoEnabled)
            .focusEffectDisabled(!undoEnabled)
            .opacity(undoEnabled ? 1 : 0.35)
            .focused($focusedControl, equals: .undo)
            .accessibilityLabel("Undo")
            .accessibilityHint(undoHint)
            .focusTooltip("Undo")

            Button(action: { app.redo() }, label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .disabled(!redoEnabled)
            .focusEffectDisabled(!redoEnabled)
            .opacity(redoEnabled ? 1 : 0.35)
            .focused($focusedControl, equals: .redo)
            .accessibilityLabel("Redo")
            .accessibilityHint(redoHint)
            .focusTooltip("Redo")

            Button(action: { app.randomize() }, label: {
                Image(systemName: "shuffle")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .disabled(!randomizeEnabled)
            .focusEffectDisabled(!randomizeEnabled)
            .opacity(randomizeEnabled ? 1 : 0.35)
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

            Spacer(minLength: TVMetrics.toolbarClusterSpacing)

            TierListQuickMenu(app: app)
                .focused($focusedControl, equals: .library)
                .focusTooltip("Tier Library")
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 520, alignment: .leading)
                .layoutPriority(1)

            Button(action: { app.presentTierListCreator() }, label: {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .focused($focusedControl, equals: .newTierList)
            .accessibilityIdentifier("Toolbar_NewTierList")
            .accessibilityLabel("New Tier List")
            .accessibilityHint("Create a custom tier list from scratch")
            .focusTooltip("New Tier List")

            Spacer(minLength: TVMetrics.toolbarClusterSpacing)

            Divider()
                .frame(height: 28)

            Button(action: {
                withAnimation(.snappy(duration: 0.18, extraBounce: 0.04)) {
                    editMode = editMode == .active ? .inactive : .active
                    if editMode == .inactive { app.clearSelection() }
                }
            }, label: {
                Image(
                    systemName: editMode == .active
                        ? "rectangle.stack.fill.badge.plus"
                        : "rectangle.stack.badge.plus"
                )
                .font(.system(size: Metrics.toolbarIconSize))
                .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_MultiSelect")
            .focused($focusedControl, equals: .multiSelect)
            .accessibilityLabel(editMode == .active ? "Exit Selection Mode" : "Multi-Select")
            .accessibilityValue(editMode == .active ? "\(app.selection.count) items selected" : "")
            .focusTooltip(editMode == .active ? "Exit Selection" : "Multi-Select")
            .onChange(of: editMode) { _, _ in
                // Keep focus on multi-select button for ANY mode change
                focusedControl = .multiSelect
            }

            Button(action: { app.startHeadToHead() }, label: {
                Image(systemName: "person.line.dotted.person.fill")
                    .font(.system(size: Metrics.toolbarIconSize * 0.9))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_HeadToHead")
            .disabled(!headToHeadEnabled)
            .focusEffectDisabled(!headToHeadEnabled)
            .opacity(headToHeadEnabled ? 1 : 0.35)
            .focused($focusedControl, equals: .headToHead)
            .accessibilityLabel("HeadToHead")
            .accessibilityHint(headToHeadHint)
            .focusTooltip(headToHeadTooltip)
            #if swift(>=6.0)
            .glassEffectID("headToHeadButton", in: glassNamespace)
            #endif

            Button(action: { app.toggleAnalyticsSidebar() }, label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_Analytics")
            .disabled(!analyticsEnabled)
            .focusEffectDisabled(!analyticsEnabled)
            .opacity(analyticsEnabled ? 1 : 0.35)
            .focused($focusedControl, equals: .analytics)
            .accessibilityLabel("Analytics")
            .accessibilityValue(analyticsActive ? "Visible" : "Hidden")
            .accessibilityHint(analyticsHint)
            .focusTooltip(analyticsTooltip)

            Button(action: { showingSortPicker = true }, label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_Sort")
            .focused($focusedControl, equals: .sort)
            .accessibilityLabel("Sort")
            .accessibilityValue(app.globalSortMode.displayName)
            .accessibilityHint("Change sort order")
            .focusTooltip("Sort: \(app.globalSortMode.displayName)")

            // Apply Sort button (conditional - only when sort is active)
            if !app.globalSortMode.isCustom {
                Button(action: {
                    app.applyGlobalSortToCustom()
                }, label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Metrics.toolbarIconSize))
                        .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
                })
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_ApplySort")
                .focused($focusedControl, equals: .applySort)
                .accessibilityLabel("Apply Sort")
                .accessibilityValue("Save \(app.globalSortMode.displayName) order as custom")
                .focusTooltip("Apply: \(app.globalSortMode.displayName)")
            }

            Button(action: { app.cycleCardDensityPreference() }, label: {
                Image(systemName: cardDensityValue.symbolName)
                    .font(.system(size: Metrics.toolbarIconSize))
                    .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
            })
            .buttonStyle(.tvRemote(.primary))
            .accessibilityIdentifier("Toolbar_CardSize")
            .focused($focusedControl, equals: .density)
            .accessibilityLabel("Card Size")
            .accessibilityValue(cardDensityValue.displayName)
            .accessibilityHint("Cycle through card density presets")
            .focusTooltip(cardDensityValue.focusTooltip)

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
            #if swift(>=6.0)
            .glassEffectID("themePickerButton", in: glassNamespace)
            #endif

            if AIGenerationState.isSupportedOnCurrentPlatform {
                Button(action: { app.toggleAIChat() }, label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: Metrics.toolbarIconSize))
                        .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)
                })
                .buttonStyle(.tvRemote(.primary))
                .accessibilityIdentifier("Toolbar_AIChat")
                .focused($focusedControl, equals: .aiChat)
                .accessibilityLabel("Apple Intelligence")
                .accessibilityHint("Chat with Apple Intelligence")
                .focusTooltip("AI Chat")
                #if swift(>=6.0)
                .glassEffectID("aiChatButton", in: glassNamespace)
                #endif
            }
        }
        .padding(.horizontal, TVMetrics.barHorizontalPadding)
        .padding(.vertical, TVMetrics.barVerticalPadding)
        .tvGlassRounded(36)
        #if swift(>=6.0)
        .glassEffectID("toolbar", in: glassNamespace)
        .glassEffectUnion(id: "tiercade.controls", namespace: glassNamespace)
        #endif
        .overlay(alignment: .bottom) {
            Divider().opacity(0.12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: TVMetrics.topBarHeight)
        .fixedSize(horizontal: false, vertical: true)
        #if os(tvOS)
        .focusSection()
        #endif
        .onChange(of: app.overlays.showAnalyticsSidebar) { _, isPresented in
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
        .sheet(isPresented: $showingSortPicker) {
            TVSortPickerOverlay(app: app, isPresented: $showingSortPicker)
        }
    }
}
#endif
