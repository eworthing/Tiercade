import SwiftUI

private enum FocusField: Hashable {
    case name
    case description
    case tier(UUID)
    case palette(Int)
    case save
    case cancel
}

struct ThemeCreatorOverlay: View {
    @Bindable var appState: AppState
    let draft: ThemeDraft

    @FocusState private var focusedElement: FocusField?
    @Namespace private var focusNamespace
    @State private var paletteFocusIndex: Int = 0
    @State private var lastFocus: FocusField?
    @State private var suppressFocusReset = false

    private let paletteColumns = 6
    private static let paletteHexes: [String] = [
        "#F97316", "#FACC15", "#4ADE80", "#22D3EE", "#818CF8", "#C084FC",
        "#F472B6", "#F43F5E", "#FB7185", "#FF9F0A", "#FFD60A", "#64D2FF",
        "#30D158", "#5AC8FA", "#BF5AF2", "#FF2D55", "#FF453A", "#FF3B30",
        "#FF6B6B", "#34D399", "#0EA5E9", "#2563EB", "#9333EA", "#DB2777"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { dismiss(returnToPicker: true) }

            VStack(spacing: 0) {
                header
                Divider().opacity(0.15)
                content
                Divider().opacity(0.15)
                footer
            }
            .frame(maxWidth: 1160, maxHeight: 880)
            .tvGlassRounded(TVMetrics.overlayCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: TVMetrics.overlayCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.42), radius: 32, y: 18)
            .accessibilityIdentifier("ThemeCreator_Overlay")
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .focusSection()
            .focusScope(focusNamespace)
            .defaultFocus($focusedElement, .tier(draft.activeTierID))
            .onAppear {
                suppressFocusReset = false
                appState.themeCreatorActive = true
                paletteFocusIndex = paletteIndex(for: draft.activeTier?.colorHex)
                setFocus(.tier(draft.activeTierID))
                FocusUtils.seedFocus()
            }
            .onDisappear {
                suppressFocusReset = true
                appState.themeCreatorActive = false
                focusedElement = nil
                lastFocus = nil
            }
            .onExitCommand { dismiss(returnToPicker: true) }
            .onMoveCommand(perform: handleMoveCommand)
            .onChange(of: focusedElement) { _, newValue in
                guard !suppressFocusReset else { return }
                if let newValue {
                    lastFocus = newValue
                } else if let lastFocus {
                    focusedElement = lastFocus
                }
            }
        }
        #if os(tvOS)
        .persistentSystemOverlays(.hidden)
        #endif
    }

}

private extension ThemeCreatorOverlay {
    var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create Custom Theme")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Name your theme and choose colors for each tier")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(TVMetrics.overlayPadding)
    .tvGlassRounded(0)
    }

    var content: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 28) {
                formSection
                tierList
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 520)

            paletteSection
        }
        .padding(.horizontal, TVMetrics.overlayPadding)
        .padding(.vertical, 32)
    }

    var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Details")
                .font(.headline)

            TextField("Theme Name", text: nameBinding)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .tvGlassRounded(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .focused($focusedElement, equals: .name)
                .submitLabel(.done)
                .accessibilityIdentifier("ThemeCreator_NameField")

            TextField("Short description", text: descriptionBinding)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .tvGlassRounded(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .focused($focusedElement, equals: .description)
                .submitLabel(.done)
                .accessibilityIdentifier("ThemeCreator_DescriptionField")
                .foregroundStyle(.secondary)
        }
    }

    var tierList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tiers")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(draft.tiers) { tier in
                        Button {
                            setActiveTier(tier.id)
                        } label: {
                            tierRow(for: tier)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedElement, equals: .tier(tier.id))
                        .accessibilityIdentifier("ThemeCreator_Tier_\(tier.name)")
                    }
                }
            }
        }
    }

    func tierRow(for tier: ThemeTierDraft) -> some View {
        let isActive = tier.id == draft.activeTierID
        let background = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorUtilities.color(hex: tier.colorHex))
                .frame(width: 72, height: 56)
                .overlay(
                    Text(tier.name)
                        .fontWeight(.bold)
                        .foregroundStyle(ColorUtilities.accessibleTextColor(onBackground: tier.colorHex))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.name)
                    .font(.headline)
                Text(tier.colorHex)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .tvGlassRounded(14)
        .tint(ColorUtilities.color(hex: tier.colorHex).opacity(isActive ? 0.26 : 0.14))
        .overlay(
            background
                .stroke(
                    isActive ? Color.accentColor : Color.white.opacity(0.08),
                    lineWidth: isActive ? 2.5 : 1
                )
        )
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isActive)
    }

    var paletteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Palette")
                .font(.headline)

            Text("Select a color to apply to the active tier")
                .font(.footnote)
                .foregroundStyle(.secondary)

            GlassEffectContainer(spacing: 18) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: paletteColumns),
                    spacing: 18
                ) {
                    ForEach(Self.paletteHexes.indices, id: \.self) { index in
                        let hex = Self.paletteHexes[index]
                        paletteButton(for: hex, index: index)
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func paletteButton(for hex: String, index: Int) -> some View {
        let isFocusedColor = focusedElement == .palette(index)
        let isApplied = draft.activeTier?.colorHex.uppercased() == ThemeDraft.normalizeHex(hex)
        let background = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return Button {
            paletteFocusIndex = index
            appState.assignColorToActiveTier(hex)
            setFocus(.palette(index))
        } label: {
            background
                .fill(ColorUtilities.color(hex: hex))
                .frame(width: 92, height: 72)
                .overlay(
                    VStack {
                        if isApplied {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ColorUtilities.accessibleTextColor(onBackground: hex))
                        }
                        Spacer()
                        Text(hex)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(10)
                )
        }
        .buttonStyle(.plain)
        .focused($focusedElement, equals: .palette(index))
        .scaleEffect(isFocusedColor ? 1.06 : 1.0)
        .shadow(
            color: .black.opacity(isFocusedColor ? 0.45 : 0.25),
            radius: isFocusedColor ? 16 : 8,
            x: 0,
            y: isFocusedColor ? 12 : 6
        )
        .animation(.easeOut(duration: 0.18), value: isFocusedColor)
        .accessibilityIdentifier("ThemeCreator_Palette_\(index)")
    }

    var footer: some View {
        HStack(spacing: TVMetrics.buttonSpacing) {
            Button(role: .cancel) { dismiss(returnToPicker: true) } label: {
                Label("Cancel", systemImage: "arrow.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .focused($focusedElement, equals: .cancel)
            .accessibilityIdentifier("ThemeCreator_FooterCancel")

            Spacer()

            Button(action: appState.completeThemeCreation) {
                Label("Save Theme", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .focused($focusedElement, equals: .save)
            .disabled(nameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("ThemeCreator_Save")
        }
        .padding(TVMetrics.overlayPadding)
        .tvGlassRounded(0)
        .overlay(alignment: .top) {
            Divider().opacity(0.12)
        }
    }

    func dismiss(returnToPicker: Bool) {
        appState.cancelThemeCreation(returnToThemePicker: returnToPicker)
    }

    func setActiveTier(_ tierID: UUID) {
        appState.selectThemeDraftTier(tierID)
        paletteFocusIndex = paletteIndex(for: appState.themeDraft?.activeTier?.colorHex)
        setFocus(.tier(tierID))
    }

    func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let focus = focusedElement else { return }
        switch focus {
        case .name:
            handleNameMove(direction)
        case .description:
            handleDescriptionMove(direction)
        case .tier(let id):
            handleTierMove(direction, tierID: id)
        case .palette(let index):
            handlePaletteMove(direction, index: index)
        case .save:
            handleSaveMove(direction)
        case .cancel:
            handleCancelMove(direction)
        }
    }

    func handleNameMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .down:
            setFocus(.description)
        case .right:
            setFocus(.tier(draft.activeTierID))
        default:
            setFocus(.name)
        }
    }

    func handleDescriptionMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            setFocus(.name)
        case .down:
            setFocus(.tier(draft.activeTierID))
        case .right:
            setFocus(.tier(draft.activeTierID))
        default:
            setFocus(.description)
        }
    }

    func handleTierMove(_ direction: MoveCommandDirection, tierID: UUID) {
        guard let currentIndex = tierIndex(for: tierID) else { return }
        switch direction {
        case .up:
            if currentIndex == 0 {
                setFocus(.description)
            } else {
                focusTier(at: currentIndex - 1)
            }
        case .down:
            if currentIndex >= draft.tiers.count - 1 {
                setFocus(.save)
            } else {
                focusTier(at: currentIndex + 1)
            }
        case .right:
            paletteFocusIndex = paletteIndex(for: draft.tiers[currentIndex].colorHex)
            setFocus(.palette(paletteFocusIndex))
        default:
            setFocus(.tier(tierID))
        }
    }

    func handlePaletteMove(_ direction: MoveCommandDirection, index: Int) {
        switch direction {
        case .left:
            setFocus(.tier(draft.activeTierID))
        case .up:
            let target = max(index - paletteColumns, 0)
            paletteFocusIndex = target
            setFocus(.palette(target))
        case .down:
            let target = index + paletteColumns
            if target < Self.paletteHexes.count {
                paletteFocusIndex = target
                setFocus(.palette(target))
            } else {
                setFocus(.save)
            }
        case .right:
            let target = min(index + 1, Self.paletteHexes.count - 1)
            paletteFocusIndex = target
            setFocus(.palette(target))
        default:
            setFocus(.palette(index))
        }
    }

    func handleSaveMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            setFocus(.palette(paletteFocusIndex))
        case .left:
            setFocus(.cancel)
        default:
            setFocus(.save)
        }
    }

    func handleCancelMove(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            setFocus(.tier(draft.activeTierID))
        case .right:
            setFocus(.save)
        case .down:
            setFocus(.save)
        default:
            setFocus(.cancel)
        }
    }

    func focusTier(at index: Int) {
        let tier = draft.tiers[index]
        paletteFocusIndex = paletteIndex(for: tier.colorHex)
        setActiveTier(tier.id)
    }

    var nameBinding: Binding<String> {
        Binding(
            get: { appState.themeDraft?.displayName ?? draft.displayName },
            set: { appState.updateThemeDraftName($0) }
        )
    }

    var descriptionBinding: Binding<String> {
        Binding(
            get: { appState.themeDraft?.shortDescription ?? draft.shortDescription },
            set: { appState.updateThemeDraftDescription($0) }
        )
    }

    func tierIndex(for id: UUID) -> Int? {
        draft.tiers.firstIndex { $0.id == id }
    }

    func paletteIndex(for hex: String?) -> Int {
        guard let hex else { return 0 }
        let normalized = ThemeDraft.normalizeHex(hex)
        return Self.paletteHexes.firstIndex { ThemeDraft.normalizeHex($0) == normalized } ?? 0
    }

    func setFocus(_ target: FocusField) {
        focusedElement = target
        lastFocus = target
    }
}
