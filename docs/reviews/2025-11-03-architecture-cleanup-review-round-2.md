# Tiercade Architecture Cleanup Review — Round 2

Date: 2025-11-03
Owner: Codex CLI follow-up review
Scope: Post-fix pass focusing on remaining naming issues, implicit coupling, magic numbers, and hidden invariants. Verified key Apple API usage (focusSection, onExitCommand, glassEffect, Observation) against Apple docs.

## What’s improved since last review
- Export UI now gates PDF on tvOS (`#if !os(tvOS)`), reducing platform mismatches.
- Focus scoping, `.onExitCommand`, and `.focusSection()` usage are consistent with Apple guidance.
- Observation (`@Observable`) and main-actor state patterns remain aligned with Swift 6 strict concurrency.

Below are remaining hotspots with concrete rewrite exemplars.

---

## 1) Naming

### A. Sentinel Item for Quick Move (batch mode)
- Problem: `presentBatchQuickMove()` synthesizes a dummy `Item(id: "batch", ...)` to drive overlay presentation.
- Why it hurts: Hides intent, conflates view-state with data, and risks leaking sentinel IDs into analytics/persistence paths.
- Exemplar rewrite:
```swift
// AppState.swift
struct QuickMoveState { var target: Item?; var isBatch = false }
var quickMove = QuickMoveState()

// Presenters
func presentBatchQuickMove() {
  guard !selection.isEmpty else { return }
  quickMove.isBatch = true
  quickMove.target = nil // overlay consumes selection count directly
}

// Overlay reads app.quickMove.isBatch and app.selection.count
```

### B. UserDefaults keys as bare strings
- Problem: `tierListStateKey`, `tierListRecentsKey` live as top-level `let` string constants.
- Why it hurts: Increases risk of typos and inconsistent usage.
- Exemplar rewrite:
```swift
enum DefaultsKeys { static let activeTier = "Tiercade.tierlist.active.v1"; static let recents = "Tiercade.tierlist.recents.v1" }
// Replace call sites accordingly
```

### C. ExportFormat scope and labeling
- Observation: `ExportFormat` sits in `AppState.swift` with UI-facing strings.
- Recommendation: Move `ExportFormat` to a UI/Export namespace or file (e.g., `Export/ExportFormat.swift`) to reduce AppState bloat and clarify ownership. Keep `displayName` as UI-only.

---

## 2) Implicit Coupling

### A. Overlay z-ordering via scattered numeric zIndex
- Problem: Multiple hard-coded `.zIndex` values in `MainAppView` encode layering rules implicitly.
- Why it hurts: Adding overlays requires mentally merging the numeric stack, increasing regressions.
- Exemplar rewrite:
```swift
enum OverlayZ { static let progress = 50.0; static let quickRank = 40.0; static let quickMove = 45.0; static let h2h = 40.0; static let analytics = 52.0; static let browser = 53.0; static let themePicker = 54.0; static let aiChat = 55.0; static let themeCreator = 55.0; static let toast = 60.0 }
// Use: .zIndex(OverlayZ.themePicker)
```

### B. Focus reassertion timing hack in Theme overlay
- Problem: `.onChange(of: overlayHasFocus)` reasserts focus after `50ms` delay.
- Why it hurts: Magic delay couples timing to platform behavior and can become brittle.
- Exemplar rewrite:
```swift
enum FocusWorkarounds { static let reassertDelay: Duration = .milliseconds(50) }
// Use: try? await Task.sleep(for: FocusWorkarounds.reassertDelay)
```

---

## 3) Magic Numbers

### A. Autosave interval `30.0`
- Problem: `autosaveInterval = 30.0` is embedded in `AppState`.
- Exemplar rewrite:
```swift
enum PersistenceIntervals { static let autosave: TimeInterval = 30.0 }
// Use: let interval = PersistenceIntervals.autosave
```

### B. Token chunking budget `800`
- Problem: `chunkByTokens(_:budget: 800)` controls Apple Intelligence prompt chunk size but lives as an unlabelled default.
- Exemplar rewrite:
```swift
enum AIChunking { static let tokenBudget = 800 }
func chunkByTokens(_ keys: [String], budget: Int = AIChunking.tokenBudget) -> [[String]] { ... }
```

### C. AI Hybrid thresholds `0.70`
- Problem: `hybridDupThreshold = 0.70` is a bare heuristic.
- Exemplar rewrite:
```swift
enum AIDedupHeuristics { static let hybridRoundDupThreshold = 0.70 }
// Use: hybridDupThreshold = AIDedupHeuristics.hybridRoundDupThreshold
```

### D. Quick Move UI dimensions (e.g., `frame(height: 74)`, paddings)
- Problem: Raw values appear in overlay buttons and layouts.
- Exemplar rewrite:
```swift
enum QuickMoveMetrics { static let buttonHeight: CGFloat = 74; static let buttonCorner: CGFloat = 16 }
// Use: .frame(height: QuickMoveMetrics.buttonHeight)
```

---

## 4) Hidden Invariants

### A. AI unguided retry telemetry still uses local sessionRecreated
- Problem: Guided path correctly resets `retryState.sessionRecreated` per attempt; unguided path declares a local `sessionRecreated` instead of living in a shared `RetryState`.
- Why it hurts: Telemetry can diverge from actual behavior and regress silently during refactors.
- Exemplar rewrite:
```swift
// Align unguided path with guided per-attempt RetryState pattern
var retryState = RetryState(options: currentOptions, seed: params.initialSeed, lastError: nil, sessionRecreated: false)
for attempt in 0..<params.maxRetries {
  retryState.sessionRecreated = false
  // pass &report retryState.sessionRecreated
}
```

### B. Tier order and special `unranked` semantics
- Status: Much logic already appends `"unranked"` ad hoc.
- Recommendation: Consolidate with typed tiers consistently (see prior review): `rankedTierOrder + [.unranked]`, and bridge to `Items` only at boundaries.

### C. Export availability vs. platform behavior
- Status: Toolbar UI now gates PDF on tvOS. Double-check command surfaces (macOS Commands are macOS-only) and export coordinator to ensure `exportToFormat(.pdf)` never executes on tvOS.
- Exemplar pattern:
```swift
#if os(tvOS)
let allowed: [ExportFormat] = [.text, .json, .markdown, .csv, .png]
#else
let allowed: [ExportFormat] = ExportFormat.allCases
#endif
```

---

## Apple Documentation Anchors
- Focus & tvOS commands: `onExitCommand(perform:)`, `onMoveCommand(perform:)`, `focusSection()` — correct usage for dismissal and directional input on tvOS/macOS.
- Liquid Glass: `glassEffect(_:in:)` — apply on chrome (buttons, headers) rather than section/container backgrounds to preserve focus overlay readability.
- Observation: Observation framework and SwiftUI migration — continued use of `@Observable` and main-actor mutation aligns with guidance.

---

## Suggested Next Patch Set
1) Introduce state wrappers and constants:
   - `QuickMoveState`, `DefaultsKeys`, `OverlayZ`, `FocusWorkarounds`, `PersistenceIntervals`, `AIChunking`, `AIDedupHeuristics`, `QuickMoveMetrics`.
2) Replace sentinel `Item` usage in Quick Move with explicit view state.
3) Unify unguided AI retry logic with guided `RetryState` pattern and per-attempt resets.
4) Continue type-safe tier adoption where string keys remain, bridging at boundaries only.
5) Sweep overlay z-indices to use the centralized `OverlayZ` constants.

These changes reduce accidental coupling, encode behavioral contracts, and make future platform/UX adjustments safer and more discoverable.

