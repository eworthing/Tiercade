import SwiftUI

internal struct TierListQuickMenu: View {
    @Bindable var app: AppState

    #if os(tvOS)
    private var tierTitleFont: Font {
        let nameLength = app.activeTierDisplayName.count
        return nameLength <= 16 ? TypeScale.h2 : TypeScale.h3
    }
    #endif

    internal var body: some View {
        #if os(tvOS)
        // tvOS doesn't support Menu dropdowns; use direct button to browser
        Button(action: {
            app.presentTierListBrowser()
        }, label: {
            menuLabel
        })
        .buttonStyle(.tvRemote(.primary))
        .accessibilityIdentifier("Toolbar_TierListMenu")
        .accessibilityLabel("Tier list picker")
        .accessibilityHint("Choose a saved or bundled tier list")
        #else
        Menu {
            menuContent
        } label: {
            menuLabel
        }
        .accessibilityIdentifier("Toolbar_TierListMenu")
        .accessibilityLabel("Tier list picker")
        .accessibilityHint("Choose a saved or bundled tier list")
        #endif
    }

    @ViewBuilder
    private var menuContent: some View {
        if app.quickPickTierListsDeduped.isEmpty {
            Text("No tier lists available")
        } else {
            // Use Picker for selection with checkmark pattern (Apple HIG)
            Picker("Tier List", selection: Binding(
                get: { app.persistence.activeTierList },
                set: { newValue in
                    guard let newValue, newValue != app.persistence.activeTierList else { return }
                    Task { await app.selectTierList(newValue) }
                }
            )) {
                ForEach(app.quickPickTierListsDeduped) { handle in
                    Label(handle.displayName, systemImage: iconName(for: handle))
                        .tag(handle as TierListHandle?)
                }
            }
            .pickerStyle(.inline)
            #if os(iOS)
            .menuOrder(.fixed)
            #endif
        }

        Divider()

        Button("Create New Tier List…") {
            app.presentTierListCreator()
        }
        #if !os(tvOS)
        .keyboardShortcut("n", modifiers: [.command, .shift])
        #endif

        Button("Browse All Lists…") {
            app.presentTierListBrowser()
        }
        #if !os(tvOS)
        .keyboardShortcut(.downArrow, modifiers: [])
        #endif
    }

    private var menuLabel: some View {
        #if os(tvOS)
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: Metrics.toolbarIconSize))
                .frame(width: Metrics.toolbarButtonSize, height: Metrics.toolbarButtonSize)

            Text(app.activeTierDisplayName)
                .font(tierTitleFont)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("Toolbar_TierListMenu_Title")
        }
        .foregroundStyle(Palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        #else
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(TypeScale.menuTitle)
            Text(app.activeTierDisplayName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("Toolbar_TierListMenu_Title")
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.bold))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        #endif
    }

    private func iconName(for handle: TierListHandle) -> String {
        if let icon = handle.iconSystemName {
            return icon
        }
        switch handle.source {
        case .bundled:
            return "square.grid.2x2"
        case .file:
            return "externaldrive"
        case .authored:
            return "square.and.pencil"
        }
    }
}
