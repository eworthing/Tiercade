# AI-Powered Tier List Item Generation - Implementation Plan

**Status:** Planning Phase
**Created:** 2025-10-31
**Estimated Effort:** 14-20 hours (2-3 work days)
**Platform Support:** tvOS-first UI (independent); macOS/iOS enable Apple Intelligence generation. tvOS shows an informative message (no AI session) per platform gating.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [User Requirements](#user-requirements)
3. [Architecture Overview](#architecture-overview)
4. [UI/UX Flow](#uiux-flow)
5. [Data Models](#data-models)
6. [State Management](#state-management)
7. [Implementation Phases](#implementation-phases)
8. [File Structure](#file-structure)
9. [Accessibility Reference](#accessibility-reference)
10. [Testing Strategy](#testing-strategy)
11. [Risk Assessment](#risk-assessment)
12. [Design Decisions](#design-decisions)

---

## Executive Summary

### Goal

Add an AI-powered item generation feature to the tier list creation wizard that allows users to:

1. Describe the type of items they want (text input)
2. Specify the number of items (numeric input, 5-100 range)
3. Generate a list using Apple Intelligence
4. Review generated items with all selected by default
5. Deselect/remove unwanted items before importing
6. Save the curated list to their tier list draft

### Integration Point

Add to the **Items page** of the existing `TierListProjectWizard` as an optional "Generate with AI" feature.

### Key Benefits

- **Accelerates tier list creation** - Generate 50+ items in seconds
- **Maintains quality control** - User reviews and curates before import
- **Platform-appropriate UX** - Optimized for tvOS/iOS/macOS
- **Reuses existing AI infrastructure** - Leverages `UniqueListCoordinator`

---

## User Requirements

### Functional Requirements

1. **FR-1:** User can open AI generator from Items page via dedicated button
2. **FR-2:** User can enter natural language description of items (e.g., "Best sci-fi movies of all time")
3. **FR-3:** User can specify item count between 5-100 using numeric input
4. **FR-4:** System generates unique items using Apple Intelligence
5. **FR-5:** System shows progress during generation
6. **FR-6:** User can review generated items in a multi-selection list
7. **FR-7:** All items are selected by default upon generation
8. **FR-8:** User can toggle selection of individual items
9. **FR-9:** User can search/filter items (iOS/macOS only)
10. **FR-10:** User can delete items from the candidate list
11. **FR-11:** User can import selected items to draft
12. **FR-12:** System deduplicates against existing draft items
13. **FR-13:** User can regenerate with same parameters
14. **FR-14:** User can cancel at any stage

### Non-Functional Requirements

1. **NFR-1:** Platform Support - macOS/iOS only; tvOS shows informative message
2. **NFR-2:** Performance - Generate 50 items within 30 seconds
3. **NFR-3:** Accessibility - All controls have accessibility IDs for UI testing
4. **NFR-4:** Focus Management - Default focus on tvOS follows platform conventions
5. **NFR-5:** Error Handling - Graceful degradation on generation failure
6. **NFR-6:** Concurrency - Swift 6 strict concurrency compliance
7. **NFR-7:** Code Quality - SwiftLint compliant, cyclomatic complexity ≤ 8

---

## Architecture Overview

### Component Architecture

```
┌─────────────────────────────────────────────────────────┐
│              TierListProjectWizard (Items Page)          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  [Generate with AI] Button                         │ │
│  └──────────────────┬─────────────────────────────────┘ │
└─────────────────────┼───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              AIItemGeneratorOverlay (Sheet)              │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Stage 1: Input Form                             │   │
│  │  - Description TextField                         │   │
│  │  - Count Stepper/TextField                       │   │
│  │  - [Generate] [Cancel] Buttons                   │   │
│  └──────────────────────────────────────────────────┘   │
│                      │                                   │
│                      ▼                                   │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Stage 2: Progress View                          │   │
│  │  - ProgressView spinner                          │   │
│  │  - Progress message from AppState                │   │
│  │  - Percentage indicator                          │   │
│  └──────────────────────────────────────────────────┘   │
│                      │                                   │
│                      ▼                                   │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Stage 3: Review & Selection                     │   │
│  │  - Search bar (iOS/macOS only)                   │   │
│  │  - Multi-selection List                          │   │
│  │  - Selection counter                             │   │
│  │  - [Import] [Regenerate] Buttons                 │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   AppState+AIGeneration                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │  • presentAIItemGenerator()                      │   │
│  │  • generateItems(description:count:)             │   │
│  │  • toggleCandidateSelection(_:)                  │   │
│  │  • importSelectedCandidates(into:)               │   │
│  └──────────────────┬───────────────────────────────┘   │
└─────────────────────┼───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  UniqueListCoordinator (reused)           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Reuses existing UniqueListCoordinator logic     │   │
│  │  • Generate → Dedup → Backfill loop              │   │
│  │  • Progress callbacks                            │   │
│  │  • Platform-gated (macOS/iOS only)               │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Integration Strategy

**Chosen Approach:** Items Page Integration

**Rationale:**
- ✅ Preserves existing wizard flow (Settings → Schema → Items → Tiers)
- ✅ AI generation is optional, doesn't force users through extra steps
- ✅ Natural location - users are already on Items page when they need items
- ✅ Can reuse existing `AppleIntelligenceService` and `UniqueListCoordinator`
- ✅ Maintains tvOS-first UX with proper focus management

**Alternative Considered (Rejected):** Standalone wizard page
- ❌ Adds unnecessary navigation complexity
- ❌ Breaks existing wizard flow
- ❌ Harder to integrate generated items

---

## UI/UX Flow

### Entry Point (Items Page)

```swift
// In TierListProjectWizardPages+Items.swift
Button {
    showAIGenerator = true
} label: {
    Label("Generate with AI", systemImage: "sparkles.rectangle.stack")
}
.accessibilityIdentifier("ItemsPage_GenerateAI")
```

**Placement:** Toolbar or prominent position above item list

**Platform Behavior:**
- **macOS/iOS:** Opens full `AIItemGeneratorOverlay` sheet
- **tvOS:** Shows alert: "AI generation requires macOS or iOS"

---

### Stage 1: Input Form

```
┌─────────────────────────────────────────┐
│  Generate Items with AI                  │
├─────────────────────────────────────────┤
│                                          │
│  What kind of items?                     │
│  ┌────────────────────────────────────┐ │
│  │ Best sci-fi movies of all time     │ │ (TextField)
│  └────────────────────────────────────┘ │
│                                          │
│  How many items?                         │
│  ┌──────┐                               │
│  │  50  │  [−]  [+]                     │ (Stepper/TextField)
│  └──────┘                               │
│  (Range: 5-100)                         │
│                                          │
│  [ Generate ]  [ Cancel ]               │
└─────────────────────────────────────────┘
```

**Focus Behavior (tvOS):**
- Default focus: Description TextField
- Navigation: Down arrow → Count → Generate button
- Exit: Menu button dismisses overlay

**Validation:**
- Description cannot be empty (disables Generate button)
- Count must be 5-100 (enforced by Stepper range)

**Platform-Specific Number Input:**

**tvOS (Stepper unavailable on tvOS):**
```swift
HStack(spacing: Metrics.padding) {
    Button("-") { itemCount = max(5, itemCount - 5) }
        .buttonStyle(.glass)
        .focusable(interactions: .activate)
    Text("\(itemCount)")
        .font(.title2.monospacedDigit())
        .frame(minWidth: 72)
    Button("+") { itemCount = min(100, itemCount + 5) }
        .buttonStyle(.glass)
        .focusable(interactions: .activate)
}
.focusSection()
```

**iOS/macOS:**
```swift
HStack {
    TextField("Count", value: $itemCount, format: .number)
        .keyboardType(.numberPad)  // iOS only
        .frame(width: 80)

    Stepper("", value: $itemCount, in: 5...100, step: 5)
        .labelsHidden()
}
```

---

### Stage 2: Generation Progress

```
┌─────────────────────────────────────────┐
│  Generating Items...                     │
├─────────────────────────────────────────┤
│                                          │
│         ⚙️  Working...                   │
│                                          │
│  Generated: 32 / 50                      │
│  [████████░░░░] 64%                      │
│                                          │
└─────────────────────────────────────────┘
```

**Progress Updates:**
- Uses existing `AppState.currentProgress` API
- Updates via `updateProgress(_:)` method
- Shows message + percentage from coordinator progress

**State Transitions:**
- Auto-transitions to Review stage when generation completes
- On error: Shows toast, returns to Input stage

---

### Stage 3: Review & Selection

```
┌─────────────────────────────────────────┐
│  Review Generated Items (50)             │
│  All items selected • [Edit] button      │
├─────────────────────────────────────────┤
│  Search: [        ]                      │  ← iOS/macOS only
│                                          │
│  ☑️ Blade Runner                         │
│  ☑️ The Matrix                           │
│  ☑️ 2001: A Space Odyssey                │
│  ☑️ Star Wars: A New Hope                │
│  ☑️ Interstellar                         │
│  ...                                     │
│                                          │
│  45 of 50 selected                       │
│  [ Import Selected ]  [ Regenerate ]     │
└─────────────────────────────────────────┘
```

**Interaction Patterns:**

**Selection Toggle (Outside Edit Mode):**
- Tap item → Toggle checkmark
- Checkmark: ☑️ (green) = selected
- Circle: ⭕ (gray) = unselected

**Edit Mode:**
- Tap "Edit" button → Enter `EditMode.active`
- Shows standard delete controls (red minus buttons)
- Swipe-to-delete on iOS/macOS
- "Done" button to exit edit mode

**Search (iOS/macOS only):**
- Use `.searchable(text:)` on container per SwiftUI docs
- Filter candidates by name
- Case-insensitive search
- Live filtering as user types

**Selection Counter:**
- Live updates: "X of Y selected"
- Updates on toggle/delete

**Action Buttons:**
- **Import:** Disabled if selection count = 0
- **Regenerate:** Reopens input form with same parameters

---

## Data Models

### AIGenerationRequest

```swift
// File: Tiercade/State/Wizard/AIGenerationModels.swift

struct AIGenerationRequest: Sendable {
    let description: String
    let itemCount: Int
    let timestamp: Date

    var isValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && itemCount >= 5
        && itemCount <= 100
    }
}
```

**Purpose:** Captures user input for generation request
**Validation:** Ensures description is non-empty and count is in valid range

---

### AIGeneratedItemCandidate

```swift
// File: Tiercade/State/Wizard/AIGenerationModels.swift

struct AIGeneratedItemCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    var isSelected: Bool  // Mutable for toggle
    let generatedAt: Date

    init(name: String, isSelected: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isSelected = isSelected  // Default: selected
        self.generatedAt = Date()
    }
}
```

**Purpose:** Represents an AI-generated item awaiting user review
**Default State:** All items start as selected
**Mutability:** Only `isSelected` can change after creation

---

## State Management

### New State Properties (AppState)

```swift
// File: Tiercade/State/AppState.swift or AppState+AIGeneration.swift

extension AppState {
    // MARK: - AI Item Generation State

    /// Whether the AI item generator overlay is visible
    internal var showAIItemGenerator: Bool = false

    /// Current generation request (preserves parameters for regeneration)
    internal var aiGenerationRequest: AIGenerationRequest?

    /// Generated item candidates awaiting review
    internal var aiGeneratedCandidates: [AIGeneratedItemCandidate] = []

    /// Whether generation is in progress
    internal var aiGenerationInProgress: Bool = false
}
```

---

### Core Methods (AppState+AIGeneration.swift)

#### presentAIItemGenerator()

```swift
/// Present the AI item generator overlay
func presentAIItemGenerator() {
    showAIItemGenerator = true
    aiGenerationRequest = nil
    aiGeneratedCandidates = []
}
```

**Purpose:** Opens overlay and resets state
**Called From:** Items page "Generate with AI" button

---

#### dismissAIItemGenerator()

```swift
/// Dismiss the AI item generator overlay
func dismissAIItemGenerator() {
    showAIItemGenerator = false
    aiGenerationRequest = nil
    aiGeneratedCandidates = []
}
```

**Purpose:** Closes overlay and cleans up state
**Called From:** Cancel button, successful import, tvOS exit command

---

#### generateItems(description:count:)

```swift
/// Generate items using AI
/// - Parameters:
///   - description: Natural language description of items (e.g., "Best sci-fi movies")
///   - count: Target number of items (5-100)
func generateItems(description: String, count: Int) async {
    let request = AIGenerationRequest(
        description: description,
        itemCount: count,
        timestamp: Date()
    )

    guard request.isValid else {
        showToast("Invalid request", style: .error)
        return
    }

    aiGenerationRequest = request
    aiGenerationInProgress = true

    await withLoadingIndicator(message: "Generating \(count) items...") {
        do {
            // Reuse UniqueListCoordinator (AppleIntelligence)
            let items = try await generateUniqueListForWizard(
                query: description,
                count: count
            )

            // Convert to candidates (all selected by default)
            aiGeneratedCandidates = items.map {
                AIGeneratedItemCandidate(name: $0, isSelected: true)
            }

            showToast("Generated \(items.count) items", style: .success)
        } catch {
            showToast("Generation failed: \(error.localizedDescription)", style: .error)
            aiGeneratedCandidates = []
        }
    }

    aiGenerationInProgress = false
}
```

**Purpose:** Orchestrates AI generation with progress tracking
**Error Handling:** Shows toast on failure, clears candidates
**Progress:** Uses `withLoadingIndicator` from existing AppState+Progress

---

#### toggleCandidateSelection(_:)

```swift
/// Toggle selection state for a candidate
/// - Parameter candidate: The candidate to toggle
func toggleCandidateSelection(_ candidate: AIGeneratedItemCandidate) {
    guard let index = aiGeneratedCandidates.firstIndex(where: { $0.id == candidate.id }) else {
        return
    }
    aiGeneratedCandidates[index].isSelected.toggle()
}
```

**Purpose:** Toggles checkmark state
**Called From:** List item tap gesture (outside edit mode)

---

#### removeCandidate(_:)

```swift
/// Remove a candidate completely from the list
/// - Parameter candidate: The candidate to remove
func removeCandidate(_ candidate: AIGeneratedItemCandidate) {
    aiGeneratedCandidates.removeAll { $0.id == candidate.id }
}
```

**Purpose:** Deletes candidate (vs. just deselecting)
**Called From:** Edit mode delete action

---

#### importSelectedCandidates(into:)

```swift
/// Import selected candidates into tier list draft
/// - Parameter draft: The tier list draft to import into
func importSelectedCandidates(into draft: TierProjectDraft) {
    let selected = aiGeneratedCandidates.filter { $0.isSelected }

    // Deduplication: Check against existing draft items
    let existingTitles = Set(draft.items.map { $0.title.lowercased() })
    let uniqueCandidates = selected.filter {
        !existingTitles.contains($0.name.lowercased())
    }

    let skippedCount = selected.count - uniqueCandidates.count

    // Create TierDraftItems from candidates
    for candidate in uniqueCandidates {
        let item = TierDraftItem(
            itemId: "item-\(UUID().uuidString)",
            title: candidate.name,
            subtitle: "",
            summary: "",
            slug: "item-\(UUID().uuidString)",
            ordinal: draft.items.count
        )
        item.project = draft
        draft.items.append(item)
    }

    markDraftEdited(draft)

    // Show appropriate toast
    if skippedCount > 0 {
        showToast(
            "Imported \(uniqueCandidates.count) items (\(skippedCount) duplicates skipped)",
            style: .success
        )
    } else {
        showToast("Imported \(uniqueCandidates.count) items", style: .success)
    }

    dismissAIItemGenerator()
}
```

**Purpose:** Creates TierDraftItems from selected candidates
**Deduplication:** Always checks against existing draft items (case-insensitive)
**Feedback:** Shows toast with import count + duplicate count
**Side Effects:** Marks draft as edited, dismisses overlay

---

### Private Helper: generateUniqueListForWizard(query:count:)

```swift
/// Reuse existing UniqueListCoordinator from AppleIntelligence.
/// Keep prototype surface small and reuse the existing session.
private func generateUniqueListForWizard(query: String, count: Int) async throws -> [String] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
        guard let session else {
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])
        }
        let fm = FMClient(session: session, logger: { _ in })
        let coordinator = UniqueListCoordinator(
            fm: fm,
            logger: { _ in },
            useGuidedBackfill: true
        )
        return try await coordinator.uniqueList(query: query, targetCount: count, seed: nil)
    }
    #endif
    throw NSError(domain: "AI", code: -2, userInfo: [NSLocalizedDescriptionKey: "AI generation is only available on macOS and iOS 26+"])
}
```

**Implementation Note:** This requires refactoring existing coordinator logic (see Phase 1, Task 1.1)

---

## Implementation Phases

### Phase 1: Core Infrastructure (4-6 hours)

#### Task 1.1: Wire Wizard to Existing UniqueListCoordinator

**Files to Modify:**
- `Tiercade/State/AppState+AppleIntelligence.swift` (optional, reuse `session`)
- `Tiercade/State/AppState+AIGeneration.swift` (new)

**Actions:**
1. Add `generateUniqueListForWizard(query:count:)` wrapper that instantiates `FMClient` with the existing `session` and calls `UniqueListCoordinator.uniqueList(...)`.
2. Gate with `#if canImport(FoundationModels)` and `@available(iOS 26, macOS 26, *)`.
3. Use existing progress helpers (`withLoadingIndicator`, `updateProgress`).
4. Leverage existing telemetry; avoid introducing new retry state.

**Acceptance Criteria:**
- [ ] Wrapper calls `UniqueListCoordinator.uniqueList(query:targetCount:)`
- [ ] Platform-gated for macOS/iOS only
- [ ] Uses existing `session` to avoid duplicate session wiring
- [ ] No new coordinator type introduced

---

#### Task 1.2: Create Data Models

**Files to Create:**
- `Tiercade/State/Persistence/AIGenerationModels.swift`

**Models to Define:**
- `AIGenerationRequest` (see Data Models section)
- `AIGeneratedItemCandidate` (see Data Models section)

**Acceptance Criteria:**
- [ ] Models conform to `Sendable` for Swift 6 concurrency
- [ ] `AIGenerationRequest` has validation logic
- [ ] `AIGeneratedItemCandidate` defaults to selected
- [ ] All properties are `let` except `isSelected`
- [ ] Models are `Hashable` and `Identifiable`

---

#### Task 1.3: Add AppState Extension

**Files to Create:**
- `Tiercade/State/AppState+AIGeneration.swift`

**State Properties:**
- `showAIItemGenerator: Bool`
- `aiGenerationRequest: AIGenerationRequest?`
- `aiGeneratedCandidates: [AIGeneratedItemCandidate]`
- `aiGenerationInProgress: Bool`

**Methods to Implement:**
- `presentAIItemGenerator()`
- `dismissAIItemGenerator()`
- `generateItems(description:count:) async`
- `toggleCandidateSelection(_:)`
- `removeCandidate(_:)`
- `importSelectedCandidates(into:)`

**Acceptance Criteria:**
- [ ] All methods are `@MainActor`
- [ ] Uses `withLoadingIndicator` for async generation
- [ ] Shows toast on success/error
- [ ] Deduplicates against existing draft items
- [ ] Platform-gated for macOS/iOS only
- [ ] Progress updates via `updateProgress(_:)`

---

### Phase 2: UI Implementation (6-8 hours)

#### Task 2.1: Create AI Generator Overlay

**Files to Create:**
- `Tiercade/Views/Overlays/AIItemGeneratorOverlay.swift`

**Components:**

**Stage 1: Input Form**
- Description TextField with focus management
- Count Stepper/TextField (platform-specific)
- Generate Button (disabled if description empty)
- Cancel Button

**Stage 2: Loading**
- ProgressView spinner
- Progress message from AppState
- Percentage indicator

**Stage 3: Review & Selection**
- Search bar (iOS/macOS only)
- Multi-selection List with checkmarks
- Selection counter
- Import button (disabled if count = 0)
- Regenerate button

**Platform Variations:**

```swift
#if os(tvOS)
// Stepper is unavailable on tvOS; use +/- buttons and action-only focus
HStack {
    Button("-") { itemCount = max(5, itemCount - 5) }.buttonStyle(.glass).focusable(interactions: .activate)
    Text("\(itemCount)").font(.title2.monospacedDigit())
    Button("+") { itemCount = min(100, itemCount + 5) }.buttonStyle(.glass).focusable(interactions: .activate)
}

// No search bar (focus complexity)
// Glass effects with proper spacing (.glassBackgroundEffect)
#else
// TextField + Stepper for numbers
HStack {
    TextField("Count", value: $itemCount, format: .number)
        .keyboardType(.numberPad)  // iOS only
    Stepper("", value: $itemCount, in: 5...100, step: 5)
}

// Search bar above list
 .searchable(text: $searchText, placement: .automatic)

// Standard material backgrounds
#endif
```

**Focus Management (tvOS):**

```swift
@Namespace private var focusNamespace
@FocusState private var focusedField: Field?

enum Field: Hashable {
    case description
    case count
}

// In input form:
TextField("Description", text: $description)
    .focused($focusedField, equals: .description)
    .prefersDefaultFocus(true, in: focusNamespace)

// Container:
.focusScope(focusNamespace)
.onAppear {
    focusedField = .description
}

// Exit handling:
#if os(tvOS)
.onExitCommand {
    appState.dismissAIItemGenerator()
}
#endif
```

**Acceptance Criteria:**
- [ ] Three-stage UI flows correctly (input → generating → review)
- [ ] Focus lands on description field on appear
- [ ] Default focus on tvOS uses `prefersDefaultFocus`
- [ ] Exit command handler for tvOS (`.onExitCommand`)
- [ ] Accessibility IDs for all interactive elements
- [ ] Glass effects follow existing `GlassEffectContainer` pattern (tvOS)
- [ ] **CRITICAL:** Solid backgrounds for text input areas (no glass behind TextFields)
- [ ] Platform-specific number input (tvOS uses +/- controls; iOS/macOS use TextField + Stepper)
- [ ] Search bar only on iOS/macOS
- [ ] Navigation title and toolbar buttons

---

#### Task 2.2: Add Multi-Selection List

**List Requirements:**
- Bind to `Set<UUID>` for selection tracking
- Show checkmark indicators when not in edit mode
- Support EditMode for delete operations (iOS). On macOS, prefer context menu or a trailing destructive button because the `editMode` environment isn’t available.
- Custom tap handler for checkbox toggle
- `.onDelete` modifier for swipe-to-delete

**Code Pattern:**

```swift
@Environment(\.editMode) private var editMode

List(selection: editMode?.wrappedValue.isEditing == true
     ? nil
     : Binding<Set<UUID>>(
         get: {
             Set(appState.aiGeneratedCandidates.filter(\.isSelected).map(\.id))
         },
         set: { newSelection in
             for candidate in appState.aiGeneratedCandidates {
                 let shouldBeSelected = newSelection.contains(candidate.id)
                 if candidate.isSelected != shouldBeSelected {
                     appState.toggleCandidateSelection(candidate)
                 }
             }
         }
     )
) {
    ForEach(filteredCandidates) { candidate in
        HStack {
            if editMode?.wrappedValue.isEditing == false || editMode == nil {
                Image(systemName: candidate.isSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .foregroundStyle(candidate.isSelected ? .green : .secondary)
            }
            Text(candidate.name)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if editMode?.wrappedValue.isEditing == false || editMode == nil {
                appState.toggleCandidateSelection(candidate)
            }
        }
    }
    .onDelete { indexSet in
        for index in indexSet {
            appState.removeCandidate(filteredCandidates[index])
        }
    }
}
.toolbar {
    #if !os(macOS)
    EditButton()
    #endif
}
```

**Acceptance Criteria:**
- [ ] All items selected by default
- [ ] Tap toggles selection (outside edit mode)
- [ ] Edit mode shows standard delete controls
- [ ] Selection count updates reactively
- [ ] Import button disabled when selection count = 0
- [ ] Search filters list correctly (iOS/macOS)
- [ ] Delete removes from candidates array

---

#### Task 2.3: Integrate into Wizard Items Page

**Files to Modify:**
- `Tiercade/Views/Overlays/TierListProjectWizardPages+Items.swift`

**Changes:**

1. Add state:
```swift
@State private var showAIGenerator = false
```

2. Add button (toolbar or above list):
```swift
Button {
    showAIGenerator = true
} label: {
    Label("Generate with AI", systemImage: "sparkles.rectangle.stack")
}
.accessibilityIdentifier("ItemsPage_GenerateAI")
```

3. Add sheet presentation:
```swift
.sheet(isPresented: $showAIGenerator) {
    #if os(macOS) || os(iOS)
    AIItemGeneratorOverlay(appState: appState, draft: draft)
    #else
    // tvOS: Show informative message
    VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundStyle(.orange)
        Text("AI Generation Requires macOS or iOS")
            .font(.title2)
        Text("Please use the companion iOS or macOS app to generate items with AI.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        Button("OK") {
            showAIGenerator = false
        }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    #endif
}
```

**Acceptance Criteria:**
- [ ] Button appears prominently on Items page
- [ ] Sheet presentation works on all platforms
- [ ] tvOS shows informative message (no AI support)
- [ ] macOS/iOS show full overlay
- [ ] Accessibility ID set correctly
- [ ] Button placement follows existing toolbar patterns

---

### Phase 3: Polish & Testing (3-4 hours)

#### Task 3.1: Focus Management (tvOS)

**Focus Requirements:**
1. Description field receives default focus on appear
2. Generate button is easily reachable via down navigation
3. In review stage, list receives focus
4. Edit button accessible via standard navigation
5. Exit command dismisses overlay

**Implementation:**

```swift
@Namespace private var focusNamespace
@FocusState private var focusedField: Field?

enum Field: Hashable {
    case description
    case count
    case generateButton
}

// In input form:
TextField("Description", text: $description)
    .focused($focusedField, equals: .description)
    .prefersDefaultFocus(true, in: focusNamespace)

Stepper("Count", value: $itemCount)
    .focused($focusedField, equals: .count)

Button("Generate") { ... }
    .focused($focusedField, equals: .generateButton)

// Container:
.focusScope(focusNamespace)
.onAppear {
    focusedField = .description
}

#if os(tvOS)
.onExitCommand {
    appState.dismissAIItemGenerator()
}
#endif
```

**Acceptance Criteria:**
- [ ] Default focus lands correctly on tvOS
- [ ] Focus transitions feel natural between sections
- [ ] Exit command dismisses overlay (tvOS)
- [ ] No focus traps or dead zones
- [ ] Focus visual feedback matches platform conventions

---

#### Task 3.2: Error Handling & Edge Cases

**Scenarios to Handle:**

| Scenario | Behavior |
|----------|----------|
| Empty description | Disable generate button |
| Generation failure | Show error toast, keep form visible |
| Zero results | Show "No items generated" message |
| All items deselected | Disable import button |
| Duplicate items | Show count in toast: "Imported X (Y duplicates skipped)" |
| Platform not supported (tvOS) | Show message in sheet |
| Timeout | Show timeout error toast |

**Error Messages:**

```swift
// In generateItems method:
catch {
    if let genError = error as? GenerationError {
        showToast(genError.localizedDescription, style: .error)
    } else {
        showToast("Unexpected error occurred", style: .error)
        appendDebugFile("AI Generation Error: \(error)")
    }
    aiGeneratedCandidates = []
}
```

**Acceptance Criteria:**
- [ ] All error paths show appropriate messages
- [ ] Failed generation returns to input form (doesn't dismiss)
- [ ] Toast messages are user-friendly
- [ ] No silent failures
- [ ] Debug log captures unexpected errors
- [ ] Empty results show helpful message

---

#### Task 3.3: Platform Testing

**Test Matrix:**

| Platform | Test Case | Expected Result |
|----------|-----------|-----------------|
| **tvOS** | Button on Items page | Shows "Requires macOS/iOS" message in sheet |
| **tvOS** | Focus navigation | Message sheet has focusable OK button |
| **iOS** | TextField number input | Number pad keyboard appears |
| **iOS** | Multi-selection | Tap toggles checkmark, edit mode shows delete |
| **iOS** | Search | Filters list case-insensitively |
| **macOS** | TextField input | Standard keyboard, accepts typed numbers |
| **macOS** | Multi-selection | Command-click works without edit mode |
| **macOS** | Search | Search bar appears and filters correctly |
| **All (macOS/iOS)** | Generate 25 items | Shows progress, returns ≤25 unique items |
| **All (macOS/iOS)** | Deselect all → Import | Import button disabled |
| **All (macOS/iOS)** | Import 10 items | Adds 10 TierDraftItems to draft |
| **All (macOS/iOS)** | Regenerate | Reopens input with same parameters |
| **All (macOS/iOS)** | Duplicate detection | Skips existing items, shows count |

**Manual Test Steps:**

1. Open tier list wizard
2. Navigate to Items page
3. Click "Generate with AI"
4. **macOS/iOS:** Enter description: "Best PlayStation games"
5. **macOS/iOS:** Set count: 30
6. **macOS/iOS:** Click Generate
7. **macOS/iOS:** Wait for generation (verify progress updates)
8. **macOS/iOS:** Review list (verify all selected by default)
9. **macOS/iOS:** Deselect 5 items
10. **macOS/iOS:** Click Import
11. **macOS/iOS:** Verify 25 items added to draft
12. **tvOS:** Verify message sheet appears, OK button dismisses

**Acceptance Criteria:**
- [ ] All platforms tested in simulator
- [ ] Focus behavior validated on tvOS
- [ ] Multi-selection works correctly on all platforms
- [ ] Import adds correct number of items
- [ ] Deduplication works (test by importing twice)
- [ ] No crashes or runtime warnings
- [ ] Build timestamp in `BuildInfoView` matches test build

---

#### Task 3.4: Code Quality & Documentation

**SwiftLint Compliance:**
- [ ] No cyclomatic complexity warnings (threshold: 8, error: 12)
- [ ] File length under 600 lines (split if needed)
- [ ] Function body length under 40 lines
- [ ] No force unwrapping
- [ ] No unused code

**Documentation:**
- [ ] Add doc comments to public methods
- [ ] Document platform limitations
- [ ] Add example usage in comments
- [ ] Update CLAUDE.md if needed (add to prototype scope)

**Example Doc Comments:**

```swift
/// Generates a list of unique items using Apple Intelligence.
///
/// This method orchestrates the full generation flow:
/// 1. Validates input parameters
/// 2. Calls `UniqueListCoordinator` via wrapper with progress
/// 3. Converts results to `AIGeneratedItemCandidate` instances
/// 4. Shows success/error feedback via toast
///
/// - Parameters:
///   - description: Natural language description of items to generate (e.g., "Best sci-fi movies")
///   - count: Target number of items (valid range: 5-100)
///
/// - Note: Only available on macOS and iOS. Falls back gracefully on tvOS.
/// - Note: Uses existing `withLoadingIndicator` for progress UI
///
/// - Requires: `description` must be non-empty, `count` must be 5-100
///
/// Example:
/// ```swift
/// await appState.generateItems(description: "Top 80s songs", count: 50)
/// ```
@MainActor
func generateItems(description: String, count: Int) async
```

**Acceptance Criteria:**
- [ ] SwiftLint passes with no warnings
- [ ] All public APIs documented with doc comments
- [ ] Code follows existing patterns (AppState extensions, view structure)
- [ ] Accessibility IDs follow `{Component}_{Action}` convention
- [ ] No `@available` warnings for tvOS 26 APIs

---

### Phase 4: Build & Validation (1-2 hours)

#### Task 4.1: Cross-Platform Builds

**Build Commands:**

```bash
# Build tvOS (primary platform)
./build_install_launch.sh

# Build native macOS
./build_install_launch.sh macos

# Check for build warnings
xcodebuild -project Tiercade.xcodeproj \
  -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  build | grep warning
```

**Acceptance Criteria:**
- [ ] tvOS build succeeds with no errors
- [ ] macOS build succeeds with no errors
- [ ] No deprecation warnings
- [ ] No concurrency warnings (`Sendable` violations)
- [ ] DerivedData timestamp matches current build
- [ ] Both platforms launch successfully in simulator

---

#### Task 4.2: Acceptance Testing

**Automated Tests (Optional - Swift Testing):**

```swift
// File: TiercadeTests/AIGenerationTests.swift

import Testing
@testable import Tiercade

@Suite("AI Generation")
struct AIGenerationTests {

    @Test("AIGenerationRequest validates correctly")
    func testRequestValidation() {
        let valid = AIGenerationRequest(
            description: "Movies",
            itemCount: 25,
            timestamp: Date()
        )
        #expect(valid.isValid)

        let emptyDescription = AIGenerationRequest(
            description: "",
            itemCount: 25,
            timestamp: Date()
        )
        #expect(!emptyDescription.isValid)

        let countTooLow = AIGenerationRequest(
            description: "Movies",
            itemCount: 3,
            timestamp: Date()
        )
        #expect(!countTooLow.isValid)

        let countTooHigh = AIGenerationRequest(
            description: "Movies",
            itemCount: 150,
            timestamp: Date()
        )
        #expect(!countTooHigh.isValid)
    }

    @Test("Candidate defaults to selected")
    func testCandidateDefaultState() {
        let candidate = AIGeneratedItemCandidate(name: "Test Item")
        #expect(candidate.isSelected == true)
    }

    @Test("Candidate can be toggled")
    @MainActor
    func testCandidateToggle() async {
        let appState = AppState()
        let candidate = AIGeneratedItemCandidate(name: "Test Item")
        appState.aiGeneratedCandidates = [candidate]

        #expect(appState.aiGeneratedCandidates[0].isSelected == true)

        appState.toggleCandidateSelection(candidate)
        #expect(appState.aiGeneratedCandidates[0].isSelected == false)

        appState.toggleCandidateSelection(candidate)
        #expect(appState.aiGeneratedCandidates[0].isSelected == true)
    }
}
```

**Manual Acceptance Checklist:**

- [ ] **Generation:** Generate 50 items → all 50 appear in review list
- [ ] **Selection:** All items have checkmarks by default
- [ ] **Toggle:** Deselect 10 → counter shows "40 of 50 selected"
- [ ] **Import:** Click Import → 40 items added to draft
- [ ] **Deduplication:** Import again → shows "0 items imported (40 duplicates skipped)"
- [ ] **Regenerate:** Click Regenerate → returns to input form with same parameters
- [ ] **Search (iOS/macOS):** Type "Star" → filters results correctly
- [ ] **Edit Mode:** Enter edit mode → delete buttons appear
- [ ] **Delete:** Delete item → removed from candidates, counter updates
- [ ] **Cancel:** Click Cancel → overlay dismisses, no changes to draft
- [ ] **Error Handling:** Invalid description → Generate button disabled
- [ ] **Focus (tvOS):** Default focus on description field, Exit button dismisses
- [ ] **Platform Gate (tvOS):** Button shows message sheet instead of overlay

---

## File Structure

### New Files (4 total)

```
Tiercade/
├── State/
│   ├── Wizard/
│   │   └── AIGenerationModels.swift           [NEW] - Request & Candidate models
│   └── AppState+AIGeneration.swift            [NEW] - State management extension
└── Views/
    └── Overlays/
        └── AIItemGeneratorOverlay.swift        [NEW] - Main UI overlay

TiercadeTests/
└── AIGenerationTests.swift                     [NEW, Optional] - Swift Testing suite

docs/
└── AppleIntelligence/
    └── AI_ITEM_GENERATION_PLAN.md              [NEW] - This document
```

### Modified Files (2 total)

```
Tiercade/
└── Views/
    └── Overlays/
        └── TierListProjectWizardPages+Items.swift    [ADD] - Button & sheet

Tiercade/State/AppState.swift                         [OPTIONAL] - Add properties if not using extension
```

### File Responsibilities

| File | Responsibility | Size Est. |
|------|----------------|-----------|
| `AIGenerationModels.swift` | Data models (Request, Candidate) | ~50 lines |
| `AppState+AIGeneration.swift` | State management, import logic | ~150 lines |
| `AIItemGeneratorOverlay.swift` | UI overlay (3 stages) | ~400 lines |
| `AIGenerationTests.swift` | Unit tests | ~100 lines |
| Items page modifications | Integration point | +30 lines |

**Total New Code:** ~930 lines
**Refactored Code:** Minimal; reuse UniqueListCoordinator via wrapper

---

## Accessibility Reference

### Accessibility IDs

All interactive elements must have accessibility IDs for UI testing and VoiceOver support.

| Element | Accessibility ID | Purpose |
|---------|-----------------|---------|
| Items page button | `ItemsPage_GenerateAI` | Entry point to AI generator |
| Overlay root | `AIGenerator_Overlay` | Container for UI tests |
| Description field | `AIGenerator_Description` | Text input validation |
| Count field | `AIGenerator_Count` | Number input validation |
| Generate button | `AIGenerator_Generate` | Trigger generation action |
| Import button | `AIGenerator_Import` | Import selected items |
| Cancel button | Standard (from NavigationStack) | Dismissal action |

### VoiceOver Labels

**Input Form:**
- Description field: "What kind of items do you want to generate? For example, Best sci-fi movies of all time"
- Count stepper: "Number of items to generate, 5 to 100"
- Generate button: "Generate items with AI"

**Review List:**
- Item row: "\(item.name), \(item.isSelected ? 'selected' : 'not selected')"
- Selection counter: "\(selectedCount) of \(totalCount) items selected"
- Import button: "Import \(selectedCount) selected items"

**tvOS Message Sheet:**
- Message: "AI generation requires macOS or iOS. Please use the companion app."

---

## Testing Strategy

### Unit Tests (Swift Testing)

**Coverage Targets:**
- `AIGenerationRequest` validation logic
- `AIGeneratedItemCandidate` default state
- `AppState.toggleCandidateSelection(_:)`
- `AppState.removeCandidate(_:)`
- Deduplication logic in `importSelectedCandidates(into:)`

**Test File:** `TiercadeTests/AIGenerationTests.swift`

---

### Integration Tests (Manual)

**Cross-Platform Matrix:**

| Platform | Simulator | OS Version | Test Cases |
|----------|-----------|------------|------------|
| tvOS | Apple TV 4K (3rd gen) | tvOS 26 | Platform gate, message sheet |
| iOS | iPhone 16 Pro | iOS 26 | Full flow, multi-selection, search |
| macOS | Mac (My Mac) | macOS 26 | Full flow, keyboard input, Cmd-click |

**Test Scenarios:**
1. **Happy Path:** Generate 30 items → deselect 5 → import 25
2. **Deduplication:** Import 20 items → import again → verify 0 imported
3. **Regeneration:** Generate → regenerate → verify new list
4. **Error Handling:** Simulate failure → verify toast + form retained
5. **Edge Cases:** Empty description, count boundaries (5, 100)

---

### UI Tests (Optional - Future)

```swift
// Example UI test for Items page integration
func testAIGeneratorButton_opensOverlay() {
    let app = XCUIApplication()
    app.launch()

    // Navigate to tier list wizard
    app.buttons["Toolbar_NewTierList"].tap()

    // Navigate to Items page
    app.buttons["Items"].tap()

    // Tap AI generator button
    app.buttons["ItemsPage_GenerateAI"].tap()

    #if os(macOS) || os(iOS)
    // Verify overlay appears
    XCTAssertTrue(app.otherElements["AIGenerator_Overlay"].exists)

    // Verify description field is focused
    XCTAssertTrue(app.textFields["AIGenerator_Description"].hasFocus)
    #else
    // tvOS: Verify message sheet
    XCTAssertTrue(app.staticTexts["AI generation requires macOS or iOS"].exists)
    #endif
}
```

---

## Risk Assessment

### High Risk Items

#### Risk 1: UniqueListCoordinator Extraction Complexity

**Description:** Existing coordinator is tightly coupled to AI chat service. Extracting may break existing functionality.

**Impact:** High - Blocks entire feature
**Probability:** Medium

**Mitigation:**
1. Start with minimal refactor - copy coordinator code instead of moving
2. Test AI chat feature after extraction to ensure no regression
3. Create fallback branch before refactoring
4. Add unit tests for extracted generator

**Fallback:**
- Copy coordinator logic instead of refactoring
- Accept some code duplication short-term
- Refactor later as part of broader AI architecture cleanup

---

#### Risk 2: tvOS Focus Management Complexity

**Description:** Focus behavior with multi-section overlay (input form → list) may have edge cases or focus traps.

**Impact:** Medium - Feature works but UX is poor
**Probability:** Medium

**Mitigation:**
1. Use existing patterns from other overlays (MatchupArena, QuickMove)
2. Test early and often in tvOS 26 simulator
3. Use `.focusSection()` to isolate stages
4. Validate with VoiceOver enabled

**Fallback:**
- Simplify to single-focus section
- Remove search functionality on tvOS (already planned)
- Show "Use iOS/macOS for full experience" hint

---

### Medium Risk Items

#### Risk 3: Multi-Selection UX on tvOS

**Description:** EditMode + multi-selection may not work as expected on tvOS with remote input.

**Impact:** Low - Feature is macOS/iOS only, tvOS shows message
**Probability:** Low (tvOS doesn't use this feature)

**Mitigation:**
- N/A (feature disabled on tvOS)

---

#### Risk 4: Generation Performance / Timeout

**Description:** Generating 100 items may take too long or timeout.

**Impact:** Medium - Poor UX for large requests
**Probability:** Low (existing AI chat handles this)

**Mitigation:**
1. Show progress updates during generation
2. Set reasonable timeout (60s)
3. Allow cancellation (future enhancement)
4. Recommend 25-50 items in UI hint

**Fallback:**
- Reduce max count from 100 to 50
- Show "Generating large lists may take time" warning

---

### Low Risk Items

#### Risk 5: Platform-Specific UI Differences

**Description:** TextField, Stepper, List may behave differently across platforms.

**Impact:** Low - Cosmetic issues
**Probability:** Low (well-tested SwiftUI components)

**Mitigation:**
- Extensive use of `#if os()` checks
- Test all platforms in simulator
- Follow existing codebase patterns

---

## Design Decisions

### Decision 1: Number Input Pattern

**Question:** Stepper-only vs. TextField+Stepper hybrid?

**Options:**
- **A:** Stepper-only (simpler)
- **B:** TextField+Stepper hybrid (more flexible)
- **C:** Platform-specific (Stepper on tvOS, hybrid on iOS/macOS)

**Decision:** **Option C** - Platform-specific

**Rationale:**
- tvOS: Keyboard input is tedious (Apple HIG recommends avoiding)
- iOS/macOS: Users expect ability to type numbers directly
- Stepper provides good UX for small adjustments (5 → 10 → 15)
- TextField allows quick jumps (5 → 75)
- Hybrid gives best of both worlds on platforms with keyboards

**Implementation:**
```swift
#if os(tvOS)
HStack {
    Button("-") { itemCount = max(5, itemCount - 5) }.buttonStyle(.glass).focusable(interactions: .activate)
    Text("\(itemCount)").font(.title2.monospacedDigit())
    Button("+") { itemCount = min(100, itemCount + 5) }.buttonStyle(.glass).focusable(interactions: .activate)
}
#else
HStack {
    TextField("Count", value: $itemCount, format: .number)
        .keyboardType(.numberPad)
        .frame(width: 80)
    Stepper("", value: $itemCount, in: 5...100, step: 5)
        .labelsHidden()
}
#endif
```

---

### Decision 2: Deduplication Strategy

**Question:** Always dedupe, allow duplicates, or make it configurable?

**Options:**
- **A:** Always deduplicate (automatic)
- **B:** Allow duplicates (no checking)
- **C:** Make it configurable (toggle in UI)

**Decision:** **Option A** - Always deduplicate

**Rationale:**
- User pain: Importing "Best movies" twice would create duplicate items
- Cleanup burden: Manually finding/deleting duplicates is tedious
- Expected behavior: Most users expect system to prevent duplicates
- Low complexity: Simple Set-based deduplication is cheap
- Good feedback: Toast shows "X imported (Y duplicates skipped)"

**Implementation:**
```swift
let existingTitles = Set(draft.items.map { $0.title.lowercased() })
let uniqueCandidates = selected.filter {
    !existingTitles.contains($0.name.lowercased())
}
```

**Future Enhancement:** Add toggle if users request duplicate support

---

### Decision 3: tvOS Feature Availability

**Question:** How should tvOS users access AI generation?

**Options:**
- **A:** Show informative message ("Requires macOS/iOS")
- **B:** Hide/disable button entirely
- **C:** Offer alternative (QR code to companion app)

**Decision:** **Option A** - Show informative message

**Rationale:**
- Discoverability: Button visible, users understand limitation
- Consistent UX: Same button placement across platforms
- Simple implementation: Sheet with message + OK button
- Future-proof: If Apple adds on-device AI to tvOS, easy to enable
- No companion app yet: Option C requires additional infrastructure

**Implementation:**
```swift
.sheet(isPresented: $showAIGenerator) {
    #if os(macOS) || os(iOS)
    AIItemGeneratorOverlay(...)
    #else
    VStack {
        Image(systemName: "exclamationmark.triangle")
        Text("AI Generation Requires macOS or iOS")
        Button("OK") { showAIGenerator = false }
    }
    #endif
}
```

---

### Decision 4: Search Feature Scope

**Question:** Include search on all platforms or iOS/macOS only?

**Options:**
- **A:** All platforms (including tvOS)
- **B:** iOS/macOS only
- **C:** No search (keep it simple)

**Decision:** **Option B** - iOS/macOS only

**Rationale:**
- tvOS complexity: Search bar adds focus management overhead
- tvOS input: Typing search query on remote is tedious
- List size: 100 items max is scrollable without search on tvOS
- iOS/macOS benefit: Keyboard makes search valuable
- Simplifies implementation: No tvOS-specific search UX needed

**Implementation:**
```swift
#if !os(tvOS)
 .searchable(text: $searchText, placement: .automatic)
    .padding()
#endif

// Filter logic works on all platforms:
private var filteredCandidates: [AIGeneratedItemCandidate] {
    if searchText.isEmpty {
        return appState.aiGeneratedCandidates
    } else {
        return appState.aiGeneratedCandidates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}
```

---

### Decision 5: Integration Location

**Question:** Where to add AI generation entry point?

**Options:**
- **A:** Items page (within wizard)
- **B:** New wizard page (AI Generation step)
- **C:** Toolbar shortcut (global)

**Decision:** **Option A** - Items page

**Rationale:**
- Context: Users on Items page need items
- Optional: Doesn't force AI usage on all users
- Flow: Fits naturally in existing wizard progression
- Discoverability: Prominent button on relevant page
- Simplicity: No new navigation or wizard restructuring

**Placement:** Toolbar or above item list (TBD based on visual design)

---

## Timeline & Milestones

### Phase 1: Core Infrastructure (4-6 hours)
- **Milestone 1.1:** Wrapper wired to UniqueListCoordinator and tested
- **Milestone 1.2:** Data models defined and validated
- **Milestone 1.3:** AppState extension complete with all methods

### Phase 2: UI Implementation (6-8 hours)
- **Milestone 2.1:** AIItemGeneratorOverlay with 3 stages functional
- **Milestone 2.2:** Multi-selection list working on iOS/macOS
- **Milestone 2.3:** Items page integration complete

### Phase 3: Polish & Testing (3-4 hours)
- **Milestone 3.1:** tvOS focus management validated
- **Milestone 3.2:** Error handling complete
- **Milestone 3.3:** Cross-platform manual testing passed
- **Milestone 3.4:** SwiftLint clean, documentation complete

### Phase 4: Build & Validation (1-2 hours)
- **Milestone 4.1:** Both platforms build successfully
- **Milestone 4.2:** Acceptance tests passed

**Total Estimated Effort:** 14-20 hours (2-3 full work days)

---

## Future Enhancements (Out of Scope)

### Post-MVP Features

1. **Cancellation Support**
   - Add "Cancel" button during generation
   - Implement async task cancellation
   - Clean up partial results

2. **Batch Editing**
   - Select multiple items for bulk actions
   - Bulk delete, bulk tag assignment
   - Export selected to separate list

3. **Smart Suggestions**
   - "Did you mean...?" for typos
   - Related list suggestions
   - Popular templates (genres, eras, etc.)

4. **Generation History**
   - Save recent generation requests
   - Quick regenerate from history
   - Compare different generation attempts

5. **Advanced Options**
   - Temperature/creativity slider
   - Domain-specific prompts (movies, games, books)
   - Custom system instructions

6. **Item Enrichment**
   - Auto-fetch images for generated items
   - Add metadata (release year, genre, etc.)
   - Suggest tier placements

---

## Appendix A: Code Snippets

### Complete AIItemGeneratorOverlay Structure

```swift
import SwiftUI
import TiercadeCore

struct AIItemGeneratorOverlay: View {
    @Bindable var appState: AppState
    let draft: TierProjectDraft

    @State private var itemDescription: String = ""
    @State private var itemCount: Int = 25
    @State private var searchText: String = ""
    @Environment(\.editMode) private var editMode
    @FocusState private var focusedField: Field?
    @Namespace private var focusNamespace

    enum Field: Hashable {
        case description
        case count
    }

    private enum Stage {
        case input
        case generating
        case review
    }

    private var stage: Stage {
        if appState.aiGenerationInProgress {
            return .generating
        } else if !appState.aiGeneratedCandidates.isEmpty {
            return .review
        } else {
            return .input
        }
    }

    private var selectedCount: Int {
        appState.aiGeneratedCandidates.filter(\.isSelected).count
    }

    private var filteredCandidates: [AIGeneratedItemCandidate] {
        if searchText.isEmpty {
            return appState.aiGeneratedCandidates
        } else {
            return appState.aiGeneratedCandidates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.dismissAIItemGenerator()
                    }
                }

                if stage == .review {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
        .accessibilityIdentifier("AIGenerator_Overlay")
        #if os(tvOS)
        .onExitCommand {
            appState.dismissAIItemGenerator()
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
                    .prefersDefaultFocus(true, in: focusNamespace)
                    #if os(iOS) || os(macOS)
                    .textInputAutocapitalization(.sentences)
                    #endif
                    .accessibilityIdentifier("AIGenerator_Description")
            } header: {
                Text("What kind of items?")
            }

            Section {
                #if os(tvOS)
                // tvOS: Action-only +/- controls
                HStack {
                    Button("-") { itemCount = max(5, itemCount - 5) }
                        .buttonStyle(.glass)
                        .focusable(interactions: .activate)
                        .focused($focusedField, equals: .count)
                    Text("\(itemCount)")
                        .font(.title2.monospacedDigit())
                        .frame(minWidth: 72)
                    Button("+") { itemCount = min(100, itemCount + 5) }
                        .buttonStyle(.glass)
                        .focusable(interactions: .activate)
                }
                #else
                // iOS/macOS: Hybrid
                HStack {
                    TextField("Count", value: $itemCount, format: .number)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("AIGenerator_Count")
                        .frame(width: 80)

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
        .focusScope(focusNamespace)
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

            if let progress = appState.currentProgress {
                VStack(spacing: 8) {
                    Text(progress.message)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if let percentage = progress.percentage {
                        ProgressView(value: percentage)
                            .frame(width: 200)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review List

    @ViewBuilder
    private var reviewList: some View {
        VStack(spacing: 0) {
            #if !os(tvOS)
             .searchable(text: $searchText, placement: .automatic)
                .padding()
            #endif

            Text("\(selectedCount) of \(appState.aiGeneratedCandidates.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            List(selection: editMode?.wrappedValue.isEditing == true ? nil : Binding<Set<UUID>>(
                get: { Set(appState.aiGeneratedCandidates.filter(\.isSelected).map(\.id)) },
                set: { newSelection in
                    for candidate in appState.aiGeneratedCandidates {
                        let shouldBeSelected = newSelection.contains(candidate.id)
                        if candidate.isSelected != shouldBeSelected {
                            appState.toggleCandidateSelection(candidate)
                        }
                    }
                }
            )) {
                ForEach(filteredCandidates) { candidate in
                    HStack {
                        if editMode?.wrappedValue.isEditing == false || editMode == nil {
                            Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(candidate.isSelected ? .green : .secondary)
                        }

                        Text(candidate.name)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if editMode?.wrappedValue.isEditing == false || editMode == nil {
                            appState.toggleCandidateSelection(candidate)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        appState.removeCandidate(filteredCandidates[index])
                    }
                }
            }

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

#if !os(tvOS)
private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search items", text: $text)
                .textFieldStyle(.roundedBorder)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
#endif
```

---

## Appendix B: Related Documentation

### Internal Documentation

- `docs/AppleIntelligence/DEEP_RESEARCH_2025-10.md` - AI research plan and experiment matrix
- `CLAUDE.md` - Agent playbook and prototype scope
- `docs/AppleIntelligence/` - AI research and telemetry notes

### Apple Documentation

- [SwiftUI TextField](https://developer.apple.com/documentation/swiftui/textfield/)
- [SwiftUI List](https://developer.apple.com/documentation/swiftui/list/)
- [EditMode](https://developer.apple.com/documentation/swiftui/editmode/)
- [FocusState](https://developer.apple.com/documentation/swiftui/focusstate/)
- [tvOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos)
- [Stepper (HIG)](https://developer.apple.com/design/human-interface-guidelines/components/selection-and-input/steppers/)

### External References

- [Nielsen Norman: Input Steppers](https://www.nngroup.com/articles/input-steppers/)
- Apple WWDC Sessions on tvOS focus management

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-31 | Claude (Sonnet 4.5) | Initial comprehensive plan |
| 1.1 | 2025-10-31 | Codex | Corrections for tvOS input, Apple docs alignment, feature flags |

---


---

## Addendum (Codex Review)

### Corrections and Alignments

- tvOS number input: Stepper is not available on tvOS. Replace any tvOS Stepper examples with a glass-styled ± button pair and a monospaced count label inside a `.focusSection()`. Keep buttons `.focusable(interactions: .activate)`.
- Search on iOS/macOS: prefer `View.searchable(text:)` instead of a custom SearchBar view.
- Reuse existing AppleIntelligence UniqueListCoordinator: avoid creating a new generator type; add a thin wrapper that instantiates `FMClient` with the existing `session` and calls `uniqueList(query:targetCount:)` under `#if canImport(FoundationModels)`.
- RetryState invariants: ensure no local variables shadow `RetryState` fields; let coordinator own per-attempt resets and telemetry.
- Feature flags and gating: add SPM trait `ai-generation` (DEBUG default ON) and gate Apple Intelligence behind `#if canImport(FoundationModels)` on macOS/iOS only; keep tvOS UI independent.
- Accessibility: on iOS/macOS overlays, use `AccessibilityBridgeView` to ensure immediate accessibility-tree presence; assign leaf-level accessibility identifiers only.
- Glass effects: apply Liquid Glass to chrome (headers/buttons) only. Use solid backgrounds behind text fields to preserve tvOS focus overlays.

### Reference Snippets

tvOS count input (replace Stepper):

```swift
HStack(spacing: Metrics.padding) {
    Button("-") { itemCount = max(5, itemCount - 5) }
        .buttonStyle(.glass)
        .focusable(interactions: .activate)
    Text("\(itemCount)")
        .font(.title2.monospacedDigit())
        .frame(minWidth: 72)
    Button("+") { itemCount = min(100, itemCount + 5) }
        .buttonStyle(.glass)
        .focusable(interactions: .activate)
}
.focusSection()
```

iOS/macOS searchable:

```swift
.searchable(text: $searchText, placement: .automatic)
```

Wizard generation wrapper:

```swift
#if canImport(FoundationModels)
if #available(iOS 26.0, macOS 26.0, *) {
    guard let session else { throw NSError(domain: "AI", code: -1) }
    let fm = FMClient(session: session, logger: { _ in })
    let coordinator = UniqueListCoordinator(fm: fm, logger: { _ in }, useGuidedBackfill: true)
    let items = try await coordinator.uniqueList(query: topic, targetCount: count, seed: nil)
}
#endif
```

### Apple Documentation

- TextField(value:format:) — https://developer.apple.com/documentation/swiftui/textfield/
- IntegerFormatStyle — https://developer.apple.com/documentation/foundation/integerformatstyle/
- focusSection() — https://developer.apple.com/documentation/swiftui/view/focussection()/
- focusable(interactions:) — https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)/
- onExitCommand(perform:) — https://developer.apple.com/documentation/swiftui/view/onexitcommand(perform:)/
- glassEffect(_:in:) — https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)/
- Stepper — https://developer.apple.com/documentation/swiftui/stepper/

**End of Plan Document**
