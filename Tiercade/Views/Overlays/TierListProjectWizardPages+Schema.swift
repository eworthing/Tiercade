import SwiftUI
import TiercadeCore
import os

// MARK: - Schema Wizard Page

internal struct SchemaWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var schemaFields: [SchemaFieldDefinition] = []
    @State private var showingAddField = false
    private let schemaAdditionalKey = "itemSchema"

    internal let pageTitle = "Item Schema"
    internal let pageDescription = "Define custom fields for your items"

    #if os(tvOS)
    @Namespace private var defaultFocusNamespace
    #endif

    internal var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.grid * 3) {
                headerSection

                // Built-in fields
                VStack(alignment: .leading, spacing: Metrics.grid * 2) {
                    Text("Built-in Fields")
                        .font(.headline)
                        .padding(.horizontal, Metrics.grid * 6)

                    VStack(spacing: Metrics.grid * 2) {
                        builtInFieldRow("Title", icon: "textformat", type: "Text", required: true)
                        builtInFieldRow("Subtitle", icon: "text.alignleft", type: "Text", required: false)
                        builtInFieldRow("Summary", icon: "doc.text", type: "Text Area", required: false)
                        builtInFieldRow("Rating", icon: "star", type: "Number", required: false)
                    }
                    .padding(.horizontal, Metrics.grid * 6)
                }

                Divider()
                    .padding(.horizontal, Metrics.grid * 6)

                // Custom fields
                VStack(alignment: .leading, spacing: Metrics.grid * 2) {
                    HStack {
                        Text("Custom Fields")
                            .font(.headline)

                        Spacer()

                        Button {
                            showingAddField = true
                        } label: {
                            Label("Add Field", systemImage: "plus.circle.fill")
                        }
                        #if os(tvOS)
                        .buttonStyle(.glassProminent)
                        .prefersDefaultFocus(true, in: defaultFocusNamespace)
                        #else
                        .buttonStyle(.borderedProminent)
                        #endif
                        .accessibilityIdentifier("Schema_AddField")
                    }
                    .padding(.horizontal, Metrics.grid * 6)

                    if schemaFields.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(TypeScale.wizardTitle)
                                .foregroundStyle(Palette.textDim)
                            Text("No custom fields yet")
                                .font(.headline)
                                .foregroundStyle(Palette.textDim)
                            Text("Add fields to capture specific information about your items")
                                .font(.caption)
                                .foregroundStyle(Palette.textDim)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                                .fill(Palette.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Metrics.rLg, style: .continuous)
                                        .stroke(Palette.stroke, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, Metrics.grid * 6)
                    } else {
                        LazyVStack(spacing: Metrics.grid * 2) {
                            ForEach(schemaFields) { field in
                                customFieldRow(field)
                            }
                        }
                        .padding(.horizontal, Metrics.grid * 6)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        #if os(tvOS)
        .fullScreenCover(isPresented: $showingAddField) {
            AddSchemaFieldSheet(onAdd: { field in
                schemaFields.append(field)
                persistSchemaChange()
            })
        }
        // Scope default focus for tvOS so prefersDefaultFocus is reliable
        .focusScope(defaultFocusNamespace)
        #else
        .sheet(isPresented: $showingAddField) {
        AddSchemaFieldSheet(onAdd: { field in
        schemaFields.append(field)
        persistSchemaChange()
        })
        .presentationDetents([.large])
        }
        #endif
        .onAppear {
            loadSchema()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {
            Text("Item Properties")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.text)

            Text(
                """
                Define what information each item should have. Examples include Year, Genre, Platform, \
                Developer, or Publisher.
                """
            )
            .font(TypeScale.body)
            .foregroundStyle(Palette.textDim)
        }
        .padding(.horizontal, Metrics.grid * 6)
        .padding(.top, Metrics.grid * 5)
    }

    private func builtInFieldRow(_ name: String, icon: String, type: String, required: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.brand)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.text)

                HStack(spacing: 8) {
                    Text(type)
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)

                    if required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(Palette.tierColor("S", from: appState.tierColors))
                    }
                }
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(Palette.textDim)
        }
        .padding(Metrics.grid * 2)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
    }

    private func customFieldRow(_ field: SchemaFieldDefinition) -> some View {
        HStack(spacing: 16) {
            Image(systemName: field.fieldType.icon)
                .font(.title3)
                .foregroundStyle(Palette.tierColor("B", from: appState.tierColors))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(field.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.text)

                HStack(spacing: 8) {
                    Text(field.fieldType.displayName)
                        .font(.caption)
                        .foregroundStyle(Palette.textDim)

                    if field.required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(Palette.tierColor("S", from: appState.tierColors))
                    }

                    if field.allowMultiple {
                        Text("• Multiple")
                            .font(.caption)
                            .foregroundStyle(Palette.brand)
                    }
                }
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation {
                    schemaFields.removeAll { $0.id == field.id }
                    persistSchemaChange()
                }
            } label: {
                Image(systemName: "trash")
            }
            #if os(tvOS)
            .buttonStyle(.glass)
            #else
            .buttonStyle(.bordered)
            #endif
        }
        .padding(Metrics.grid * 2)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                .fill(Palette.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.rMd, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )
        )
    }

    private func loadSchema() {
        guard let stored = draft.additional?[schemaAdditionalKey] else {
            schemaFields = []
            return
        }

        do {
            let data = try TierListCreatorCodec.makeEncoder().encode(stored)
            schemaFields = try TierListCreatorCodec.makeDecoder().decode([SchemaFieldDefinition].self, from: data)
        } catch {
            Logger.appState.error("Schema decode failed: \(error.localizedDescription, privacy: .public)")
            schemaFields = []
        }
    }

    private func saveSchema() {
        do {
            var additional = draft.additional ?? [:]
            if schemaFields.isEmpty {
                additional.removeValue(forKey: schemaAdditionalKey)
                draft.additional = additional.isEmpty ? nil : additional
            } else {
                let data = try TierListCreatorCodec.makeEncoder().encode(schemaFields)
                let json = try TierListCreatorCodec.makeDecoder().decode(JSONValue.self, from: data)
                additional[schemaAdditionalKey] = json
                draft.additional = additional
            }
        } catch {
            Logger.appState.error("Schema encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistSchemaChange() {
        saveSchema()
        appState.markDraftEdited(draft)
    }
}

// MARK: - Add Schema Field Sheet
