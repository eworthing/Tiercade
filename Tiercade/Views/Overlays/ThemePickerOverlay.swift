import SwiftUI
import TiercadeCore

/// Theme picker overlay for tvOS
/// Displays theme options in a grid with live preview
struct ThemePickerOverlay: View {
    @Bindable var appState: AppState
    @FocusState private var focus: ThemePickerFocus?
    @State private var lastFocus: ThemePickerFocus = .card(0)
    @State private var suppressFocusReset = false

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: TVMetrics.cardSpacing),
            GridItem(.flexible(), spacing: TVMetrics.cardSpacing)
        ]
    }

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
                    LazyVGrid(columns: gridColumns, spacing: TVMetrics.cardSpacing) {
                        ForEach(Array(focusableThemes.enumerated()), id: \.offset) { idx, theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: appState.selectedTheme == theme,
                                isFocused: focus == .card(idx)
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    appState.applyTheme(theme)
                                }
                            }
                            .focused($focus, equals: .card(idx))
                            .accessibilityIdentifier("ThemeCard_\(theme.slug)")
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
            .onAppear {
                appState.themePickerActive = true
                suppressFocusReset = false
                let targetIndex = defaultFocusedIndex
                let targetFocus: ThemePickerFocus = .card(targetIndex)
                lastFocus = targetFocus
                focus = targetFocus
            }
            .onDisappear {
                suppressFocusReset = true
                focus = nil
                appState.themePickerActive = false
            }
            .onExitCommand {
                appState.dismissThemePicker()
            }
            .onChange(of: focus) { _, newValue in
                guard !suppressFocusReset else { return }
                if let newValue {
                    lastFocus = newValue
                } else {
                    focus = lastFocus
                }
            }
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
            .focused($focus, equals: .close)
            .accessibilityLabel("Close theme picker")
            .accessibilityIdentifier("ThemePicker_Close")
        }
        .padding(TVMetrics.overlayPadding)
        .background(.thinMaterial)
        #if os(tvOS)
        .focusSection()
        #endif
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

            Spacer()

            Text("Current: \(appState.selectedTheme.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(TVMetrics.overlayPadding)
        .background(.thinMaterial)
    }

    private var focusableThemes: [TierTheme] {
        TierThemeCatalog.allThemes
    }

    private var defaultFocusedIndex: Int {
        focusableThemes.firstIndex(of: appState.selectedTheme) ?? 0
    }

    private enum ThemePickerFocus: Hashable {
        case card(Int)
        case close
    }
}

/// Individual theme card with color preview
private struct ThemeCard: View {
    let theme: TierTheme
    let isSelected: Bool
    let isFocused: Bool
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
                    ForEach(Array(theme.previewTiers), id: \.id) { tier in
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
