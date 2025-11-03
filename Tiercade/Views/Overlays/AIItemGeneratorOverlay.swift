import SwiftUI
import TiercadeCore

/// AI-powered item generator overlay for tier list wizard.
///
/// Provides a 3-stage flow:
/// 1. **Input:** User enters description and item count
/// 2. **Progress:** Shows generation progress with spinner
/// 3. **Review:** Multi-selection list for curating generated items
///
/// - Note: Only available on macOS/iOS 26+. tvOS shows platform message.
/// - Note: All items default to selected; users deselect unwanted items.
internal struct AIItemGeneratorOverlay: View {
    @Bindable var appState: AppState
    internal let draft: TierProjectDraft

    @State private var itemDescription: String = ""
    @State private var itemCount: Int = 25
    @State private var searchText: String = ""
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif
    @FocusState private var focusedField: Field?
    @Namespace private var focusNamespace

    internal enum Field: Hashable {
        case description
        case count
    }

    private enum Stage {
        case input
        case generating
        case review
    }

    private var stage: Stage {
        if appState.aiGeneration.aiGenerationInProgress {
            return .generating
        } else if !appState.aiGeneration.aiGeneratedCandidates.isEmpty {
            return .review
        } else {
            return .input
        }
    }

    private var selectedCount: Int {
        appState.aiGeneration.aiGeneratedCandidates.filter(\.isSelected).count
    }

    private var filteredCandidates: [AIGeneratedItemCandidate] {
        if searchText.isEmpty {
            return appState.aiGeneration.aiGeneratedCandidates
        } else {
            return appState.aiGeneration.aiGeneratedCandidates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    internal var body: some View {
        NavigationStack {
            Group {
                switch stage {
        case .input:
                    inputForm
        case .generating:
                    generatingView
        case .review:
                    reviewList
                }
            }
            .navigationTitle("Generate Items with AI")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.aiGeneration.aiGenerationRequest = nil
                        appState.aiGeneration.aiGeneratedCandidates = []
                        appState.aiGeneration.aiGenerationInProgress = false
                    }
                }

                #if os(iOS)
                if stage == .review {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
                #endif
            }
        }
        .accessibilityIdentifier("AIGenerator_Overlay")
        #if os(tvOS)
        .onExitCommand {
            appState.aiGeneration.aiGenerationRequest = nil
            appState.aiGeneration.aiGeneratedCandidates = []
            appState.aiGeneration.aiGenerationInProgress = false
        }
        #endif
    }

    // MARK: - Input Form

    @ViewBuilder
    private var inputForm: some View {
        Form {
            Section {
                TextField("e.g., Best sci-fi movies of all time", text: $itemDescription)
                    .focused($focusedField, equals: .description)
                    #if os(tvOS)
                    .prefersDefaultFocus(true, in: focusNamespace)
                    #endif
                    #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                    #endif
                    .accessibilityIdentifier("AIGenerator_Description")
            } header: {
                Text("What kind of items?")
            }

            Section {
                #if os(tvOS)
                // tvOS: Stepper unavailable; use +/- controls
                HStack(spacing: Metrics.grid) {
                    Button {
                        itemCount = max(5, itemCount - 5)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.glass)
                    .focusable(interactions: .activate)
                    .accessibilityIdentifier("AIGenerator_CountMinus")

                    Text("\(itemCount)")
                        .font(.title2.monospacedDigit())
                        .frame(width: 80)

                    Button {
                        itemCount = min(100, itemCount + 5)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.glass)
                    .focusable(interactions: .activate)
                    .accessibilityIdentifier("AIGenerator_CountPlus")
                }
                .focusSection()
                #else
                // iOS/macOS: Hybrid TextField + Stepper
                HStack {
                    TextField("Count", value: $itemCount, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityIdentifier("AIGenerator_Count")
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)

                    Stepper("", value: $itemCount, in: 5...100, step: 5)
                        .labelsHidden()
                }
                #endif

                Text("Range: 5-100 items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("How many items?")
            }

            Section {
                Button {
                    Task {
                        await appState.generateItems(
                            description: itemDescription,
                            count: itemCount
                        )
                    }
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .disabled(itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("AIGenerator_Generate")
            }
        }
        #if os(tvOS)
        .focusScope(focusNamespace)
        #endif
        .onAppear {
            focusedField = .description
        }
    }

    // MARK: - Generating View

    @ViewBuilder
    private var generatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Generating Items...")
                .font(.title2)

            if !appState.loadingMessage.isEmpty {
                Text(appState.loadingMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review List

    @ViewBuilder
    private var reviewList: some View {
        VStack(spacing: 0) {
            // Selection counter
            Text("\(selectedCount) of \(appState.aiGeneration.aiGeneratedCandidates.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 8)

            // Item list with multi-selection
            List {
                ForEach(filteredCandidates) { candidate in
                    HStack {
                        #if os(iOS)
                        // iOS: Show checkboxes when not editing (EditMode available)
                        if editMode?.wrappedValue.isEditing == false || editMode == nil {
                            Image(systemName: candidate.isSelected
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(candidate.isSelected ? .green : .secondary)
                        }
                        #else
                        // macOS/tvOS: Always show checkboxes (no EditMode)
                        Image(systemName: candidate.isSelected
                              ? "checkmark.circle.fill"
                              : "circle")
                            .foregroundStyle(candidate.isSelected ? .green : .secondary)
                        #endif

                        Text(candidate.name)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        #if os(iOS)
                        // iOS: Toggle only when not editing (EditMode available)
                        if editMode?.wrappedValue.isEditing == false || editMode == nil {
                            appState.toggleCandidateSelection(candidate)
                        }
                        #else
                        // macOS/tvOS: Always allow toggling (no EditMode)
                        appState.toggleCandidateSelection(candidate)
                        #endif
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        appState.removeCandidate(filteredCandidates[index])
                    }
                }
            }
            #if !os(tvOS)
            .searchable(text: $searchText)
            #endif

            // Action bar
            HStack {
                Button("Regenerate") {
                    Task {
                        await appState.generateItems(
                            description: itemDescription,
                            count: itemCount
                        )
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    appState.importSelectedCandidates(into: draft)
                } label: {
                    Label("Import \(selectedCount) Items", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
                .accessibilityIdentifier("AIGenerator_Import")
            }
            .padding()
        }
    }
}
