import SwiftUI
import TiercadeCore
import os

// MARK: - Schema Wizard Page

struct SchemaWizardPage: View, WizardPage {
    @Bindable var appState: AppState
    @Bindable var draft: TierProjectDraft
    @State private var schemaFields: [SchemaFieldDefinition] = []
    @State private var showingAddField = false
    private let schemaAdditionalKey = "itemSchema"

    let pageTitle = "Item Schema"
    let pageDescription = "Define custom fields for your items"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Item Properties")
                        .font(.title2.weight(.semibold))

                    Text(
                        "Define what information each item should have. " +
                        "Examples: Year, Genre, Platform, Developer, Publisher"
                    )
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Built-in fields
                VStack(alignment: .leading, spacing: 16) {
                    Text("Built-in Fields")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        builtInFieldRow("Title", icon: "textformat", type: "Text", required: true)
                        builtInFieldRow("Subtitle", icon: "text.alignleft", type: "Text", required: false)
                        builtInFieldRow("Summary", icon: "doc.text", type: "Text Area", required: false)
                        builtInFieldRow("Rating", icon: "star", type: "Number", required: false)
                    }
                    .padding(.horizontal, 20)
                }

                Divider()
                    .padding(.horizontal, 20)

                // Custom fields
                VStack(alignment: .leading, spacing: 16) {
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
                        #else
                        .buttonStyle(.borderedProminent)
                        #endif
                        .accessibilityIdentifier("Schema_AddField")
                    }
                    .padding(.horizontal, 20)

                    if schemaFields.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No custom fields yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add fields to capture specific information about your items")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(schemaFields) { field in
                                customFieldRow(field)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .sheet(isPresented: $showingAddField) {
            AddSchemaFieldSheet(onAdd: { field in
                schemaFields.append(field)
                persistSchemaChange()
            })
        }
        .onAppear {
            loadSchema()
        }
    }

    private func builtInFieldRow(_ name: String, icon: String, type: String, required: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(type)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func customFieldRow(_ field: SchemaFieldDefinition) -> some View {
        HStack(spacing: 16) {
            Image(systemName: field.fieldType.icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(field.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(field.fieldType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if field.required {
                        Text("• Required")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if field.allowMultiple {
                        Text("• Multiple")
                            .font(.caption)
                            .foregroundStyle(.blue)
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
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

struct AddSchemaFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (SchemaFieldDefinition) -> Void

    @State private var fieldName = ""
    @State private var fieldType: SchemaFieldDefinition.FieldType = .text
    @State private var required = false
    @State private var allowMultiple = false
    @State private var options: [String] = []
    @State private var newOption = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Field Information") {
                    TextField("Field Name", text: $fieldName, prompt: Text("e.g., Genre, Year, Platform"))
                    #if !os(tvOS)
                        .textFieldStyle(.roundedBorder)
                    #endif

                    Picker("Field Type", selection: $fieldType) {
                        ForEach(SchemaFieldDefinition.FieldType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Required Field", isOn: $required)
                    Toggle("Allow Multiple Values", isOn: $allowMultiple)
                }

                if fieldType == .singleSelect || fieldType == .multiSelect {
                    Section("Select Options") {
                        ForEach(options, id: \.self) { option in
                            HStack {
                                Text(option)
                                Spacer()
                                Button(role: .destructive) {
                                    options.removeAll { $0 == option }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        HStack {
                            TextField("New Option", text: $newOption)
                            #if !os(tvOS)
                                .textFieldStyle(.roundedBorder)
                            #endif
                            Button {
                                if !newOption.isEmpty {
                                    options.append(newOption)
                                    newOption = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Add Custom Field")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let field = SchemaFieldDefinition(
                            name: fieldName,
                            fieldType: fieldType,
                            required: required,
                            allowMultiple: allowMultiple,
                            options: options
                        )
                        onAdd(field)
                        dismiss()
                    }
                    .disabled(fieldName.isEmpty)
                }
            }
        }
    }
}
