import Observation
import SwiftUI

@MainActor
struct TierCreatorSetupStageView: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let focusNamespace: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 2) {
            detailCard
                .focusSection()
                .frame(maxWidth: .infinity, alignment: .leading)

            sidebar
                .frame(maxWidth: Metrics.paneRight)
                .focusSection()
        }
    }

    private var detailCard: some View {
        TierCreatorStageCard(
            title: "Project details",
            subtitle: "Define the basics before creating items"
        ) {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                TierCreatorSetupField(label: "Title", focusNamespace: focusNamespace, prefersInitialFocus: true) {
                    TextField(
                        "Project title",
                        text: binding(
                            get: { project.title },
                            set: { project.title = $0 }
                        )
                    )
                    .submitLabel(.done)
                    .textFieldStyle(.plain)
                }

                TierCreatorSetupField(label: "Description", focusNamespace: focusNamespace) {
                    TextField(
                        "Optional summary",
                        text: binding(
                            get: { project.projectDescription ?? "" },
                            set: { project.projectDescription = $0.isEmpty ? nil : $0 }
                        )
                    )
                    .submitLabel(.done)
                    .textFieldStyle(.plain)
                }

                TierCreatorSetupField(label: "Content source", focusNamespace: focusNamespace) {
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
                .accessibilityIdentifier("TierCreator_SetupPreseedToggle")

                HStack(spacing: Metrics.grid * 1.5) {
                    Button {
                        appState.presentThemePicker()
                    } label: {
                        Label("Choose theme", systemImage: "paintpalette")
                    }
                    .buttonStyle(.tvGlass)
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
                    .accessibilityIdentifier("TierCreator_SetupTemplate")
                }
            }
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
    let focusNamespace: Namespace.ID?
    let prefersInitialFocus: Bool
    @ViewBuilder let field: () -> Field

    init(
        label: String,
        focusNamespace: Namespace.ID? = nil,
        prefersInitialFocus: Bool = false,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.label = label
        self.focusNamespace = focusNamespace
        self.prefersInitialFocus = prefersInitialFocus
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
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .focusable(true)
                .tierCreatorDefaultFocus(prefersInitialFocus, in: focusNamespace)
        }
    }
}

private extension View {
    @ViewBuilder
    func tierCreatorDefaultFocus(_ prefers: Bool, in namespace: Namespace.ID?) -> some View {
        if prefers, let namespace {
            prefersDefaultFocus(in: namespace)
        } else {
            self
        }
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
