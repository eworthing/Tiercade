import SwiftUI
import TiercadeCore

// MARK: - Tier Details Sheet

internal struct TierDetailsSheet: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @Bindable var tier: TierDraftTier
    @Environment(\.dismiss) private var dismiss

    internal var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Tier color preview
                    Rectangle()
                        .fill(ColorUtilities.color(hex: tier.colorHex))
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Basic fields
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tier Details")
                            .font(.title3.weight(.semibold))

                        TextField("Display Label", text: Binding(
                            get: { tier.label },
                            set: { newValue in
                                tier.label = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                        #endif

                        TextField("Tier Identifier", text: Binding(
                            get: { tier.tierId },
                            set: { newValue in
                                tier.tierId = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                        #endif

                        TextField("Color Hex", text: Binding(
                            get: { tier.colorHex },
                            set: { newValue in
                                tier.colorHex = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    }

                    // Toggles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.title3.weight(.semibold))

                        Toggle("Locked", isOn: Binding(
                            get: { tier.locked },
                            set: { _ in appState.toggleLock(tier, in: draft) }
                        ))
                        .toggleStyle(.switch)

                        Toggle("Collapsed", isOn: Binding(
                            get: { tier.collapsed },
                            set: { _ in appState.toggleCollapse(tier, in: draft) }
                        ))
                        .toggleStyle(.switch)
                    }

                    // Item count
                    Text("\(appState.orderedItems(for: tier).count) items in this tier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
            }
            .navigationTitle("Edit Tier")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Item Details Sheet

internal struct ItemDetailsSheet: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @Bindable var item: TierDraftItem
    internal let currentTier: TierDraftTier?
    @Environment(\.dismiss) private var dismiss

    internal var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Essentials
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Basic Information")
                            .font(.title3.weight(.semibold))

                        TextField("Display Title", text: Binding(
                            get: { item.title },
                            set: { newValue in
                                item.title = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                        #endif

                        TextField("Subtitle", text: Binding(
                            get: { item.subtitle },
                            set: { newValue in
                                item.subtitle = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                    }

                    // Tier assignment
                    if let currentTier {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Assignment")
                                .font(.title3.weight(.semibold))

                            HStack {
                                Text("Current tier:")
                                    .foregroundStyle(.secondary)
                                Text(item.tier?.label ?? "Unassigned")
                                    .font(.body.weight(.semibold))
                                Spacer()
                            }

                            Button {
                                appState.assign(item, to: currentTier, in: draft)
                            } label: {
                                Label("Assign to \(currentTier.label)", systemImage: "arrow.turn.down.right")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    // Advanced section
                    #if os(tvOS)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Fields")
                            .font(.title3.weight(.semibold))

                        TextField("Identifier", text: Binding(
                            get: { item.itemId },
                            set: { newValue in
                                item.itemId = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))

                        TextField("Slug", text: Binding(
                            get: { item.slug },
                            set: { newValue in
                                item.slug = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))

                        TextField("Summary", text: Binding(
                            get: { item.summary },
                            set: { newValue in
                                item.summary = newValue
                                appState.markDraftEdited(draft)
                            }
                        ), axis: .vertical)
                        .lineLimit(2...4)

                        Text("Rating: \(Int(item.rating ?? 50))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Hide from library", isOn: Binding(
                            get: { item.hidden },
                            set: { newValue in
                                item.hidden = newValue
                                appState.markDraftEdited(draft)
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                    #else
                    DisclosureGroup("Advanced Fields") {
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("Identifier", text: Binding(
                                get: { item.itemId },
                                set: { newValue in
                                    item.itemId = newValue
                                    appState.markDraftEdited(draft)
                                }
                            ))
                            .textFieldStyle(.roundedBorder)

                            TextField("Slug", text: Binding(
                                get: { item.slug },
                                set: { newValue in
                                    item.slug = newValue
                                    appState.markDraftEdited(draft)
                                }
                            ))
                            .textFieldStyle(.roundedBorder)

                            TextField("Summary", text: Binding(
                                get: { item.summary },
                                set: { newValue in
                                    item.summary = newValue
                                    appState.markDraftEdited(draft)
                                }
                            ), axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading) {
                                Text("Rating: \(Int(item.rating ?? 50))")
                                    .font(.caption)
                                Slider(value: Binding(
                                    get: { item.rating ?? 50 },
                                    set: { newValue in
                                        item.rating = newValue
                                        appState.markDraftEdited(draft)
                                    }
                                ), in: 0...100, step: 1)
                            }

                            Toggle("Hide from library", isOn: Binding(
                                get: { item.hidden },
                                set: { newValue in
                                    item.hidden = newValue
                                    appState.markDraftEdited(draft)
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                        .padding(.top, 12)
                    }
                    #endif
                }
                .padding(32)
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Project Settings Sheet

internal struct ProjectSettingsSheet: View {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @Environment(\.dismiss) private var dismiss

    internal var body: some View {
        NavigationStack {
            Form {
                Section("Project Information") {
                    TextField("Project Title", text: $draft.title, prompt: Text("Enter a descriptive title"))
                        .onChange(of: draft.title) { appState.markDraftEdited(draft) }

                    TextField("Description", text: $draft.summary, prompt: Text("Short description"), axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: draft.summary) { appState.markDraftEdited(draft) }
                }

                Section("Display Options") {
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
                            .foregroundStyle(.secondary)
                    }
                    #endif

                    Toggle("Show Unranked Tier", isOn: $draft.showUnranked)
                        .onChange(of: draft.showUnranked) { appState.markDraftEdited(draft) }

                    Toggle("Enable Grid Snap", isOn: $draft.gridSnap)
                        .onChange(of: draft.gridSnap) { appState.markDraftEdited(draft) }
                }

                Section("Accessibility") {
                    Toggle("VoiceOver Hints", isOn: $draft.accessibilityVoiceOver)
                        .onChange(of: draft.accessibilityVoiceOver) { appState.markDraftEdited(draft) }

                    Toggle("High Contrast Mode", isOn: $draft.accessibilityHighContrast)
                        .onChange(of: draft.accessibilityHighContrast) { appState.markDraftEdited(draft) }
                }

                Section("Publishing") {
                    Picker("Visibility", selection: $draft.visibility) {
                        Text("Private").tag("private")
                        Text("Unlisted").tag("unlisted")
                        Text("Public").tag("public")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.visibility) { appState.markDraftEdited(draft) }
                }

                Section("Validation") {
                    if appState.tierListCreatorIssues.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text("No issues found")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(appState.tierListCreatorIssues) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .accessibilityHidden(true)
                                Text(issue.message)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Project Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
