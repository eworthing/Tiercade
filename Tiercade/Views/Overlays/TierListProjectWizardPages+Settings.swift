import SwiftUI
import TiercadeCore
import os

// MARK: - Settings Wizard Page

internal struct SettingsWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft

    internal let pageTitle = "Project Settings"
    internal let pageDescription = "Configure basic project information and options"

    #if os(tvOS)
    @Namespace private var defaultFocusNamespace
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, description }
    #endif

    internal var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                projectInfoSection
                displayOptionsSection
                accessibilitySection
                publishingSection
                validationSection
            }
            .padding(.horizontal, Metrics.grid * 6)
            .padding(.vertical, Metrics.grid * 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(tvOS)
        .onAppear { focusedField = .title }
        #endif
    }

    // MARK: - Sections

    private var projectInfoSection: some View {
        sectionContainer(title: "Project Information") {
            TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                .font(.title3)
                #if os(tvOS)
                .wizardFieldDecoration()
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .accessibilityIdentifier("Settings_TitleField")
                .onChange(of: draft.title) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .focused($focusedField, equals: .title)
                .prefersDefaultFocus(true, in: defaultFocusNamespace)
            #endif

            TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                .lineLimit(3...6)
                #if os(tvOS)
                .wizardFieldDecoration()
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .accessibilityIdentifier("Settings_DescriptionField")
                .onChange(of: draft.summary) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .focused($focusedField, equals: .description)
            #endif
        }
    }

    private var displayOptionsSection: some View {
        sectionContainer(title: "Display Options") {
            #if !os(tvOS)
            Stepper(value: $draft.schemaVersion, in: 1...9) {
                Text("Schema Version: \(draft.schemaVersion)")
            }
            .onChange(of: draft.schemaVersion) { appState.markDraftEdited(draft) }
            #else
            HStack {
                Text("Schema Version")
                Spacer()
                Text("\(draft.schemaVersion)")
                    .foregroundStyle(Palette.textDim)
            }
            .font(.title3)
            #endif

            Toggle("Show Unranked Tier", isOn: $draft.showUnranked)
                .accessibilityIdentifier("Settings_ShowUnrankedToggle")
                .onChange(of: draft.showUnranked) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .wizardTogglePadding()
            #endif

            Toggle("Enable Grid Snap", isOn: $draft.gridSnap)
                .accessibilityIdentifier("Settings_GridSnapToggle")
                .onChange(of: draft.gridSnap) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .wizardTogglePadding()
            #endif
        }
    }

    private var accessibilitySection: some View {
        sectionContainer(title: "Accessibility") {
            Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                .accessibilityIdentifier("Settings_VoiceOverToggle")
                .onChange(of: draft.accessibilityVoiceOver) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .wizardTogglePadding()
            #endif

            Toggle("High Contrast Mode", isOn: $draft.accessibilityHighContrast)
                .accessibilityIdentifier("Settings_HighContrastToggle")
                .onChange(of: draft.accessibilityHighContrast) { appState.markDraftEdited(draft) }
                #if os(tvOS)
                .wizardTogglePadding()
            #endif
        }
    }

    private var publishingSection: some View {
        sectionContainer(title: "Publishing") {
            Picker("Visibility", selection: $draft.visibility) {
                Text("Private").tag("private")
                Text("Unlisted").tag("unlisted")
                Text("Public").tag("public")
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.visibility) { appState.markDraftEdited(draft) }
            .accessibilityIdentifier("Settings_VisibilityPicker")
        }
    }

    private var validationSection: some View {
        sectionContainer(title: "Validation") {
            if appState.tierListCreatorIssues.isEmpty {
                statusChip(
                    icon: "checkmark.circle.fill",
                    tint: Palette.tierColor("B"),
                    title: "No issues found",
                    message: "Your project configuration is valid"
                )
            } else {
                VStack(alignment: .leading, spacing: Metrics.grid * 2) {
                    ForEach(appState.tierListCreatorIssues) { issue in
                        statusChip(
                            icon: "exclamationmark.triangle.fill",
                            tint: Palette.tierColor("S"),
                            title: issue.category.rawValue.capitalized,
                            message: issue.message
                        )
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func sectionContainer<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 2.5) {
            sectionHeader(title)
            content()
        }
        .padding(.all, Metrics.grid * 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Palette.stroke.opacity(0.6), radius: 8, y: 4)
    }

    private func statusChip(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(spacing: Metrics.grid * 2) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: Metrics.grid) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                Text(message)
                    .font(TypeScale.body)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(Metrics.grid * 2.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(tint.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
