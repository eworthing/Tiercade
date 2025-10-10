// ...removed import Design; design files are part of main app target
import Observation
import SwiftUI
import TiercadeCore

@MainActor
struct TierCreatorSetupStageView: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    #if os(tvOS)
    @FocusState private var setupFocus: SetupFocus?
    #endif

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 2) {
            detailCard
                .frame(maxWidth: .infinity, alignment: .leading)
            sidebar
                .frame(maxWidth: Metrics.paneRight)
        }
        #if os(tvOS)
        .onAppear { setupFocus = .title }
        .onChange(of: appState.tierCreatorStage) { _, newStage in
            if newStage == .setup {
                setupFocus = .title
            }
        }
        #endif
    }

    private var detailCard: some View {
        TierCreatorStageCard(
            title: "Project details",
            subtitle: "Define the basics before creating items"
        ) {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                TierCreatorSetupField(label: "Title") {
                    TextField(
                        "Project title",
                        text: binding(
                            get: { project.title },
                            set: { project.title = $0 }
                        )
                    )
                    .submitLabel(.done)
                    .textFieldStyle(.plain)
                    #if os(tvOS)
                    .focused($setupFocus, equals: .title)
                    .focusable(interactions: .edit)
                    #endif
                }

                TierCreatorSetupField(label: "Description") {
                    TextField(
                        "Optional summary",
                        text: binding(
                            get: { project.projectDescription ?? "" },
                            set: { project.projectDescription = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .submitLabel(.done)
                    .textFieldStyle(.plain)
                    #if os(tvOS)
                    .focused($setupFocus, equals: .description)
                    .focusable(interactions: .edit)
                    #endif
                }

                TierCreatorSetupField(label: "Content source") {
                    Picker(
                        "Content source",
                        selection: binding(
                            get: { project.sourceType },
                            set: { project.sourceType = $0 }
                        )
                    ) {
                        ForEach(TierCreatorSourceType.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #if os(tvOS)
                    .focused($setupFocus, equals: .contentSource)
                    .focusable(interactions: .activate)
                    #endif
                }

                Toggle(
                    isOn: binding(
                        get: { project.hasGeneratedBaseTiers },
                        set: { project.hasGeneratedBaseTiers = $0 }
                    )
                ) {
                    Label("Pre-seed tiers with defaults", systemImage: "square.stack.3d.up")
                        .labelStyle(.titleAndIcon)
                }
                .toggleStyle(.switch)
                #if os(tvOS)
                .focused($setupFocus, equals: .preseedToggle)
                .focusable(interactions: .activate)
                #endif
                .accessibilityIdentifier("TierCreator_SetupPreseedToggle")

                HStack(spacing: Metrics.grid * 1.5) {
                    Button {
                        appState.presentThemePicker()
                    } label: {
                        Label("Choose theme", systemImage: "paintpalette")
                    }
                    .buttonStyle(.tvGlass)
                    #if os(tvOS)
                    .focused($setupFocus, equals: .chooseTheme)
                    .focusable(interactions: .activate)
                    #endif
                    .accessibilityIdentifier("TierCreator_SetupTheme")

                    Button {
                        appState.showInfoToast(
                            "Template coming soon",
                            message: "Theme presets"
                        )
                    } label: {
                        Label("Apply template", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.tvGlass)
                    #if os(tvOS)
                    .focused($setupFocus, equals: .applyTemplate)
                    .focusable(interactions: .activate)
                    #endif
                    .accessibilityIdentifier("TierCreator_SetupTemplate")
                }
            }
            #if os(tvOS)
            .focusSection()
            #endif
            .onChange(of: project.updatedAt) { _, _ in
                appState.tierCreatorValidationIssues = appState.stageValidationIssues(
                    for: .setup,
                    project: project
                )
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2) {
            TierCreatorStageCard(title: "Workflow tips") {
                TierCreatorSetupTips(stage: appState.tierCreatorStage)
            }

            TierCreatorStageCard(title: "Tier outline", subtitle: "Current order preview") {
                VStack(alignment: .leading, spacing: Metrics.grid) {
                    ForEach(project.tiers.sorted { $0.order < $1.order }.prefix(6)) { tier in
                        HStack(spacing: Metrics.grid) {
                            Text(tier.label.isEmpty ? tier.tierId : tier.label)
                                .font(TypeScale.body)
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Text("Order \(tier.order + 1)")
                                .font(TypeScale.label)
                                .foregroundStyle(Palette.textDim)
                        }
                        .padding(.horizontal, Metrics.grid * 1.5)
                        .padding(.vertical, Metrics.grid)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.surface.opacity(0.7))
                        )
                    }
                }
            }
        }
    }

    private func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                project.updatedAt = Date()
                appState.markAsChanged()
                appState.tierCreatorValidationIssues = appState.stageValidationIssues(
                    for: .setup,
                    project: project
                )
            }
        )
    }
}

@MainActor
struct TierCreatorSetupField<Field: View>: View {
    let label: String
    @ViewBuilder let field: () -> Field

    init(
        label: String,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.label = label
        self.field = field
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(TypeScale.label)
                .foregroundStyle(Palette.textDim)

            field()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.grid * 1.5)
                .padding(.vertical, Metrics.grid)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface.opacity(0.72))
                )
        }
    }
}

#if os(tvOS)
private extension TierCreatorSetupStageView {
    enum SetupFocus: Hashable {
        case title
        case description
        case contentSource
        case preseedToggle
        case chooseTheme
        case applyTemplate
    }
}
#endif

private extension View {
    @ViewBuilder
    func then<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

@MainActor
struct TierCreatorSetupTips: View {
    let stage: TierCreatorStage

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.25) {
            Label("Give your project a clear, concise name.", systemImage: "pencil")
                .labelStyle(.titleAndIcon)
                .font(TypeScale.body)
                .foregroundStyle(Palette.text)
            Label("Choose a base theme to set initial tier colors.", systemImage: "paintbrush")
                .labelStyle(.titleAndIcon)
                .font(TypeScale.body)
                .foregroundStyle(Palette.text)
            Label("You can return here later even after adding items.", systemImage: "arrow.uturn.backward")
                .labelStyle(.titleAndIcon)
                .font(TypeScale.body)
                .foregroundStyle(Palette.text)
        }
    }
}
