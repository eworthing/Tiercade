import Observation
import SwiftUI

// MARK: - Shared Stage Components

struct TierCreatorStageCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
            VStack(alignment: .leading, spacing: Metrics.grid * 0.5) {
                Text(title)
                    .font(TypeScale.h3)
                    .foregroundStyle(Palette.text)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                }
            }

            content()
        }
        .padding(.horizontal, Metrics.grid * 2)
        .padding(.vertical, Metrics.grid * 2)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
        )
    }
}

@MainActor
struct TierCreatorFooterActions: View {
    @Bindable var appState: AppState
    let stage: TierCreatorStage

    var body: some View {
        HStack(spacing: Metrics.grid * 2) {
            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.tvGlass)
            .disabled(!(appState.undoManager?.canUndo ?? false))
            .accessibilityIdentifier("TierCreator_Undo")

            Button(action: redo) {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.tvGlass)
            .disabled(!(appState.undoManager?.canRedo ?? false))
            .accessibilityIdentifier("TierCreator_Redo")

            Spacer()

            footerButtons()
        }
    }

    @ViewBuilder
    private func footerButtons() -> some View {
        switch stage {
        case .setup:
            Button(role: .cancel) {
                appState.closeTierCreator()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterCancel")

            Button {
                appState.advanceTierCreatorStage()
            } label: {
                Label("Continue to items", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterContinue")
        case .items:
            Button {
                appState.retreatTierCreatorStage()
            } label: {
                Label("Back to setup", systemImage: "arrow.left")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterBackSetup")

            Button {
                appState.advanceTierCreatorStage()
            } label: {
                Label("Continue to structure", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterContinueStructure")
        case .structure:
            Button {
                appState.retreatTierCreatorStage()
            } label: {
                Label("Back to items", systemImage: "arrow.left")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterBackItems")

            Button {
                appState.advanceTierCreatorStage()
            } label: {
                Label("Publish project", systemImage: "sparkles")
            }
            .buttonStyle(.tvGlass)
            .accessibilityIdentifier("TierCreator_FooterPublish")
        }
    }

    private func undo() {
        appState.undoManager?.undo()
    }

    private func redo() {
        appState.undoManager?.redo()
    }
}

@MainActor
struct TierCreatorValidationBanner: View {
    let stage: TierCreatorStage
    let issues: [TierCreatorValidationIssue]

    private var primaryColor: Color {
        issues.isEmpty ? Color.green : Color.orange
    }

    private var headlineText: String {
        if issues.isEmpty {
            return "\(stage.displayTitle) stage clear"
        }
        return "Validation issues in \(stage.displayTitle.lowercased()) stage"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.grid * 2) {
            Image(systemName: issues.isEmpty ? "checkmark.seal" : "exclamationmark.triangle")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(primaryColor)

            VStack(alignment: .leading, spacing: Metrics.grid * 0.75) {
                Text(headlineText)
                    .font(TypeScale.body.weight(.semibold))
                    .foregroundStyle(Palette.text)

                if let firstIssue = issues.first {
                    Text(firstIssue.message)
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                } else {
                    Text("You're ready to continue.")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                }

                if issues.count > 1 {
                    Text("+\(issues.count - 1) more")
                        .font(TypeScale.label)
                        .foregroundStyle(Palette.textDim)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Metrics.grid * 2)
        .padding(.vertical, Metrics.grid * 1.5)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .accessibilityIdentifier("TierCreator_ValidationBanner")
    }
}
