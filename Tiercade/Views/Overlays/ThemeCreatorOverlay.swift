import SwiftUI

internal enum FocusField: Hashable {
    case name
    case description
    case tier(UUID)
    case palette(Int)
    case advancedPicker
    case save
    case cancel
}

internal struct ThemeCreatorOverlay: View {
    @Bindable var appState: AppState
    internal let draft: ThemeDraft

    @FocusState internal var focusedElement: FocusField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var focusNamespace
    @State private var paletteFocusIndex: Int = 0
    @State private var showAdvancedPicker = false
    #if !os(tvOS)
    @FocusState internal var overlayHasFocus: Bool
    #endif

    internal let paletteColumns = 6
    internal static let paletteHexes: [String] = [
        "#F97316", "#FACC15", "#4ADE80", "#22D3EE", "#818CF8", "#C084FC",
        "#F472B6", "#F43F5E", "#FB7185", "#FF9F0A", "#FFD60A", "#64D2FF",
        "#30D158", "#5AC8FA", "#BF5AF2", "#FF2D55", "#FF453A", "#FF3B30",
        "#FF6B6B", "#34D399", "#0EA5E9", "#2563EB", "#9333EA", "#DB2777"
    ]

    internal var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { dismiss(returnToPicker: true) }

            VStack(spacing: 0) {
                header
                    .padding(Metrics.cardPadding)
                    .tvGlassRounded(0)  // Glass on header chrome only

                Divider().opacity(0.15)

                content
                    .padding(Metrics.cardPadding)
                    .background(Color.black.opacity(0.7))

                Divider().opacity(0.15)

                footer
                    .padding(Metrics.cardPadding)
                    .tvGlassRounded(0)  // Glass on footer chrome only
            }
            .frame(maxWidth: 1160, maxHeight: 880)
            .background(
                Color.black.opacity(0.7),
                in: RoundedRectangle(cornerRadius: platformOverlayCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: platformOverlayCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.42), radius: 32, y: 18)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            #if os(tvOS)
            .focusSection()
            .focusScope(focusNamespace)
            .defaultFocus($focusedElement, .tier(draft.activeTierID))
            #endif
            .onAppear {
                paletteFocusIndex = paletteIndex(for: draft.activeTier?.colorHex)
                focusedElement = .tier(draft.activeTierID)
                FocusUtils.seedFocus()
            }
            .onDisappear {
                focusedElement = nil
            }
            #if os(tvOS)
            .onExitCommand { dismiss(returnToPicker: true) }
            #endif
            #if os(tvOS)
            .onMoveCommand(perform: handleMoveCommand)
            #else
            .focusable()
            .focused($overlayHasFocus)
            .onKeyPress(.upArrow) { handleDirectionalMove(.up); return .handled }
            .onKeyPress(.downArrow) { handleDirectionalMove(.down); return .handled }
            .onKeyPress(.leftArrow) { handleDirectionalMove(.left); return .handled }
            .onKeyPress(.rightArrow) { handleDirectionalMove(.right); return .handled }
            .onKeyPress(.space) { handlePrimaryAction(); return .handled }
            .onKeyPress(.return) { handlePrimaryAction(); return .handled }
            #endif
            .sheet(isPresented: $showAdvancedPicker) {
                #if os(tvOS)
                if let activeTier = draft.activeTier {
                    TVColorPickerView(
                        selection: Binding(
                            get: { ColorUtilities.color(hex: activeTier.colorHex) },
                            set: { newColor in
                                if let hex = newColor.toHex() {
                                    appState.assignColorToActiveTier(hex)
                                }
                            }
                        ),
                        title: "Custom Color for \(activeTier.name)"
                    )
                }
                #else
                if let activeTier = draft.activeTier {
                    VStack(spacing: 20) {
                        Text("Choose Color for \(activeTier.name)")
                            .font(.headline)
                            .padding(.top)

                        ColorPicker(
                            "Select a color",
                            selection: Binding(
                                get: { ColorUtilities.color(hex: activeTier.colorHex) },
                                set: { newColor in
                                    if let hex = newColor.toHex() {
                                        appState.assignColorToActiveTier(hex)
                                    }
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .padding()

                        Text(activeTier.colorHex)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Button("Done") {
                            showAdvancedPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom)
                    }
                    .padding(.horizontal)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
                #endif
            }
        }
        #if os(tvOS)
        .persistentSystemOverlays(.hidden)
        #endif
        #if !os(tvOS)
        .onAppear { overlayHasFocus = true }
        .onDisappear { overlayHasFocus = false }
        #endif
    }

}

// MARK: - Core Actions

internal extension ThemeCreatorOverlay {
    func dismiss(returnToPicker: Bool) {
        appState.cancelThemeCreation(returnToThemePicker: returnToPicker)
    }

    func setActiveTier(_ tierID: UUID) {
        appState.selectThemeDraftTier(tierID)
        paletteFocusIndex = paletteIndex(for: appState.theme.themeDraft?.activeTier?.colorHex)
        setFocusField(.tier(tierID))
    }
}

// MARK: - Views

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
        .padding(platformOverlayPadding)
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
        .padding(.horizontal, platformOverlayPadding)
        .padding(.vertical, 32)
    }

    var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Details")
                .font(.headline)

            TextField("Theme Name", text: nameBinding)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .focused($focusedElement, equals: .name)
                .submitLabel(.done)
                .accessibilityIdentifier("ThemeCreator_NameField")
                #if os(tvOS)
                .focusEffectDisabled(false)
            #endif

            TextField("Short description", text: descriptionBinding)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .focused($focusedElement, equals: .description)
                .submitLabel(.done)
                .accessibilityIdentifier("ThemeCreator_DescriptionField")
                .foregroundStyle(.secondary)
                #if os(tvOS)
                .focusEffectDisabled(false)
            #endif
        }
    }

    var tierList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tiers")
                .font(.headline)

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
            .padding(16)
            .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
        .animation(reduceMotion ? nil : Motion.emphasis, value: isActive)
    }

    var paletteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Palette")
                        .font(.headline)

                    Text("Select a color to apply to the active tier")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { showAdvancedPicker = true }, label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text("RGB Sliders")
                    }
                    .font(.caption)
                })
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focused($focusedElement, equals: .advancedPicker)
                .accessibilityIdentifier("ThemeCreator_AdvancedPicker")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: paletteColumns),
                spacing: 18
            ) {
                ForEach(Self.paletteHexes.indices, id: \.self) { index in
                    let hex = Self.paletteHexes[index]
                    paletteButton(for: hex, index: index)
                }
            }
            .padding(18)
            .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
            setFocusField(.palette(index))
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
        .animation(reduceMotion ? nil : Motion.focus, value: isFocusedColor)
        .accessibilityIdentifier("ThemeCreator_Palette_\(index)")
    }

    var footer: some View {
        HStack(spacing: platformButtonSpacing) {
            Button(role: .cancel) { dismiss(returnToPicker: true) } label: {
                Label("Cancel", systemImage: "arrow.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .focused($focusedElement, equals: .cancel)
            .accessibilityIdentifier("ThemeCreator_FooterCancel")
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif

            Spacer()

            Button(action: appState.completeThemeCreation) {
                Label("Save Theme", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .focused($focusedElement, equals: .save)
            .disabled(nameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("ThemeCreator_Save")
            #if !os(tvOS)
            .keyboardShortcut(.defaultAction)
            #endif
        }
        .padding(platformOverlayPadding)
        .tvGlassRounded(0)
        .overlay(alignment: .top) {
            Divider().opacity(0.12)
        }
    }

    var nameBinding: Binding<String> {
        Binding(
            get: { appState.theme.themeDraft?.displayName ?? draft.displayName },
            set: { appState.updateThemeDraftName($0) }
        )
    }

    var descriptionBinding: Binding<String> {
        Binding(
            get: { appState.theme.themeDraft?.shortDescription ?? draft.shortDescription },
            set: { appState.updateThemeDraftDescription($0) }
        )
    }

    func paletteIndexPrivate(for hex: String?) -> Int {
        guard let hex else { return 0 }
        let normalized = ThemeDraft.normalizeHex(hex)
        return Self.paletteHexes.firstIndex { ThemeDraft.normalizeHex($0) == normalized } ?? 0
    }
}

// MARK: - Focus State Accessors (for extension access)

internal extension ThemeCreatorOverlay {
    var currentFocusedElement: FocusField? { focusedElement }
    var currentPaletteFocusIndex: Int { paletteFocusIndex }

    func setFocusField(_ target: FocusField) {
        focusedElement = target
    }

    func updatePaletteFocusIndex(_ index: Int) {
        paletteFocusIndex = index
    }

    func presentAdvancedPicker() {
        showAdvancedPicker = true
    }

    #if !os(tvOS)
    func setOverlayHasFocus(_ value: Bool) {
        overlayHasFocus = value
    }
    #endif
}

// MARK: - Platform metrics

private extension ThemeCreatorOverlay {
    var platformOverlayCornerRadius: CGFloat {
        #if os(tvOS)
        TVMetrics.overlayCornerRadius
        #else
        28
        #endif
    }

    var platformOverlayPadding: CGFloat {
        #if os(tvOS)
        TVMetrics.overlayPadding
        #else
        Metrics.grid * 4
        #endif
    }

    var platformButtonSpacing: CGFloat {
        #if os(tvOS)
        TVMetrics.buttonSpacing
        #else
        Metrics.grid * 2
        #endif
    }
}
