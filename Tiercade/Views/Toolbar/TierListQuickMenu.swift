import SwiftUI

struct TierListQuickMenu: View {
    private typealias TierListHandle = AppState.TierListHandle
    @Bindable var app: AppState

    var body: some View {
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
        if app.quickPickTierLists.isEmpty {
            Text("No tier lists available")
        } else {
            ForEach(app.quickPickTierLists) { handle in
                quickPickButton(for: handle)
            }
        }

        Divider()

        Button("Browse All Lists…") {
            app.presentTierListBrowser()
        }
#if !os(tvOS)
        .keyboardShortcut(.downArrow, modifiers: [])
#endif
    }

    private var menuLabel: some View {
        #if os(tvOS)
        VStack(spacing: 10) {
            Text("Tier Library")
                .font(TypeScale.body)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.textDim)

            HStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 38, weight: .semibold))

                Text(app.activeTierDisplayName)
                    .font(TypeScale.h3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("Toolbar_TierListMenu_Title")
            }
            .foregroundStyle(Palette.text)

            Text("Browse bundled & saved lists")
                .font(TypeScale.label)
                .fontWeight(.semibold)
                .foregroundStyle(Palette.textDim)
                .opacity(0.9)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 44)
        .padding(.vertical, 22)
        .frame(minWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        #else
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 22, weight: .semibold))
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

    private func quickPickButton(for handle: TierListHandle) -> some View {
        Button {
            guard handle != app.activeTierList else { return }
            Task { await app.selectTierList(handle) }
        } label: {
            quickPickLabel(for: handle)
        }
        .disabled(handle == app.activeTierList)
    }

    private func quickPickLabel(for handle: TierListHandle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: handle))
            VStack(alignment: .leading, spacing: 2) {
                Text(handle.displayName)
                    .font(.body.weight(handle == app.activeTierList ? .semibold : .regular))
                if let subtitle = handle.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if handle == app.activeTierList {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
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
        }
    }
}
