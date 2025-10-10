import Observation
import SwiftData
import SwiftUI

@MainActor
struct TierCreatorTierInspector: View {
    @Bindable var appState: AppState
    let tier: TierCreatorTier?
    let issues: [TierCreatorValidationIssue]

    @State private var labelDraft: String = ""
    @State private var colorDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
            header
            content
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: tier?.tierId) { _, _ in syncDrafts() }
    }

    private var header: some View {
        HStack {
            Text("Tier Inspector")
                .font(TypeScale.h3)
                .foregroundStyle(Palette.text)
            Spacer()
            if let tier {
                Text("Tier ID: \(tier.tierId)")
                    .font(TypeScale.label)
                    .foregroundStyle(Palette.textDim)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tier {
            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
                inspectorField(
                    title: "Display Label",
                    text: Binding(
                        get: { labelDraft },
                        set: { newValue in
                            labelDraft = newValue
                            applyLabelIfNeeded()
                        }
                    ),
                    prompt: "Enter tier label"
                )

                inspectorField(
                    title: "Color Hex",
                    text: Binding(
                        get: { colorDraft },
                        set: { newValue in
                            colorDraft = newValue
                            applyColorIfNeeded()
                        }
                    ),
                    prompt: "#RRGGBB"
                )
                .textInputAutocapitalization(.characters)
                .keyboardType(.alphabet)

                TierInspectorToggleGroup(appState: appState, tier: tier)
                validationList
            }
            .padding(.horizontal, Metrics.grid * 2)
            .padding(.vertical, Metrics.grid * 1.5)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
            )
        } else {
            Text("Select a tier to edit its properties.")
                .font(TypeScale.body)
                .foregroundStyle(Palette.textDim)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Palette.surface)
                )
        }
    }

    private func inspectorField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(TypeScale.label)
                .foregroundStyle(Palette.textDim)
            TextField(prompt, text: text)
                .padding(.horizontal, Metrics.grid * 1.5)
                .padding(.vertical, Metrics.grid)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.surface.opacity(0.72))
                )
                .frame(height: 52)
                .focusable(true)
        }
    }

    private func syncDrafts() {
        guard let tier else {
            labelDraft = ""
            colorDraft = ""
            return
        }
        labelDraft = tier.label
        colorDraft = tier.colorHex ?? ""
    }

    private func applyLabelIfNeeded() {
        guard let tier, labelDraft != tier.label else { return }
        appState.updateTier(tier, label: labelDraft)
    }

    private func applyColorIfNeeded() {
        guard let tier else { return }
        let normalized = colorDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized != (tier.colorHex ?? "") {
            appState.updateTier(tier, colorHex: normalized.isEmpty ? nil : normalized)
        }
    }

    @ViewBuilder
    private var validationList: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(issues) { issue in
                    HStack(spacing: Metrics.grid) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        Text(issue.message)
                            .font(TypeScale.label)
                            .foregroundStyle(Palette.textDim)
                    }
                }
            }
            .padding(.horizontal, Metrics.grid * 1.5)
            .padding(.vertical, Metrics.grid)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .accessibilityIdentifier("TierCreator_TierIssues")
        }
    }

}

@MainActor
private struct TierInspectorToggleGroup: View {
    @Bindable var appState: AppState
    let tier: TierCreatorTier

    init(appState: AppState, tier: TierCreatorTier) {
        _appState = Bindable(appState)
        self.tier = tier
    }

    var body: some View {
        HStack(spacing: Metrics.grid * 2) {
            Toggle(isOn: toggleBinding(for: \TierCreatorTier.isLocked)) {
                Label("Locked", systemImage: "lock.fill")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("TierCreator_TierLockedToggle")

            Toggle(isOn: toggleBinding(for: \TierCreatorTier.isCollapsed)) {
                Label("Collapsed", systemImage: "rectangle.compress.vertical")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("TierCreator_TierCollapsedToggle")
        }
    }

    private func toggleBinding(for keyPath: ReferenceWritableKeyPath<TierCreatorTier, Bool>) -> Binding<Bool> {
        Binding(
            get: { tier[keyPath: keyPath] },
            set: { newValue in
                switch keyPath {
                case \TierCreatorTier.isLocked:
                    appState.updateTier(tier, isLocked: newValue)
                case \TierCreatorTier.isCollapsed:
                    appState.updateTier(tier, isCollapsed: newValue)
                default:
                    break
                }
            }
        )
    }
}
