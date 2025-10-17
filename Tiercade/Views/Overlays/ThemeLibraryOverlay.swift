import SwiftUI
import TiercadeCore

@MainActor
struct ThemeLibraryOverlay: View {
    @Environment(AppState.self) private var appState
    @Namespace private var glassNamespace
    @FocusState private var focusedThemeID: TierTheme.ID?

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

    var body: some View {
        ZStack {
            scrim
            overlayContent
        }
        #if os(tvOS)
        .persistentSystemOverlays(.hidden)
        #endif
        .onAppear(perform: handleAppear)
        .onDisappear { appState.themePickerActive = false }
    }
}

// MARK: - Layout

private extension ThemeLibraryOverlay {
    var scrim: some View {
        Color.black.opacity(0.6)
            .ignoresSafeArea()
            .onTapGesture { appState.dismissThemePicker() }
    }

    var overlayContent: some View {
        VStack {
            chrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, platformOverlayPadding / 3)
        .accessibilityIdentifier("ThemePicker_Overlay")
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        #if os(tvOS)
        .focusSection()
        .defaultFocus($focusedThemeID, defaultFocusID)
        .onExitCommand { appState.dismissThemePicker() }
        #endif
        .onChange(of: appState.availableThemes) { ensureValidFocus() }
        .onChange(of: appState.selectedTheme.id) { assignFocusToSelectedTheme() }
    }

    @ViewBuilder
    var chrome: some View {
        let container = tvGlassContainer {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.18)
                grid
                Divider().opacity(0.18)
                footer
            }
            .frame(maxWidth: 1180)
            .padding(.vertical, platformOverlayPadding / 2)
        }

        container
            .glassEffect(
                Glass.regular.tint(Palette.surface.opacity(0.92)).interactive(),
                in: RoundedRectangle(cornerRadius: platformOverlayCornerRadius, style: .continuous)
            )
            .glassEffectID("ThemeLibraryOverlay", in: glassNamespace)
            .shadow(color: Color.black.opacity(0.35), radius: 32, y: 18)
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
                appState.beginThemeCreation(baseTheme: appState.selectedTheme)
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
                ForEach(appState.availableThemes) { theme in
                    ThemeLibraryTile(
                        theme: theme,
                        tint: tint(for: theme),
                        isSelected: appState.selectedTheme.id == theme.id,
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

                Text(appState.selectedTheme.displayName)
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
    func handleAppear() {
        appState.themePickerActive = true
        assignFocusToSelectedTheme()
    }

    func assignFocusToSelectedTheme() {
        if let target = appState.availableThemes.first(where: { $0.id == appState.selectedTheme.id }) {
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

        guard appState.availableThemes.contains(where: { $0.id == current }) else {
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
        if appState.availableThemes.contains(where: { $0.id == appState.selectedTheme.id }) {
            return appState.selectedTheme.id
        }
        return appState.availableThemes.first?.id
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
    let theme: TierTheme
    let tint: Color
    let isSelected: Bool
    let isCustom: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                header
                preview
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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
        .animation(animation, value: isFocused)
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

    private var animation: Animation {
        .easeOut(duration: 0.22)
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
    let text: String
    let tint: Color
    let textColor: Color

    var body: some View {
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
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .padding(10)
            .background(
                Circle()
                    .fill(Color.green.gradient)
                    .shadow(color: .green.opacity(0.35), radius: 12, y: 6)
            )
            .accessibilityHidden(true)
    }
}
