import SwiftUI
import TiercadeCore

/// Theme picker overlay for tvOS
/// Displays theme options in a grid with live preview
struct ThemePickerOverlay: View {
    @Bindable var appState: AppState
    @Namespace private var focusNamespace
    @FocusState private var focusedElement: FocusElement?

    private let columns = 2

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.dismissThemePicker()
                }

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: TVMetrics.cardSpacing),
                            GridItem(.flexible(), spacing: TVMetrics.cardSpacing)
                        ],
                        spacing: TVMetrics.cardSpacing
                    ) {
                        ForEach(focusableThemes, id: \.self) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: appState.selectedTheme == theme,
                                isFocused: focusedTheme == theme,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.applyTheme(theme)
                                    }
                                }
                            )
                            .focused($focusedElement, equals: .theme(theme))
                            .accessibilityIdentifier("ThemeCard_\(theme.rawValue)")
                        }
                    }
                    .padding(TVMetrics.overlayPadding)
                }

                footerSection
            }
            .frame(maxWidth: 1200, maxHeight: 900)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius))
            .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
            .accessibilityIdentifier("ThemePicker_Overlay")
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
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
                appState.dismissThemePicker()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close theme picker")
            .accessibilityIdentifier("ThemePicker_Close")
            .focused($focusedElement, equals: .close)
        }
        .padding(TVMetrics.overlayPadding)
        .background(.thinMaterial)
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

            Spacer()

            Text("Current: \(appState.selectedTheme.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(TVMetrics.overlayPadding)
        .background(.thinMaterial)
    }

    private var focusableThemes: [TierTheme] {
        TierTheme.allCases
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
        guard let focused = focusedElement else { return }

        switch focused {
        case .theme(let theme):
            handleThemeMove(direction, theme: theme)
        case .close:
            handleCloseMove(direction)
        case .reset:
            handleResetMove(direction)
        }
    }

    private func handleThemeMove(_ direction: MoveCommandDirection, theme: TierTheme) {
        if direction == .up, isTopRow(theme) {
            focusedElement = .close
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
        case .up, .left, .right:
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
    }
}

/// Individual theme card with color preview
private struct ThemeCard: View {
    let theme: TierTheme
    let isSelected: Bool
    let isFocused: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let previewTiers = ["S", "A", "B", "C"]

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(theme.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        Spacer()

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
                    ForEach(previewTiers, id: \.self) { tier in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.swiftUIColor(for: tier))
                                .frame(height: 60)
                                .overlay(
                                    Text(tier)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(
                                            ColorUtilities.accessibleTextColor(
                                                onBackground: theme.color(for: tier)
                                            )
                                        )
                                )
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 4
                            )
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

#if DEBUG
#Preview("Theme Picker") {
    @Previewable @State var appState = AppState()
    ThemePickerOverlay(appState: appState)
}
#endif
