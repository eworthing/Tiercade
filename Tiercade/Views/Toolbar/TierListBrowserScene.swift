import SwiftUI

internal struct TierListBrowserScene: View {
    @Bindable var app: AppState
    @FocusState private var focus: FocusTarget?
    #if swift(>=6.0)
    @Namespace private var glassNamespace
    #endif

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 32),
        GridItem(.flexible(), spacing: 32)
    ]

    internal var body: some View {
        ZStack {
            // Background dimming (non-interactive)
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            tvGlassContainer(spacing: 0) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    Divider()
                        .blendMode(.plusLighter)
                        .opacity(0.28)

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
                .padding(.vertical, containerVerticalPadding)
                .padding(.horizontal, containerHorizontalPadding)
            }
            .frame(maxWidth: 1680, maxHeight: 920)
            .tvGlassRounded(44)
            #if swift(>=6.0)
            .glassEffectID("tierListBrowser", in: glassNamespace)
            #endif
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.1)
            )
            .shadow(color: .black.opacity(0.38), radius: 32, y: 18)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("TierListBrowser_Overlay")
            .defaultFocus($focus, defaultFocusTarget)
            #if os(tvOS)
            .focusSection()
            #endif
            .onAppear {
                focus = defaultFocusTarget ?? .close
            }
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

            Button("Close", role: .cancel) {
                app.dismissTierListBrowser()
            }
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.borderedProminent)
            #endif
            .focused($focus, equals: .close)
            .accessibilityIdentifier("TierListBrowser_Close")
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.textDim)
    }

    private func cardsGrid(for handles: [TierListHandle]) -> some View {
        LazyVGrid(columns: columns, spacing: 28) {
            ForEach(handles) { handle in
                TierListCard(
                    handle: handle,
                    isActive: handle == app.persistence.activeTierList,
                    focusBinding: $focus,
                    openAction: { select(handle) },
                    editAction: { edit(handle) }
                )
            }
        }
    }

    private func select(_ handle: TierListHandle) {
        Task {
            await app.selectTierList(handle)
            app.dismissTierListBrowser()
        }
    }

    private func edit(_ handle: TierListHandle) {
        Task {
            await app.presentTierListEditor(for: handle)
        }
    }

    private var recentHandles: [TierListHandle] {
        app.persistence.recentTierLists
    }

    private var bundledHandles: [TierListHandle] {
        // Show all bundled projects, not just those not in recent
        return app.bundledProjects
            .map(TierListHandle.init(bundled:))
    }

    private var containerVerticalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding * 1.15
        #else
        return Metrics.grid * 5
        #endif
    }

    private var containerHorizontalPadding: CGFloat {
        #if os(tvOS)
        return TVMetrics.overlayPadding * 1.2
        #else
        return Metrics.grid * 6
        #endif
    }

    private var defaultFocusTarget: FocusTarget? {
        if let active = app.persistence.activeTierList?.id {
            return .card(active)
        }
        if let firstRecent = recentHandles.first?.id {
            return .card(firstRecent)
        }
        if let firstBundled = bundledHandles.first?.id {
            return .card(firstBundled)
        }
        return .close
    }

    fileprivate enum FocusTarget: Hashable {
        case close
        case card(String)
        case edit(String)
    }
}

private struct TierListCard: View {
    internal let handle: TierListHandle
    internal let isActive: Bool
    internal let focusBinding: FocusState<TierListBrowserScene.FocusTarget?>.Binding
    internal let openAction: () -> Void
    internal let editAction: () -> Void

    internal var body: some View {
        tvGlassContainer(spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                headerRow
                Text(metadataDescription)
                    .font(.footnote)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(3)

                Divider()
                    .blendMode(.plusLighter)
                    .opacity(0.25)

                actionRow
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 26)
        }
        .tvGlassRounded(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isActive ? Palette.brand : Color.white.opacity(0.14), lineWidth: isActive ? 2.2 : 1.0)
        )
        .shadow(color: isActive ? Palette.brand.opacity(0.32) : .clear, radius: isActive ? 14 : 0, y: isActive ? 8 : 0)
        .accessibilityIdentifier("TierListCard_\(handle.id)")
    }

    private var headerRow: some View {
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
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: openAction) {
                Label("Open", systemImage: "list.bullet.rectangle")
                    #if os(tvOS)
                    .labelStyle(.iconOnly)
                    #else
                    .labelStyle(.titleAndIcon)
                    #endif
                    .font(.callout.weight(.semibold))
            }
            .focused(focusBinding, equals: .card(handle.id))
            #if os(tvOS)
            .buttonStyle(.glassProminent)
            #else
            .buttonStyle(.borderedProminent)
            #endif
            .accessibilityIdentifier("TierListCard_Open_\(handle.id)")

            Button(action: editAction) {
                Label("Edit", systemImage: "square.and.pencil")
                    #if os(tvOS)
                    .labelStyle(.iconOnly)
                    #else
                    .labelStyle(.titleAndIcon)
                    #endif
                    .font(.callout)
            }
            .focused(focusBinding, equals: .edit(handle.id))
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.bordered)
            #endif
            .accessibilityIdentifier("TierListCard_Edit_\(handle.id)")

            Spacer(minLength: 0)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private var iconName: String {
        switch handle.source {
        case .bundled:
            return handle.iconSystemName ?? "square.grid.2x2"
        case .file:
            return handle.iconSystemName ?? "externaldrive"
        case .authored:
            return handle.iconSystemName ?? "square.and.pencil"
        }
    }

    private var metadataDescription: String {
        switch handle.source {
        case .bundled:
            return "Bundled tier list • Offline ready"
        case .file:
            return "Local save file • Stored on this device"
        case .authored:
            return "Authored in Tiercade • SwiftData"
        }
    }

    private var cardIconBackground: some ShapeStyle {
        LinearGradient(
            colors: [Palette.brand.opacity(0.18), Palette.brand.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
