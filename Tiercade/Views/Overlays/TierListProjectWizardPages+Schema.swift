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

#if os(tvOS)
    @Namespace private var defaultFocusNamespace
#endif

    var body: some View {
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
                                .font(.system(size: 48))
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
                "Define what information each item should have. Examples include Year, Genre, Platform, Developer, or Publisher."
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
                            .foregroundStyle(Palette.tierColor("S"))
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
                .foregroundStyle(Palette.tierColor("B"))
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
                            .foregroundStyle(Palette.tierColor("S"))
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

struct AddSchemaFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (SchemaFieldDefinition) -> Void

    @State private var fieldName = ""
    @State private var fieldType: SchemaFieldDefinition.FieldType = .text
    @State private var required = false
    @State private var allowMultiple = false
    @State private var options: [String] = []
    @State private var newOption = ""

    private let gridColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 16)
    ]

    var body: some View {
        #if os(tvOS)
        // tvOS: Custom header approach for better control
        ZStack {
            // Solid background layer
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Text("Add Custom Field")
                        .font(.title2.weight(.semibold))

                    Spacer()

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
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .glassEffect(.regular, in: Rectangle())

                // Content area
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            fieldDetailsSection

                            if geometry.size.width > 900 {
                                HStack(alignment: .top, spacing: 28) {
                                    typeSelectionSection
                                        .frame(minWidth: 480)

                                    VStack(alignment: .leading, spacing: 28) {
                                        entryOptionsSection

                                        if fieldType == .singleSelect || fieldType == .multiSelect {
                                            selectOptionsSection
                                        }
                                    }
                                    .frame(maxWidth: 400)
                                }
                            } else {
                                typeSelectionSection
                                entryOptionsSection

                                if fieldType == .singleSelect || fieldType == .multiSelect {
                                    selectOptionsSection
                                }
                            }
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 32)
                    }
                }
            }
        }
        .onChange(of: fieldType) { newType in
            guard newType != .multiSelect else { return }
            if newType == .singleSelect {
                allowMultiple = false
            }
            if newType != .singleSelect {
                options.removeAll()
            }
        }
        #else
        // iOS/iPadOS: Standard NavigationStack
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        fieldDetailsSection

                        if geometry.size.width > 900 {
                            HStack(alignment: .top, spacing: 28) {
                                typeSelectionSection
                                    .frame(minWidth: 480)

                                VStack(alignment: .leading, spacing: 28) {
                                    entryOptionsSection

                                    if fieldType == .singleSelect || fieldType == .multiSelect {
                                        selectOptionsSection
                                    }
                                }
                                .frame(maxWidth: 400)
                            }
                        } else {
                            typeSelectionSection
                            entryOptionsSection

                            if fieldType == .singleSelect || fieldType == .multiSelect {
                                selectOptionsSection
                            }
                        }
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 32)
                }
            }
            .background {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle("Add Custom Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
        .onChange(of: fieldType) { newType in
            guard newType != .multiSelect else { return }
            if newType == .singleSelect {
                allowMultiple = false
            }
            if newType != .singleSelect {
                options.removeAll()
            }
        }
        #endif
    }

    private var fieldDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Details")
                .font(.headline.weight(.semibold))

            TextField("Field Name", text: $fieldName, prompt: Text("e.g., Genre, Platform, Developer"))
            #if os(tvOS)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                }
                .focusEffectDisabled(false)
            #else
                .textFieldStyle(.roundedBorder)
            #endif
                .accessibilityIdentifier("Schema_FieldName")

            Text("Give the field a clear label so editors know what to enter.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Field Type")
                .font(.title3.weight(.semibold))

            fieldTypeGrid
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var fieldTypeGrid: some View {
        let grid = LazyVGrid(columns: gridColumns, spacing: 24) {
            ForEach(SchemaFieldDefinition.FieldType.allCases, id: \.self) { type in
                FieldTypeCard(
                    type: type,
                    isSelected: fieldType == type
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        fieldType = type
                    }
                }
            }
        }

        #if os(tvOS)
        return grid
            .focusSection()
        #else
        return grid
        #endif
    }

    private var entryOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Entry Options")
                .font(.headline.weight(.semibold))

            Toggle("Required Field", isOn: $required)
                .accessibilityIdentifier("Schema_FieldRequired")

            Toggle("Allow Multiple Values", isOn: $allowMultiple)
                .accessibilityIdentifier("Schema_FieldAllowMultiple")
                .disabled(fieldType == .singleSelect)
                .opacity(fieldType == .singleSelect ? 0.4 : 1.0)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var selectOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Options")
                .font(.headline.weight(.semibold))

            if options.isEmpty {
                Text("Add choices so editors can pick from a curated list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(options, id: \.self) { option in
                    HStack {
                        Text(option)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Button(role: .destructive) {
                            options.removeAll { $0 == option }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Schema_Option_Remove_\(option)")
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            HStack(spacing: 12) {
                TextField("New Option", text: $newOption)
                #if os(tvOS)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    }
                    .focusEffectDisabled(false)
                #else
                    .textFieldStyle(.roundedBorder)
                #endif

                Button {
                    let trimmed = newOption.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    options.append(trimmed)
                    newOption = ""
                } label: {
                    Label("Add Option", systemImage: "plus.circle.fill")
                        .font(.callout.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                #if os(tvOS)
                .buttonStyle(.glass)
                #else
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                #endif
                .accessibilityIdentifier("Schema_Option_Add")
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }
}

// MARK: - Field Type Support Views

private struct FieldTypeCard: View {
    let type: SchemaFieldDefinition.FieldType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)

                    Text(type.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested uses:")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(type.suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.black.opacity(0.8) : Color.black.opacity(0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        #if os(tvOS)
        .buttonStyle(.plain)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityIdentifier("Schema_FieldType_\(type.rawValue)")
    }
}

private struct FieldTypeDetailView: View {
    let type: SchemaFieldDefinition.FieldType

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title2.weight(.semibold))
                Text(type.displayName)
                    .font(.title2.weight(.semibold))
            }

            Text(type.guidance)
                .font(.body)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Example")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(type.exampleValue)
                    .font(.body.monospacedDigit())
            }
        }
        .padding(24)
        .tvGlassRounded(24)
    }
}
