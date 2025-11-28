import SwiftUI
import TiercadeCore

@MainActor
internal struct ThemeLibraryOverlay: View {
    @Environment(AppState.self) private var appState
    @Namespace private var glassNamespace
    @FocusState private var focusedThemeID: TierTheme.ID?
    #if !os(tvOS)
    @FocusState private var overlayHasFocus: Bool
    #endif

    private var columns: [GridItem] {
        let spacing = platformCardSpacing
        return [
            GridItem(
                .flexible(minimum: 300, maximum: 420),
                spacing: spacing
            ),
            GridItem(
                .flexible(minimum: 300, maximum: 420),
                spacing: spacing
            )
        ]
    }

    internal var body: some View {
        ZStack {
            scrim
            overlayContent
        }
        #if os(tvOS)
        .persistentSystemOverlays(.hidden)
        #endif
        .onAppear(perform: handleAppear)
        .onDisappear {
            #if !os(tvOS)
            overlayHasFocus = false
            #endif
        }
        #if !os(tvOS)
        .onChange(of: overlayHasFocus) { _, newValue in
            guard !newValue else { return }
            Task { @MainActor in
                try? await Task.sleep(for: FocusWorkarounds.reassertDelay)
                guard appState.overlays.showThemePicker else { return }
                overlayHasFocus = true
            }
        }
        #endif
    }
}

// MARK: - Layout

private extension ThemeLibraryOverlay {
    var scrim: some View {
        Palette.bg.opacity(0.6)
            .ignoresSafeArea()
            .onTapGesture { appState.dismissThemePicker() }
    }

    var overlayContent: some View {
        VStack {
            chrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, platformOverlayPadding / 3)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        #if os(tvOS)
        .focusSection()
        .defaultFocus($focusedThemeID, defaultFocusID)
        .onExitCommand { appState.dismissThemePicker() }
        .onMoveCommand(perform: handleMoveCommand)
        #else
        .focusable()
        .focused($overlayHasFocus)
        .onKeyPress(.upArrow) { handleDirectionalInput(.up); return .handled }
        .onKeyPress(.downArrow) { handleDirectionalInput(.down); return .handled }
        .onKeyPress(.leftArrow) { handleDirectionalInput(.left); return .handled }
        .onKeyPress(.rightArrow) { handleDirectionalInput(.right); return .handled }
        .onKeyPress(.space) { activateFocusedTheme(); return .handled }
        .onKeyPress(.return) { activateFocusedTheme(); return .handled }
        #endif
        .onChange(of: appState.theme.availableThemes) { ensureValidFocus() }
        .onChange(of: appState.theme.selectedTheme.id) { assignFocusToSelectedTheme() }
    }

    @ViewBuilder
    var chrome: some View {
        VStack(spacing: 0) {
            // Apply glass to header chrome only
            header
                .background(
                    tvGlassContainer {
                        Color.clear
                    }
                )

            Divider().opacity(0.18)

            // Grid uses solid background for focus legibility
            grid
                .background(Palette.bg.opacity(0.70))

            Divider().opacity(0.18)

            // Apply glass to footer chrome only
            footer
                .background(
                    tvGlassContainer {
                        Color.clear
                    }
                )
        }
        .frame(maxWidth: 1180)
        .padding(.vertical, platformOverlayPadding / 2)
        .background(
            RoundedRectangle(cornerRadius: platformOverlayCornerRadius, style: .continuous)
                .fill(Palette.bg.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: platformOverlayCornerRadius, style: .continuous)
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .shadow(color: Palette.bg.opacity(0.35), radius: 32, y: 18)
    }

    var header: some View {
        HStack(alignment: .center, spacing: platformButtonSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme Library")
                    .font(TypeScale.h2)
                    .foregroundStyle(Palette.text)

                Text("Pick a Liquid Glass palette to refresh your tiers.")
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.textDim)
            }

            Spacer(minLength: 0)

            Button {
                appState.beginThemeCreation(baseTheme: appState.theme.selectedTheme)
            } label: {
                Label("Create Theme", systemImage: "paintpalette")
            }
            .accessibilityIdentifier("ThemePicker_Create")
            #if swift(>=6.0)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.borderedProminent)
            #endif
            .controlSize(.large)

            Button("Close", role: .close) {
                appState.dismissThemePicker()
            }
            .accessibilityIdentifier("ThemePicker_Close")
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif
            #if swift(>=6.0)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.borderedProminent)
            #endif
            .controlSize(.large)
        }
        .padding(.horizontal, platformOverlayPadding)
        .padding(.vertical, platformOverlayPadding / 1.5)
    }

    var grid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: platformCardSpacing) {
                ForEach(appState.theme.availableThemes) { theme in
                    ThemeLibraryTile(
                        theme: theme,
                        tint: tint(for: theme),
                        isSelected: appState.theme.selectedTheme.id == theme.id,
                        isCustom: appState.isCustomTheme(theme),
                        namespace: glassNamespace
                    ) {
                        appState.applyTheme(theme)
                    }
                    .focused($focusedThemeID, equals: theme.id)
                    .accessibilityIdentifier("ThemeCard_\(theme.slug)")
                }
            }
            .padding(.horizontal, platformOverlayPadding)
            .padding(.vertical, platformOverlayPadding / 2)
        }
        .frame(maxHeight: 640)
    }

    var footer: some View {
        HStack(spacing: platformButtonSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.resetToThemeColors()
                }
            } label: {
                Label("Reset Colors", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("ThemePicker_Reset")
            #if swift(>=6.0)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.bordered)
            #endif
            .controlSize(.large)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Current Theme")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.textDim)

                Text(appState.theme.selectedTheme.displayName)
                    .font(TypeScale.body.weight(.semibold))
                    .foregroundStyle(Palette.text)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, platformOverlayPadding)
        .padding(.vertical, platformOverlayPadding / 1.5)
    }
}

// MARK: - Focus helpers

private extension ThemeLibraryOverlay {

    #if os(tvOS)
    func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let mapped = DirectionalMove(moveCommand: direction) else { return }
        handleDirectionalInput(mapped)
    }
    #endif

    func handleDirectionalInput(_ move: DirectionalMove) {
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
        let themes = appState.theme.availableThemes
        guard !themes.isEmpty else { return }
        let columnCount = max(columns.count, 1)
        let currentId = focusedThemeID ?? defaultFocusID

        guard let currentId,
              let currentIndex = themes.firstIndex(where: { $0.id == currentId }) else {
            assignFocus(defaultFocusID)
            return
        }

        let targetIndex = calculateTargetIndex(
            move: move,
            currentIndex: currentIndex,
            themeCount: themes.count,
            columnCount: columnCount
        )

        if targetIndex != currentIndex, themes.indices.contains(targetIndex) {
            assignFocus(themes[targetIndex].id)
        }
    }

    private func calculateTargetIndex(
        move: DirectionalMove,
        currentIndex: Int,
        themeCount: Int,
        columnCount: Int
    ) -> Int {
        switch move {
        case .left:
            return handleLeftMove(currentIndex: currentIndex)
        case .right:
            return handleRightMove(currentIndex: currentIndex, themeCount: themeCount)
        case .up:
            return handleUpMove(currentIndex: currentIndex, columnCount: columnCount)
        case .down:
            return handleDownMove(currentIndex: currentIndex, themeCount: themeCount, columnCount: columnCount)
        }
    }

    private func handleLeftMove(currentIndex: Int) -> Int {
        return currentIndex > 0 ? currentIndex - 1 : currentIndex
    }

    private func handleRightMove(currentIndex: Int, themeCount: Int) -> Int {
        return currentIndex + 1 < themeCount ? currentIndex + 1 : currentIndex
    }

    private func handleUpMove(currentIndex: Int, columnCount: Int) -> Int {
        let candidate = currentIndex - columnCount
        return candidate >= 0 ? candidate : currentIndex
    }

    private func handleDownMove(currentIndex: Int, themeCount: Int, columnCount: Int) -> Int {
        let candidate = currentIndex + columnCount
        if candidate < themeCount {
            return candidate
        } else if currentIndex != themeCount - 1 {
            return themeCount - 1
        }
        return currentIndex
    }

    func activateFocusedTheme() {
        let themes = appState.theme.availableThemes
        guard let id = focusedThemeID ?? defaultFocusID,
              let theme = themes.first(where: { $0.id == id }) else { return }
        appState.applyTheme(theme)
    }

    func handleAppear() {
        assignFocusToSelectedTheme()
        #if !os(tvOS)
        overlayHasFocus = true
        #endif
    }

    func assignFocusToSelectedTheme() {
        if let target = appState.theme.availableThemes.first(where: { $0.id == appState.theme.selectedTheme.id }) {
            assignFocus(target.id)
        } else {
            assignFocus(defaultFocusID)
        }
    }

    func ensureValidFocus() {
        guard let current = focusedThemeID else {
            assignFocus(defaultFocusID)
            return
        }

        guard appState.theme.availableThemes.contains(where: { $0.id == current }) else {
            assignFocusToSelectedTheme()
            return
        }
    }

    func assignFocus(_ id: TierTheme.ID?) {
        Task { @MainActor in
            focusedThemeID = id
        }
    }

    var defaultFocusID: TierTheme.ID? {
        if appState.theme.availableThemes.contains(where: { $0.id == appState.theme.selectedTheme.id }) {
            return appState.theme.selectedTheme.id
        }
        return appState.theme.availableThemes.first?.id
    }

    func tint(for theme: TierTheme) -> Color {
        if let first = theme.rankedTiers.first {
            return ColorUtilities.color(hex: first.colorHex)
        }
        if let unranked = theme.unrankedTier {
            return ColorUtilities.color(hex: unranked.colorHex)
        }
        return Palette.brand
    }
}

// MARK: - Platform metrics

private extension ThemeLibraryOverlay {
    var platformOverlayPadding: CGFloat {
        #if os(tvOS)
        TVMetrics.overlayPadding
        #else
        Metrics.grid * 4
        #endif
    }

    var platformOverlayCornerRadius: CGFloat {
        #if os(tvOS)
        TVMetrics.overlayCornerRadius
        #else
        32
        #endif
    }

    var platformCardSpacing: CGFloat {
        #if os(tvOS)
        TVMetrics.cardSpacing
        #else
        Metrics.grid * 3
        #endif
    }

    var platformButtonSpacing: CGFloat {
        #if os(tvOS)
        TVMetrics.buttonSpacing
        #else
        Metrics.grid * 2.5
        #endif
    }
}

// MARK: - Tile

private struct ThemeLibraryTile: View {
    internal let theme: TierTheme
    internal let tint: Color
    internal let isSelected: Bool
    internal let isCustom: Bool
    internal let namespace: Namespace.ID
    internal let action: () -> Void

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    internal var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                header
                preview
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .focusable(interactions: .activate)
        #if swift(>=6.0)
        .glassEffect(
            Glass.regular.tint(tint.opacity(0.5)).interactive(),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .glassEffectID(theme.id, in: namespace)
        #else
        .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(.ultraThinMaterial)
        )
        #endif
        .overlay(alignment: .topTrailing) {
            if isSelected {
                SelectedBadge()
                    .padding(12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
        .scaleEffect(scale)
        .animation(reduceMotion ? nil : Motion.focus, value: isFocused)
        .accessibilityLabel(theme.displayName)
        .accessibilityHint(accessibilityHint)
    }

    private var borderColor: Color {
        isFocused ? tint.opacity(0.95) : .clear
    }

    private var borderWidth: CGFloat {
        isFocused ? 5 : 0
    }

    private var shadowColor: Color {
        tint.opacity(isFocused ? 0.35 : 0.15)
    }

    private var shadowRadius: CGFloat {
        isFocused ? 26 : 12
    }

    private var shadowOffset: CGFloat {
        isFocused ? 13 : 6
    }

    private var scale: CGFloat {
        isFocused ? 1.05 : 1.0
    }

    private var accessibilityHint: String {
        isSelected ? "Currently selected theme." : "Select to apply this theme."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(theme.displayName)
                    .font(TypeScale.h3)
                    .foregroundStyle(Palette.text)

                Spacer(minLength: 0)

                if isSelected {
                    ThemeStatusBadge(text: "Active", tint: tint.opacity(0.8), textColor: .white)
                } else if isCustom {
                    ThemeStatusBadge(text: "Custom", tint: Palette.surfHi, textColor: Palette.text)
                }
            }

            Text(theme.shortDescription)
                .font(TypeScale.label)
                .foregroundStyle(Palette.textDim)
                .lineLimit(2)
        }
    }

    private var preview: some View {
        HStack(spacing: 10) {
            ForEach(theme.rankedTiers) { tier in
                previewSwatch(for: tier)
            }

            if let unranked = theme.unrankedTier {
                previewSwatch(for: unranked)
            }
        }
    }

    private func previewSwatch(for tier: TierTheme.Tier) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(ColorUtilities.color(hex: tier.colorHex))
            .frame(height: 64)
            .overlay(
                Text(label(for: tier))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(
                        ColorUtilities.accessibleTextColor(onBackground: tier.colorHex)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            )
    }

    private func label(for tier: TierTheme.Tier) -> String {
        tier.isUnranked ? "UNR" : tier.name
    }
}

private struct ThemeStatusBadge: View {
    internal let text: String
    internal let tint: Color
    internal let textColor: Color

    internal var body: some View {
        Text(text)
            .font(TypeScale.label.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(tint)
            )
    }
}

private struct SelectedBadge: View {
    @Environment(AppState.self) private var app: AppState

    internal var body: some View {
        let successColor = Palette.tierColor("B", from: app.tierColors)
        Image(systemName: "checkmark.circle.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(Palette.textOnAccent)
            .padding(10)
            .background(
                Circle()
                    .fill(successColor.gradient)
                    .shadow(color: successColor.opacity(0.35), radius: 12, y: 6)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

@MainActor
private struct ThemeLibraryOverlayPreview: View {
    private let appState = PreviewHelpers.makeAppState { app in
        app.overlays.showThemePicker = true
    }

    var body: some View {
        ThemeLibraryOverlay()
            .environment(appState)
    }
}

#Preview("Theme Library – Light") {
    ThemeLibraryOverlayPreview()
        .preferredColorScheme(.light)
}

#Preview("Theme Library – Dark") {
    ThemeLibraryOverlayPreview()
        .preferredColorScheme(.dark)
}
