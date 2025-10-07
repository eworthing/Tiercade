import SwiftUI
import TiercadeCore

/// Theme picker overlay for tvOS
/// Displays theme options in a grid with live preview
struct ThemePickerOverlay: View {
    @Bindable var appState: AppState
    @Namespace private var focusNamespace
    @Namespace private var glassNamespace
    @FocusState private var focusedElement: FocusElement?
    @State private var lastFocusBeforeCreator: FocusElement?

    private let columns = 2

    var body: some View {
        ZStack {
            // Focus-trapping background: Focusable to catch stray focus and redirect back
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.dismissThemePicker()
                }
                .focusable()
                .focused($focusedElement, equals: .backgroundTrap)

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    GlassEffectContainer(spacing: TVMetrics.cardSpacing) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: TVMetrics.cardSpacing),
                                GridItem(.flexible(), spacing: TVMetrics.cardSpacing)
                            ],
                            spacing: TVMetrics.cardSpacing
                        ) {
                            ForEach(focusableThemes) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: appState.selectedTheme == theme,
                                    isFocused: focusedTheme == theme,
                                    isCustom: appState.isCustomTheme(theme),
                                    action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            appState.applyTheme(theme)
                                        }
                                    }
                                )
                                .focused($focusedElement, equals: .theme(theme))
                                .accessibilityIdentifier("ThemeCard_\(theme.slug)")
                                .suppressFocus(appState.showThemeCreator)
                            }
                        }
                    }
                    .padding(TVMetrics.overlayPadding)
                }

                footerSection
            }
            .frame(maxWidth: 1200, maxHeight: 900)
            .tvGlassRounded(TVMetrics.overlayCornerRadius)
#if swift(>=6.0)
            .glassEffectID("themePickerButton", in: glassNamespace)
            .glassEffectTransition(.matchedGeometry)
#endif
            .overlay(
                RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 38, y: 18)
            .accessibilityIdentifier("ThemePicker_Overlay")
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .allowsHitTesting(!appState.showThemeCreator)
#if os(tvOS)
            .onChange(of: appState.showThemeCreator) { isCreatorVisible in
                if isCreatorVisible {
                    lastFocusBeforeCreator = focusedElement
                    focusedElement = nil
                } else {
                    let restored = lastFocusBeforeCreator ?? .theme(defaultFocusedTheme)
                    lastFocusBeforeCreator = nil
                    focusedElement = restored
                    FocusUtils.seedFocus()
                }
            }
#endif
            .focusSection()
            .focusScope(focusNamespace)
            .defaultFocus($focusedElement, .theme(defaultFocusedTheme))
            .onAppear {
                appState.themePickerActive = true
            }
            .onDisappear {
                appState.themePickerActive = false
            }
            .onExitCommand {
                appState.dismissThemePicker()
            }
            .onMoveCommand(perform: handleMoveCommand)
        }
        #if os(tvOS)
        .persistentSystemOverlays(.hidden)
        #endif
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tier Themes")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Choose a color scheme for your tier list")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                appState.beginThemeCreation(baseTheme: appState.selectedTheme)
            } label: {
                Label("Create Theme", systemImage: "paintpalette")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("ThemePicker_Create")
            .focused($focusedElement, equals: .create)
            .suppressFocus(appState.showThemeCreator)
            .padding(.trailing, TVMetrics.buttonSpacing)

            Button("Close", role: .close) {
                appState.dismissThemePicker()
            }
            .buttonStyle(.borderedProminent)
            .focused($focusedElement, equals: .close)
            .suppressFocus(appState.showThemeCreator)
            .accessibilityIdentifier("ThemePicker_Close")
        }
        .padding(TVMetrics.overlayPadding)
        .tvGlassRounded(0)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.15)
        }
    }

    private var footerSection: some View {
        HStack(spacing: TVMetrics.buttonSpacing) {
            Button {
                withAnimation {
                    appState.resetToThemeColors()
                }
            } label: {
                Label("Reset Colors", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("ThemePicker_Reset")
            .focused($focusedElement, equals: .reset)
            .suppressFocus(appState.showThemeCreator)

            Spacer()

            Text("Current: \(appState.selectedTheme.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(TVMetrics.overlayPadding)
        .tvGlassRounded(0)
        .overlay(alignment: .top) {
            Divider().opacity(0.15)
        }
    }

    private var focusableThemes: [TierTheme] {
        appState.availableThemes
    }

    private var focusedTheme: TierTheme? {
        guard case let .theme(theme) = focusedElement else { return nil }
        return theme
    }

    private var defaultFocusedTheme: TierTheme {
        appState.selectedTheme
    }

    private var bottomRowDefaultTheme: TierTheme? {
        let startIndex = max(focusableThemes.count - columns, 0)
        guard focusableThemes.indices.contains(startIndex) else { return nil }
        return focusableThemes[startIndex]
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !appState.showThemeCreator else { return }
        guard let focused = focusedElement else { return }

        switch focused {
        case .theme(let theme):
            handleThemeMove(direction, theme: theme)
        case .close:
            handleCloseMove(direction)
        case .reset:
            handleResetMove(direction)
        case .create:
            handleCreateMove(direction)
        case .backgroundTrap:
            // Focus escaped to background - redirect back to close button
            focusedElement = .close
        }
    }

    private func handleThemeMove(_ direction: MoveCommandDirection, theme: TierTheme) {
        if direction == .up, isTopRow(theme) {
            focusedElement = isLeftColumn(theme) ? .create : .close
            return
        }

        if direction == .down, isBottomRow(theme) {
            focusedElement = .reset
            return
        }

        if direction == .left, isLeftColumn(theme) {
            focusedElement = .theme(theme)
            return
        }

        if direction == .right, isRightColumn(theme) {
            focusedElement = .theme(theme)
        }
    }

    private func handleCloseMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            focusedElement = .close
        case .left:
            focusedElement = .create
        case .right:
            focusedElement = .close
        case .down:
            focusedElement = .theme(defaultFocusedTheme)
        default:
            break
        }
    }

    private func handleResetMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .down, .left, .right:
            focusedElement = .reset
        case .up:
            if let target = bottomRowDefaultTheme {
                focusedElement = .theme(target)
            }
        default:
            break
        }
    }

    private func handleCreateMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up, .left:
            focusedElement = .create
        case .right:
            focusedElement = .close
        case .down:
            focusedElement = .theme(defaultFocusedTheme)
        default:
            break
        }
    }

    private func index(of theme: TierTheme) -> Int? {
        focusableThemes.firstIndex(of: theme)
    }

    private func isLeftColumn(_ theme: TierTheme) -> Bool {
        guard let index = index(of: theme) else { return false }
        return index % columns == 0
    }

    private func isRightColumn(_ theme: TierTheme) -> Bool {
        guard let index = index(of: theme) else { return false }
        if columns == 1 { return true }
        if index % columns == columns - 1 { return true }
        let isLastItem = index == focusableThemes.count - 1
        let hasSingleItemLastRow = focusableThemes.count % columns == 1
        return isLastItem && hasSingleItemLastRow
    }

    private func isTopRow(_ theme: TierTheme) -> Bool {
        guard let index = index(of: theme) else { return false }
        return index < columns
    }

    private func isBottomRow(_ theme: TierTheme) -> Bool {
        guard let index = index(of: theme) else { return false }
        return index >= max(focusableThemes.count - columns, 0)
    }

    private enum FocusElement: Hashable {
        case theme(TierTheme)
        case close
        case reset
        case create
        case backgroundTrap // Traps focus escaping to toolbar/grid
    }
}

/// Individual theme card with color preview
private struct ThemeCard: View {
    let theme: TierTheme
    let isSelected: Bool
    let isFocused: Bool
    let isCustom: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(theme.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Spacer()

                        if isCustom {
                            Text("Custom")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                                .foregroundColor(.white)
                        }

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    }

                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    ForEach(Array(theme.previewTiers)) { tier in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ColorUtilities.color(hex: tier.colorHex))
                                .frame(height: 60)
                                .overlay(
                                    Text(tier.name)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(
                                            ColorUtilities.accessibleTextColor(
                                                onBackground: tier.colorHex
                                            )
                                        )
                                )
                        }
                    }
                }
            }
            .padding(24)
            .tvGlassRounded(18)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 4 : 1
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.4 : 0.2),
                radius: isFocused ? 20 : 10,
                x: 0,
                y: isFocused ? 10 : 5
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

#if os(tvOS)
private struct FocusSuppressionModifier: ViewModifier {
    let isSuppressed: Bool

    func body(content: Content) -> some View {
        content.focusable(!isSuppressed)
    }
}

private extension View {
    func suppressFocus(_ suppressed: Bool) -> some View {
        modifier(FocusSuppressionModifier(isSuppressed: suppressed))
    }
}
#else
private extension View {
    func suppressFocus(_ suppressed: Bool) -> some View { self }
}
#endif

#if DEBUG
#Preview("Theme Picker") {
    @Previewable @State var appState = AppState()
    ThemePickerOverlay(appState: appState)
}
#endif
