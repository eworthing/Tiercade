# AppState Decomposition & Architecture Refactor Plan

**Created:** 2025-11-02
**Status:** Planning
**Target:** Swift 6 + SwiftUI Observation best practices
**Platforms:** tvOS 26+ (primary), iOS 26+, macOS 26+ (native)

---

## Executive Summary

Refactor `AppState` from a 1,000+ line monolith into smaller, purpose-built observable types following Apple's Observation macro guidance and Swift 6 strict concurrency patterns.

**Current Problem:**
- Single `@Observable` class mixing UI state, persistence, AI, overlays, and domain logic
- 17 H2H properties (now consolidated), but similar sprawl exists for themes, persistence, overlays
- Hard to test, hard to reason about, poor separation of concerns
- Violates SwiftUI Observation best practices for granular state tracking

**Solution:**
- Decompose into 6 feature aggregates with clear boundaries
- Introduce service protocols + dependency injection for testability
- Maintain tvOS-first UX and existing view → AppState → Core logic pipeline
- Execute in 5 phased PRs to minimize risk and enable incremental validation

**Success Metrics:**
- ✅ All platforms build (tvOS, iOS, macOS) after each PR
- ✅ No regressions in focus behaviors or accessibility IDs
- ✅ All tests pass (security suite + TiercadeCore)
- ✅ Smaller, testable state objects with protocol-based dependencies

---

## What's Already Done (Foundation Work)

Recent commits have laid the groundwork:

| Commit | Change | Impact |
|--------|--------|--------|
| `c6aa1d1` | **HeadToHeadState aggregation** | 17 `h2h*` properties → single struct |
| `43fa7e8` | **Centralized focus gating** | `blocksBackgroundFocus` computed property |
| `10af3f9` | **Design tokens** | 50+ magic numbers → semantic constants |
| `c8f0b3f` | **Security test suite** | 52 tests for URL/path/CSV/prompt validation |
| `9586ece` | **AI prompt sanitization** | `PromptValidator.sanitize()` |
| `c070835` | **JSON size limits** | 50MB cap prevents DoS |
| `366d4c7` | **Codex review fixes** | AsyncImage, CSV counter, NSCache, etc. |
| `716cb67` | **Export path validation** | Prevents directory traversal on writes |
| `25f6c56` | **Docs corrections** | `glassEffect` vs `glassBackgroundEffect` |
| `03a4efe` | **Test refactoring** | Exposed CSV functions, Logger migration |

**Net Result:** Security hardened, H2H state consolidated, design tokens extracted. Ready for architectural decomposition.

---

## Why Refactor AppState

### Apple Guidance

1. **SwiftUI Observation Best Practices**
   - Prefer smaller, purpose-built `@Observable` types over monolithic state
   - Improves SwiftUI's dependency tracking and reduces unnecessary view updates
   - Reference: [Migrating to Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/)

2. **Swift 6 Strict Concurrency**
   - Smaller actors/observables with well-defined isolation boundaries
   - Reduces race conditions and improves compile-time diagnostics
   - Reference: [Adopting Swift 6](https://developer.apple.com/documentation/swift/adoptingswift6/)

### Technical Debt

Current `AppState.swift` (~400 lines) + extensions (~2,000+ lines total):
- **Mixing concerns**: UI state + persistence + AI + overlays + domain logic
- **Hard to test**: Can't mock persistence without full AppState
- **Poor encapsulation**: 100+ public properties accessible to all views
- **Unclear dependencies**: Which views need which state?
- **Difficult navigation**: Finding relevant code requires grepping multiple extensions

---

## Target Architecture

### Before (Current)
```
AppState (@Observable, @MainActor)
├── Tier state (items, order, labels, colors)
├── Persistence (save/load, recents, autosave)
├── Theme state (selected, library, creator)
├── Overlay toggles (detail, H2H, themes, quick move)
├── HeadToHeadState (✅ already extracted)
├── AI Generation (session, messages, status)
├── Progress/Toast UI state
├── Selection/multi-select
├── Undo/Redo
└── 50+ methods across 10+ extensions
```

### After (Target)
```
AppState (@Observable, @MainActor) - THIN COORDINATOR
├── tierList: TierListState
├── persistence: PersistenceState
├── theme: ThemeState
├── overlays: OverlaysState
├── headToHead: HeadToHeadState (✅ exists)
├── aiGeneration: AIGenerationState
├── progress: ProgressState
└── Dependency services (injected):
    ├── persistenceStore: TierPersistenceStore
    ├── listGenerator: UniqueListGenerating
    └── themeCatalog: ThemeCatalogProviding
```

---

## Proposed State Decomposition

### 1. TierListState
**Responsibility:** Core tier list data and operations

**Properties:**
- `tiers: Items` (the actual tier data)
- `tierOrder: [String]`
- `tierLabels: [String: String]`
- `tierColors: [String: String]`
- `lockedTiers: Set<String>`
- `selection: Set<String>`
- `history: [TierStateSnapshot]`
- `historyIndex: Int`

**Methods (call TiercadeCore):**
- `moveItem(_:to:)` → wraps `TierLogic.moveItem`
- `deleteItems(_:)` → wraps `TierLogic.removeItems`
- `shuffleUnranked()` → wraps `RandomUtils.shuffle`
- Undo/redo operations

**Why separate:** Clear boundary for tier manipulation; easy to test without persistence/UI concerns.

---

### 2. PersistenceState
**Responsibility:** Save/load operations and file management

**Properties:**
- `hasUnsavedChanges: Bool`
- `lastSavedTime: Date?`
- `currentFileName: String?`
- `activeTierList: TierListHandle?`
- `recentTierLists: [TierListHandle]`
- `autosaveTask: Task<Void, Never>?`

**Methods:**
- `save()` → uses injected `persistenceStore`
- `load(from:)` → uses injected `persistenceStore`
- `autoSave()` → throttled persistence
- `updateRecents(_:)`

**Dependencies:**
- Protocol: `TierPersistenceStore` (injected)
- Implementation: `SwiftDataPersistenceStore` or `UserDefaultsPersistenceStore`

**Why separate:** Persistence is independent of tier operations; can swap storage backends for testing.

---

### 3. ThemeState
**Responsibility:** Theme selection and management

**Properties:**
- `selectedTheme: TierTheme`
- `availableThemes: [TierTheme]`
- `showThemePicker: Bool`
- `showThemeCreator: Bool`
- `customThemes: [TierTheme]`

**Methods:**
- `applyTheme(_:)`
- `createCustomTheme(_:)`
- `deleteCustomTheme(_:)`
- `resetToThemeColors()`

**Dependencies:**
- Protocol: `ThemeCatalogProviding`
- Implementation: `BundledThemeCatalog` or `DynamicThemeCatalog`

**Why separate:** Themes are orthogonal to tier data; theme picker overlay only needs this state.

---

### 4. OverlaysState
**Responsibility:** Modal/overlay routing and visibility

**Properties:**
- `detailItem: Item?`
- `quickMoveTarget: Item?`
- `showAnalyticsSidebar: Bool`
- `showTierListCreator: Bool`
- `showTierListBrowser: Bool`
- `tierListCreatorExportPayload: String?`

**Computed:**
- `activeOverlay: OverlayType?` (enum: .detail, .quickMove, .h2h, .themes, etc.)
- `blocksBackgroundFocus: Bool` (aggregate of all overlays)

**Methods:**
- `showDetail(_:)`
- `dismissDetail()`
- `showQuickMove(_:)`
- `dismissAllOverlays()`

**Why separate:** Overlay state is pure UI routing; consolidates scattered `show*` booleans.

---

### 5. HeadToHeadState ✅
**Already exists** (commit `c6aa1d1`)

**Responsibility:** Head-to-Head ranking session state

**Properties:**
- `isActive: Bool`
- `pool: [Item]`
- `currentPair: (Item, Item)?`
- `records: [String: H2HRecord]`
- Progress tracking (quick + refinement phases)
- Artifacts and suggested pairs

**Methods:** (in `AppState+HeadToHead.swift`)
- `startH2H()`
- `voteH2H(winner:)`
- `skipCurrentH2HPair()`
- `finishH2H()`

**Why separate:** Already done; serves as template for other extractions.

---

### 6. AIGenerationState
**Responsibility:** Apple Intelligence chat and generation

**Properties:**
- `showAIChat: Bool`
- `messages: [AIChatMessage]`
- `session: LanguageModelSession?`
- `aiGenerationInProgress: Bool`
- `aiGenerationRequest: AIGenerationRequest?`
- `aiGeneratedCandidates: [AIGeneratedItemCandidate]`
- `estimatedTokenCount: Int`

**Methods:**
- `sendMessage(_:)`
- `ensureSession()` → uses injected `listGenerator`
- `resetSession()`
- `dismissAIChat()`

**Dependencies:**
- Protocol: `UniqueListGenerating`
- Implementation: `AppleIntelligenceListGenerator` (FoundationModels) or `MockListGenerator`

**Why separate:** AI is platform-gated (macOS/iOS only); isolating makes testing easier and keeps tvOS code clean.

---

### 7. ProgressState (Optional)
**Responsibility:** Loading indicators and toasts

**Properties:**
- `isLoading: Bool`
- `loadingMessage: String`
- `operationProgress: Double`
- `currentToast: ToastMessage?`

**Methods:**
- `showToast(_:)`
- `dismissToast()`
- `withLoadingIndicator(_:)`

**Why separate:** Pure UI feedback; could stay in AppState if preferred (low priority).

---

## Service Protocols (Dependency Injection)

### 1. TierPersistenceStore
```swift
protocol TierPersistenceStore: Sendable {
    func save(_ snapshot: TierStateSnapshot, fileName: String) async throws
    func load(fileName: String) async throws -> TierStateSnapshot
    func listRecent() async throws -> [TierListHandle]
}

// Production implementation
actor SwiftDataPersistenceStore: TierPersistenceStore {
    private let modelContext: ModelContext
    // ... implementation
}

// Test implementation
actor MockPersistenceStore: TierPersistenceStore {
    var savedSnapshots: [String: TierStateSnapshot] = [:]
    // ... implementation
}
```

---

### 2. UniqueListGenerating
```swift
protocol UniqueListGenerating: Sendable {
    func generateUniqueList(topic: String, count: Int) async throws -> [AIGeneratedItemCandidate]
}

// Production implementation (macOS/iOS only)
#if canImport(FoundationModels)
actor AppleIntelligenceListGenerator: UniqueListGenerating {
    // Wraps FoundationModels APIs
}
#endif

// Test implementation
actor MockListGenerator: UniqueListGenerating {
    var stubbedResults: [AIGeneratedItemCandidate] = []
    // ... implementation
}
```

---

### 3. ThemeCatalogProviding
```swift
protocol ThemeCatalogProviding: Sendable {
    func allThemes() async -> [TierTheme]
    func saveCustomTheme(_ theme: TierTheme) async throws
    func deleteCustomTheme(id: String) async throws
}

// Production implementation
actor BundledThemeCatalog: ThemeCatalogProviding {
    // Reads from TierThemeSchema.bundledThemes
}
```

---

## Execution Plan (5 Phased PRs)

### PR 1: Introduce Protocols + DI (Low Risk)
**Goal:** Set up dependency injection without changing behavior

**Changes:**
1. Create `Tiercade/Services/Protocols/`
   - `TierPersistenceStore.swift`
   - `UniqueListGenerating.swift`
   - `ThemeCatalogProviding.swift`

2. Create `Tiercade/Services/Implementations/`
   - `SwiftDataPersistenceStore.swift`
   - `AppleIntelligenceListGenerator.swift` (#if canImport)
   - `BundledThemeCatalog.swift`

3. Update `AppState.init`:
   ```swift
   internal init(
       modelContext: ModelContext,
       persistenceStore: TierPersistenceStore? = nil,
       listGenerator: UniqueListGenerating? = nil,
       themeCatalog: ThemeCatalogProviding? = nil
   ) {
       self.modelContext = modelContext
       self.persistenceStore = persistenceStore ?? SwiftDataPersistenceStore(context: modelContext)
       self.listGenerator = listGenerator ?? AppleIntelligenceListGenerator()
       self.themeCatalog = themeCatalog ?? BundledThemeCatalog()
       // ... existing init
   }
   ```

4. No view changes yet; all calls remain through AppState methods

**Validation:**
- ✅ All platforms build (tvOS, iOS, macOS)
- ✅ All tests pass
- ✅ No behavior changes (pure refactor)

**Estimated Time:** 2-3 hours

---

### PR 2: Extract AIGenerationState (Moderate Risk)
**Goal:** Move AI chat into separate state object

**Changes:**
1. Create `Tiercade/State/AIGenerationState.swift`:
   ```swift
   @Observable @MainActor
   internal final class AIGenerationState {
       var showAIChat: Bool = false
       var messages: [AIChatMessage] = []
       var session: LanguageModelSession?
       var aiGenerationInProgress: Bool = false
       // ... all AI-related properties

       private let listGenerator: UniqueListGenerating

       init(listGenerator: UniqueListGenerating) {
           self.listGenerator = listGenerator
       }

       func sendMessage(_ text: String) async { /* ... */ }
       func ensureSession() async -> Bool { /* ... */ }
       // ... methods from AppState+AppleIntelligence
   }
   ```

2. Update `AppState`:
   ```swift
   @Observable @MainActor
   internal final class AppState {
       var aiGeneration: AIGenerationState

       init(modelContext: ModelContext, ...) {
           self.aiGeneration = AIGenerationState(listGenerator: listGenerator)
           // ...
       }
   }
   ```

3. Update `AIChatOverlay`:
   ```swift
   struct AIChatOverlay: View {
       @Bindable var ai: AIGenerationState  // Instead of full AppState

       var body: some View {
           // Use ai.messages, ai.sendMessage(), etc.
       }
   }
   ```

4. Update call sites:
   - `showAIChat` → `aiGeneration.showAIChat`
   - `sendMessage(_:)` → `aiGeneration.sendMessage(_:)`

**Validation:**
- ✅ All platforms build
- ✅ AI chat overlay works (macOS/iOS only)
- ✅ tvOS shows platform notice (unchanged)
- ✅ Tests pass

**Estimated Time:** 3-4 hours

---

### PR 3: Extract PersistenceState + OverlaysState (Moderate Risk)
**Goal:** Separate persistence and overlay routing

**Changes:**
1. Create `Tiercade/State/PersistenceState.swift`:
   ```swift
   @Observable @MainActor
   internal final class PersistenceState {
       var hasUnsavedChanges: Bool = false
       var lastSavedTime: Date?
       var currentFileName: String?
       var activeTierList: TierListHandle?
       var recentTierLists: [TierListHandle] = []

       private let store: TierPersistenceStore

       func save(_ snapshot: TierStateSnapshot) async throws {
           try await store.save(snapshot, fileName: currentFileName ?? "default")
           hasUnsavedChanges = false
           lastSavedTime = Date()
       }
       // ... other persistence methods
   }
   ```

2. Create `Tiercade/State/OverlaysState.swift`:
   ```swift
   @Observable @MainActor
   internal final class OverlaysState {
       var detailItem: Item?
       var quickMoveTarget: Item?
       var showAnalyticsSidebar: Bool = false
       var showTierListCreator: Bool = false
       var showTierListBrowser: Bool = false

       var activeOverlay: OverlayType? {
           if detailItem != nil { return .detail }
           if quickMoveTarget != nil { return .quickMove }
           // ... etc
           return nil
       }

       var blocksBackgroundFocus: Bool {
           activeOverlay != nil || /* check other conditions */
       }

       func dismissAllOverlays() {
           detailItem = nil
           quickMoveTarget = nil
           // ... reset all
       }
   }
   ```

3. Update `AppState`:
   ```swift
   @Observable @MainActor
   internal final class AppState {
       var persistence: PersistenceState
       var overlays: OverlaysState

       var blocksBackgroundFocus: Bool {
           overlays.blocksBackgroundFocus || headToHead.isActive || /* theme/AI overlays */
       }
   }
   ```

4. Update views:
   - `detailItem` → `overlays.detailItem`
   - `quickMoveTarget` → `overlays.quickMoveTarget`
   - `hasUnsavedChanges` → `persistence.hasUnsavedChanges`

**Validation:**
- ✅ All platforms build
- ✅ Overlay navigation works (detail, quick move, etc.)
- ✅ Save/load/autosave works
- ✅ Tests pass

**Estimated Time:** 4-5 hours

---

### PR 4: Extract TierListState (Moderate-High Risk)
**Goal:** Separate tier data and operations from AppState

**Changes:**
1. Create `Tiercade/State/TierListState.swift`:
   ```swift
   @Observable @MainActor
   internal final class TierListState {
       var tiers: Items = ["S":[],"A":[],"B":[],"C":[],"D":[],"F":[],"unranked":[]]
       var tierOrder: [String] = ["S","A","B","C","D","F"]
       var tierLabels: [String: String] = [:]
       var tierColors: [String: String] = [:]
       var lockedTiers: Set<String> = []
       var selection: Set<String> = []

       private var history: [TierStateSnapshot] = []
       private var historyIndex: Int = 0

       func moveItem(_ id: String, to tier: String) {
           let snapshot = captureSnapshot()
           tiers = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
           recordHistory(snapshot)
       }

       func deleteItems(_ ids: Set<String>) {
           let snapshot = captureSnapshot()
           tiers = TierLogic.removeItems(tiers, itemIds: ids)
           recordHistory(snapshot)
       }

       func undo() {
           guard canUndo else { return }
           historyIndex -= 1
           restoreSnapshot(history[historyIndex])
       }

       // ... other tier operations
   }
   ```

2. Update `AppState`:
   ```swift
   @Observable @MainActor
   internal final class AppState {
       var tierList: TierListState

       // Convenience accessors (can deprecate gradually)
       var tiers: Items { tierList.tiers }
       var tierOrder: [String] { tierList.tierOrder }
       // ...
   }
   ```

3. Update views gradually:
   - Option A: Keep `app.tiers` working via passthrough properties
   - Option B: Update all views to `app.tierList.tiers` (more churn but cleaner)

**Validation:**
- ✅ All platforms build
- ✅ Tier operations work (move, delete, undo/redo)
- ✅ H2H integration intact (uses tierList.tiers)
- ✅ Tests pass

**Estimated Time:** 5-6 hours

---

### PR 5: Extract ThemeState + Cleanup (Optional)
**Goal:** Complete decomposition and remove debug telemetry

**Changes:**
1. Create `Tiercade/State/ThemeState.swift`:
   ```swift
   @Observable @MainActor
   internal final class ThemeState {
       var selectedTheme: TierTheme
       var availableThemes: [TierTheme]
       var showThemePicker: Bool = false
       var showThemeCreator: Bool = false

       private let catalog: ThemeCatalogProviding

       func applyTheme(_ theme: TierTheme) {
           selectedTheme = theme
           // Update tier colors/labels
       }

       // ... other theme methods
   }
   ```

2. Move debug/telemetry to middleware:
   - `appendDebugFile(_:)` → `DebugLogger` service
   - Acceptance test boot logging → opt-in middleware
   - Keep behind `#if DEBUG` flags

3. Update `AppState`:
   ```swift
   @Observable @MainActor
   internal final class AppState {
       var tierList: TierListState
       var persistence: PersistenceState
       var theme: ThemeState
       var overlays: OverlaysState
       var headToHead: HeadToHeadState
       var aiGeneration: AIGenerationState

       // Minimal coordination methods only
       func startNewTierList() { /* ... */ }
       func importProject(_:) async throws { /* ... */ }
   }
   ```

**Validation:**
- ✅ All platforms build
- ✅ Theme picker/creator work
- ✅ Debug logging still available in DEBUG builds
- ✅ Tests pass

**Estimated Time:** 3-4 hours

---

## File Structure (After Refactor)

```
Tiercade/
├── State/
│   ├── AppState.swift                    (THIN - ~200 lines)
│   ├── TierListState.swift              (NEW)
│   ├── PersistenceState.swift           (NEW)
│   ├── ThemeState.swift                 (NEW)
│   ├── OverlaysState.swift              (NEW)
│   ├── HeadToHeadState.swift            (✅ EXISTS)
│   ├── AIGenerationState.swift          (NEW)
│   ├── ProgressState.swift              (OPTIONAL)
│   ├── AppStateErrors.swift             (EXISTS)
│   └── Extensions/
│       ├── AppState+Coordination.swift  (Cross-feature flows)
│       ├── TierListState+Operations.swift
│       └── AIGenerationState+Advanced.swift
│
├── Services/
│   ├── Protocols/
│   │   ├── TierPersistenceStore.swift
│   │   ├── UniqueListGenerating.swift
│   │   └── ThemeCatalogProviding.swift
│   └── Implementations/
│       ├── SwiftDataPersistenceStore.swift
│       ├── AppleIntelligenceListGenerator.swift
│       └── BundledThemeCatalog.swift
│
├── Views/
│   ├── Main/
│   │   ├── MainAppView.swift            (binds to app.tierList, app.overlays, etc.)
│   │   └── ContentView+TierGrid.swift
│   ├── Overlays/
│   │   ├── AIChatOverlay.swift          (binds to AIGenerationState)
│   │   ├── ThemeLibraryOverlay.swift    (binds to ThemeState)
│   │   └── MatchupArenaOverlay.swift    (binds to HeadToHeadState)
│   └── ...
```

---

## Testing Strategy

### Unit Tests (New)
```swift
// TiercadeTests/StateTests/TierListStateTests.swift
@Test("Moving item updates tiers and records history")
func testMoveItemRecordsHistory() {
    let state = TierListState()
    state.tiers["unranked"] = [Item(id: "test", name: "Test")]

    state.moveItem("test", to: "S")

    #expect(state.tiers["S"]?.contains(where: { $0.id == "test" }) == true)
    #expect(state.canUndo == true)
}

// TiercadeTests/StateTests/PersistenceStateTests.swift
@Test("Save updates timestamp and clears unsaved flag")
func testSaveUpdatesState() async throws {
    let mockStore = MockPersistenceStore()
    let state = PersistenceState(store: mockStore)
    state.hasUnsavedChanges = true

    try await state.save(TierStateSnapshot(...))

    #expect(state.hasUnsavedChanges == false)
    #expect(state.lastSavedTime != nil)
}
```

### Integration Tests (Update Existing)
```swift
// Update existing tests to use dependency injection
@Test("Import project with mock persistence")
func testImportWithMock() async throws {
    let mockStore = MockPersistenceStore()
    let appState = AppState(
        modelContext: testContext,
        persistenceStore: mockStore
    )

    try await appState.importProject(from: testData)

    #expect(mockStore.savedSnapshots.count == 1)
}
```

---

## Migration Checklist (Per PR)

### Before Starting Any PR
- [ ] Create feature branch from `tiertesting`
- [ ] Run all tests: `cd TiercadeCore && swift test`
- [ ] Verify clean build: `./build_install_launch.sh`

### During Implementation
- [ ] Follow Swift 6 strict concurrency (`@MainActor`, `Sendable`)
- [ ] Keep all properties `internal` (not `public` or `private` across files)
- [ ] Update accessibility IDs if view structure changes
- [ ] Add doc comments to new public APIs
- [ ] Write unit tests for new state objects

### Before Committing
- [ ] Build all platforms: `./build_install_launch.sh`
- [ ] Run TiercadeCore tests: `cd TiercadeCore && swift test`
- [ ] SwiftLint passes (or file is split if too complex)
- [ ] Manual smoke test:
  - [ ] tvOS: Launch app, navigate overlays, test focus
  - [ ] macOS: Launch app, verify toolbar/menus work
  - [ ] Check for console errors in Xcode

### After PR Merge
- [ ] Update this document with "Completed" status
- [ ] Tag commit in `git log` for reference
- [ ] Update `AGENTS.md` if architecture patterns changed

---

## Risk Mitigation

### High-Risk Areas
1. **TierListState extraction** (PR 4)
   - Many views depend on `tiers`, `tierOrder`, etc.
   - **Mitigation:** Introduce passthrough properties first, migrate gradually
   - **Rollback:** Keep old properties as `@available(*, deprecated)` wrappers

2. **H2H integration**
   - H2H logic depends on `tiers` heavily
   - **Mitigation:** Test H2H flow thoroughly after PR 4
   - **Rollback:** H2H already uses `headToHead.pool`, not direct tier access

3. **SwiftData interactions**
   - Persistence store must not break SwiftData
   - **Mitigation:** Use protocol to abstract SwiftData; test with in-memory context
   - **Rollback:** Keep `modelContext` accessible; store wraps it

### Low-Risk Areas
- AIGenerationState (already platform-gated, isolated)
- OverlaysState (pure UI routing, easy to test)
- Service protocols (additive change, no behavior impact)

---

## Acceptance Criteria (All PRs)

### Build Requirements
- ✅ tvOS 26 simulator builds and launches
- ✅ iOS 26 simulator builds and launches
- ✅ Native macOS builds and launches
- ✅ No new compiler warnings (strict concurrency or otherwise)

### Test Requirements
- ✅ All 55 TiercadeCore tests pass (`swift test`)
- ✅ All 52 security tests pass (when test target created)
- ✅ New unit tests for extracted states (where applicable)

### UX Requirements (tvOS Primary)
- ✅ Focus navigation unchanged (overlays, toolbars)
- ✅ Accessibility IDs stable (`Toolbar_H2H`, `QuickMove_Overlay`, etc.)
- ✅ Glass effects render correctly (no white film on focus)
- ✅ Exit command (Menu button) dismisses overlays

### Functional Requirements
- ✅ Tier operations work (move, delete, shuffle, undo/redo)
- ✅ Save/load/autosave works
- ✅ H2H flow works (start, vote, skip, finish)
- ✅ Theme picker/creator works
- ✅ AI chat works (macOS/iOS only)
- ✅ Export (JSON/CSV/PNG) works

---

## Apple Documentation References

### SwiftUI State Management
- **Observation macro migration:** https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/
- **Managing model data:** https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app/
- **State and data flow:** https://developer.apple.com/documentation/swiftui/state-and-data-flow/

### Swift 6 Concurrency
- **Adopting Swift 6:** https://developer.apple.com/documentation/swift/adoptingswift6/
- **Sendable protocol:** https://developer.apple.com/documentation/swift/sendable/
- **MainActor usage:** https://developer.apple.com/documentation/swift/mainactor/

### Dependency Injection Patterns
- **Protocol-oriented programming:** https://developer.apple.com/videos/play/wwdc2015/408/
- **Testing SwiftUI apps:** https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode/

---

## Example: Before/After for a Simple View

### Before (Current)
```swift
struct ThemeLibraryOverlay: View {
    @Bindable var appState: AppState  // Entire app state!

    var body: some View {
        VStack {
            ForEach(appState.availableThemes) { theme in
                Button(theme.displayName) {
                    appState.applyTheme(theme)
                }
            }
            Button("Close") {
                appState.showThemePicker = false
            }
        }
    }
}
```

### After (Target)
```swift
struct ThemeLibraryOverlay: View {
    @Bindable var theme: ThemeState  // Only theme state!

    var body: some View {
        VStack {
            ForEach(theme.availableThemes) { theme in
                Button(theme.displayName) {
                    theme.applyTheme(theme)
                }
            }
            Button("Close") {
                theme.showThemePicker = false
            }
        }
    }
}

// In parent view:
ThemeLibraryOverlay(theme: app.theme)
```

**Benefits:**
- View only re-renders when `ThemeState` changes (not all of `AppState`)
- Clear dependency: "This view needs theme management"
- Easy to test: `ThemeLibraryOverlay(theme: MockThemeState())`
- Previews work without full app state

---

## Next Steps to Start

### Immediate Actions
1. **Review this document** with the team/yourself
2. **Create tracking issue** in GitHub (if using issues)
3. **Create feature branch:** `git checkout -b refactor/appstate-decomposition`
4. **Start with PR 1** (protocols + DI) - lowest risk, highest value

### First Session Checklist
- [ ] Read this document completely
- [ ] Review current `AppState.swift` structure
- [ ] Review `HeadToHeadState.swift` as template (commit `c6aa1d1`)
- [ ] Create `Tiercade/Services/Protocols/` directory
- [ ] Start implementing `TierPersistenceStore` protocol

### Questions to Answer Before Starting
1. Do we want `ProgressState` separate or keep in `AppState`?
2. Should we do gradual migration (passthrough properties) or big-bang view updates?
3. Do we want test coverage for all new states or just critical paths?
4. Timeline: all 5 PRs in one session or spread across multiple days?

---

## Resources

### Related Documentation
- `AGENTS.md` - Agent instructions and architecture patterns
- `CONSOLIDATED_REVIEW.md` - Security and architecture review
- `CATALYST_TO_NATIVE_MACOS_MIGRATION.md` - Native macOS migration reference
- `TiercadeCore/README.md` - Core logic and testing patterns

### Key Commits for Reference
- `c6aa1d1` - H2H state consolidation (template for this refactor)
- `43fa7e8` - Centralized focus gating pattern
- `10af3f9` - Design tokens extraction pattern

### Codebase Patterns to Follow
- **State objects:** `@Observable @MainActor` (like `HeadToHeadState`)
- **Service protocols:** `Sendable`, async methods (like `ModelResolver`)
- **Errors:** Typed enums (like `PersistenceError`, `ImportError`)
- **Testing:** Swift Testing (`@Test`, `#expect`)

---

## Status Tracking

| PR | Description | Status | Commit | Date |
|----|-------------|--------|--------|------|
| PR 1 | Protocols + DI | 🔲 Not Started | - | - |
| PR 2 | AIGenerationState | 🔲 Not Started | - | - |
| PR 3 | PersistenceState + OverlaysState | 🔲 Not Started | - | - |
| PR 4 | TierListState | 🔲 Not Started | - | - |
| PR 5 | ThemeState + Cleanup | 🔲 Not Started | - | - |

**Legend:**
- 🔲 Not Started
- 🔄 In Progress
- ✅ Complete
- ❌ Blocked

---

## Conclusion

This refactor transforms `AppState` from a monolithic controller into a thin coordinator of purpose-built state objects. Each PR is independently valuable, reducing risk and enabling incremental progress.

**Total Estimated Time:** 17-22 hours (can be split across multiple sessions)

**Success Criteria:** Smaller, testable state objects with clear boundaries and protocol-based dependencies, while maintaining all existing functionality and tvOS-first UX patterns.

**Start Here:** PR 1 (Protocols + DI) - 2-3 hours, low risk, high foundation value.

---

**Document Version:** 1.0
**Last Updated:** 2025-11-02
**Author:** Generated via Claude Code
**Review Status:** Ready for implementation
