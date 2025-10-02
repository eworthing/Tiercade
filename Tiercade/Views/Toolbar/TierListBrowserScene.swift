import SwiftUI

struct TierListBrowserScene: View {
    @Bindable var app: AppState
    @FocusState private var focusedHandleID: String?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 32),
        GridItem(.flexible(), spacing: 32)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 28) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        if !recentHandles.isEmpty {
                            sectionHeader(title: "Recent")
                            cardsGrid(for: recentHandles)
                        }

                        sectionHeader(title: "Bundled Library")
                        cardsGrid(for: bundledHandles)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .padding(48)
            .frame(maxWidth: 1680, maxHeight: 920)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(Palette.surface.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 32, y: 18)
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("TierListBrowser_Overlay")
            .defaultFocus($focusedHandleID, defaultFocusID)
            #if os(tvOS)
            .focusSection()
            #endif
        }
        #if os(tvOS)
        .onExitCommand {
            app.dismissTierListBrowser()
        }
        #endif
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tier List Browser")
                    .font(TypeScale.h2)
                Text("Switch to another list or load a bundled project with full previews.")
                    .font(.callout)
                    .foregroundStyle(Palette.textDim)
            }

            Spacer()

            Button("Close") {
                app.dismissTierListBrowser()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("TierListBrowser_CloseButton")
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.textDim)
    }

    private func cardsGrid(for handles: [AppState.TierListHandle]) -> some View {
        LazyVGrid(columns: columns, spacing: 28) {
            ForEach(handles) { handle in
                TierListCard(
                    handle: handle,
                    isActive: handle == app.activeTierList
                ) {
                    select(handle)
                }
                .focused($focusedHandleID, equals: handle.id)
            }
        }
    }

    private func select(_ handle: AppState.TierListHandle) {
        Task {
            await app.selectTierList(handle)
            app.dismissTierListBrowser()
        }
    }

    private var recentHandles: [AppState.TierListHandle] {
        app.recentTierLists
    }

    private var bundledHandles: [AppState.TierListHandle] {
        // Show all bundled projects, not just those not in recent
        return app.bundledProjects
            .map(AppState.TierListHandle.init(bundled:))
    }

    private var defaultFocusID: String? {
        if let active = app.activeTierList?.id {
            return active
        }
        if let firstRecent = recentHandles.first?.id {
            return firstRecent
        }
        return bundledHandles.first?.id
    }
}

private struct TierListCard: View {
    let handle: AppState.TierListHandle
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Palette.brand)
                        .frame(width: 52, height: 52)
                        .background(cardIconBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(handle.displayName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(2)
                        if let subtitle = handle.subtitle {
                            Text(subtitle)
                                .font(.callout)
                                .foregroundStyle(Palette.textDim)
                        }
                    }
                    Spacer(minLength: 0)
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .foregroundStyle(Color.green)
                            .accessibilityLabel("Currently active tier list")
                    }
                }

                Text(metadataDescription)
                    .font(.footnote)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(3)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        #if os(tvOS)
        .buttonStyle(.tvRemote(.primary))
        #else
        .buttonStyle(.borderedProminent)
        #endif
        .accessibilityIdentifier("TierListCard_\(handle.id)")
    }

    private var iconName: String {
        switch handle.source {
        case .bundled:
            return handle.iconSystemName ?? "square.grid.2x2"
        case .file:
            return handle.iconSystemName ?? "externaldrive"
        }
    }

    private var metadataDescription: String {
        switch handle.source {
        case .bundled:
            return "Bundled tier list • Offline ready"
        case .file:
            return "Local save file • Stored on this Apple TV"
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isActive ? 0.26 : 0.15),
                        Color.white.opacity(isActive ? 0.18 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isActive ? Palette.brand : Color.white.opacity(0.12), lineWidth: isActive ? 3 : 1)
            )
    }

    private var cardIconBackground: some ShapeStyle {
        LinearGradient(
            colors: [Palette.brand.opacity(0.18), Palette.brand.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
