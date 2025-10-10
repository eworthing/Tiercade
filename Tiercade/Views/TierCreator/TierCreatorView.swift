import Observation
import SwiftUI

@MainActor
struct TierCreatorView: View {
    @Bindable var appState: AppState
    @Namespace private var focusNamespace
    @Environment(\.resetFocus) private var resetFocus

    private var project: TierCreatorProject? { appState.tierCreatorActiveProject }
    private var stage: TierCreatorStage { appState.tierCreatorStage }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg.ignoresSafeArea()

            if let project {
                VStack(spacing: Metrics.grid * 2) {
                    TierCreatorHeaderToolbar(appState: appState, project: project, stage: stage)
                        .focusSection()

                    if !appState.tierCreatorValidationIssues.isEmpty {
                        TierCreatorValidationBanner(
                            stage: stage,
                            issues: appState.tierCreatorValidationIssues
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, Metrics.grid * 3)
                    }

                    stageContent(for: project)
                        .focusScope(focusNamespace)
                        .padding(.horizontal, Metrics.grid * 3)

                    TierCreatorFooterActions(appState: appState, stage: stage)
                        .focusSection()
                        .padding(.horizontal, Metrics.grid * 3)
                }
                .padding(.vertical, Metrics.grid * 3)
                .transition(.opacity.combined(with: .scale))
                .onAppear {
                    refreshStageIssues(for: project)
                    resetFocus(in: focusNamespace)
                }
                .onChange(of: appState.tierCreatorStage) { _, _ in
                    refreshStageIssues(for: project)
                    resetFocus(in: focusNamespace)
                }
                .onChange(of: project.updatedAt) { _, _ in
                    refreshStageIssues(for: project)
                }
            } else {
                ContentUnavailableView(
                    "No project selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Create or select a tier project to begin.")
                )
                .padding()
            }
        }
    }

    private func refreshStageIssues(for project: TierCreatorProject) {
        let issues = appState.stageValidationIssues(for: stage, project: project)
        if issues != appState.tierCreatorValidationIssues {
            appState.tierCreatorValidationIssues = issues
        }
    }

    @ViewBuilder
    private func stageContent(for project: TierCreatorProject) -> some View {
        switch stage {
        case .setup:
            TierCreatorSetupStageView(appState: appState, project: project, focusNamespace: focusNamespace)
        case .items:
            TierCreatorItemsStageView(appState: appState, project: project, focusNamespace: focusNamespace)
        case .structure:
            TierCreatorStructureStageView(appState: appState, project: project, focusNamespace: focusNamespace)
        }
    }
}

// MARK: - Header & Stage Controls

@MainActor
private struct TierCreatorHeaderToolbar: View {
    @Bindable var appState: AppState
    let project: TierCreatorProject
    let stage: TierCreatorStage

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
            HStack(spacing: Metrics.grid * 2) {
                VStack(alignment: .leading, spacing: Metrics.grid * 0.5) {
                    Text(project.title.isEmpty ? "Untitled Project" : project.title)
                        .font(TypeScale.h2)
                        .foregroundStyle(Palette.text)
                    Text("Schema v\(project.schemaVersion) • Updated \(project.updatedAt.formatted(.dateTime))")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                        .accessibilityIdentifier("TierCreator_ProjectMetadata")
                }

                Spacer()

                Button(action: handleNew) {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.tvGlass)
                .accessibilityIdentifier("TierCreator_NewProject")

                Button(action: handleValidate) {
                    Label("Validate", systemImage: "checkmark.shield")
                }
                .buttonStyle(.tvGlass)
                .accessibilityIdentifier("TierCreator_Validate")

                Button(action: handleSave) {
                    Label("Save", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.tvGlass)
                .accessibilityIdentifier("TierCreator_Save")

                Button(role: .cancel) {
                    appState.closeTierCreator()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.tvGlass)
                .accessibilityIdentifier("TierCreator_Close")
            }

            TierCreatorStageStepper(appState: appState, currentStage: stage)
        }
        .padding(.horizontal, Metrics.grid * 3)
        .padding(.vertical, Metrics.grid * 2)
        .tvGlassRounded(28)
        .padding(.horizontal, Metrics.grid * 3)
    }

    private func handleNew() {
        let newProject = appState.createTierCreatorProject(title: "Untitled Project")
        appState.openTierCreator(with: newProject)
    }

    private func handleSave() {
        guard let active = appState.tierCreatorActiveProject else { return }
        if appState.saveTierCreatorChanges(for: active) {
            appState.showSuccessToast("Project saved", message: active.title)
        } else if let issue = appState.tierCreatorValidationIssues.first {
            appState.showErrorToast("Fix validation issues", message: issue.message)
        }
    }

    private func handleValidate() {
        guard let active = appState.tierCreatorActiveProject else { return }
        appState.tierCreatorValidationIssues = appState.validateTierCreatorProject(active)
        if appState.tierCreatorValidationIssues.isEmpty {
            appState.showSuccessToast("Validation passed")
        } else if let issue = appState.tierCreatorValidationIssues.first {
            appState.showWarningToast("Needs attention", message: issue.message)
        }
    }
}

@MainActor
private struct TierCreatorStageStepper: View {
    @Bindable var appState: AppState
    let currentStage: TierCreatorStage

    private var currentIndex: Int {
        TierCreatorStage.allCases.firstIndex(of: currentStage) ?? 0
    }

    var body: some View {
        HStack(spacing: Metrics.grid * 1.5) {
            ForEach(Array(TierCreatorStage.allCases.enumerated()), id: \.element) { index, stage in
                let isActive = stage == currentStage
                let isUnlocked = index <= currentIndex
                Button {
                    if isUnlocked, stage != currentStage {
                        appState.setTierCreatorStage(stage)
                    }
                } label: {
                    HStack(spacing: Metrics.grid * 0.75) {
                        Image(systemName: stage.systemImageName)
                        Text(stage.displayTitle)
                            .font(TypeScale.label.weight(isActive ? .semibold : .regular))
                    }
                    .padding(.horizontal, Metrics.grid * 1.5)
                    .padding(.vertical, Metrics.grid)
                    .background(
                        Capsule(style: .circular)
                            .fill(isActive ? Palette.brand.opacity(0.28) : Palette.surface.opacity(0.6))
                    )
                }
                .buttonStyle(.plain)
                .focusable(true)
                .disabled(!isUnlocked || stage == currentStage)
                .accessibilityIdentifier("TierCreator_Stage_\(stage.rawValue)")
            }
        }
    }
}
