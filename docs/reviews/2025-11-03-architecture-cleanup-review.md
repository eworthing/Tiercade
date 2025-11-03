# Tiercade Architecture Cleanup Review — Naming, Coupling, Magic Numbers, Invariants

Date: 2025-11-03
Owner: Codex CLI review pass
Scope: tvOS-first SwiftUI app (iOS/iPadOS/macOS 26+) with Swift 6 strict concurrency

## Summary

Future maintainers will struggle most with:
- Opaque abbreviations (e.g., `h2h*`) and many flat flags in `AppState`.
- Implicit coupling across overlays/focus gating implemented via scattered booleans.
- Magic numbers embedded in logic and UI, lacking centralized tokens.
- Hidden invariants (e.g., `tierOrder` excludes `unranked`, dual theme sources of truth, Liquid Glass on container backgrounds).

This document lists the top issues and provides one concrete rewrite exemplar for each category to make intent obvious and reduce regressions. Apple documentation confirms patterns for Liquid Glass, focus handling on tvOS/macOS, and Observation usage.

---

## 1) Naming

### Problem: `h2h*` scatter hides domain and flow
- Opaque abbreviation and numerous flat properties in `AppState` obscure lifecycle and make testing brittle.
- References: `Tiercade/State/AppState.swift:140–160`, `Tiercade/State/AppState+HeadToHead.swift`

### Rewrite exemplar: Consolidate under a single typed state
```swift
// In AppState.swift
struct HeadToHeadState: Sendable {
  var isActive = false
  var pool: [Item] = []
  var currentPair: (Item, Item)?
  var records: [String: H2HRecord] = [:]
  var pairsQueue: [(Item, Item)] = []
  var deferredPairs: [(Item, Item)] = []
  var startedAt: Date?
  enum Phase: Sendable { case quick, refinement }
  var phase: Phase = .quick
}

// In AppState
var headToHead = HeadToHeadState()

// Usage
if headToHead.isActive { ... }
```

Benefits: One source of truth; fewer accidental desyncs; easier unit-testing and telemetry.

---

### Problem: Stringly-typed tier keys ("S"…"unranked")
- Repeated string literals and special-casing of `"unranked"` invite typos and inconsistent logic.
- References: `Tiercade/State/AppState.swift:97–99`, `Tiercade/State/AppState+Items.swift`, `Tiercade/State/AppState+Persistence.swift`

### Rewrite exemplar: Use TiercadeCore’s type-safe identifiers
```swift
import TiercadeCore

// Replace
var tiers: Items = ["S":[], ... , "unranked":[]]
var tierOrder: [String] = ["S","A","B","C","D","F"]

// With
var tiers: TypedItems = [:]
var rankedTierOrder: [TierIdentifier] = TierIdentifier.rankedTiers
var unrankedTier: TierIdentifier { .unranked }

// Access
tiers[.unranked, default: []].append(item)
let allTiers = rankedTierOrder + [.unranked]
```

Benefits: Compiler-enforced invariants; fewer runtime mistakes; clearer intent.

---

### Problem: `showThemePicker` vs `themePickerActive`
- Two booleans must remain in sync to satisfy focus/overlay timing; names don’t signal lifecycle.
- References: `Tiercade/State/AppState.swift:122–123`, `Tiercade/State/AppState+Theme.swift`, `Tiercade/Views/Overlays/ThemeLibraryOverlay.swift`

### Rewrite exemplar: Model as a lifecycle
```swift
struct OverlayState { var isRequested = false; var isActive = false }
var themePicker = OverlayState()

// Open/close
themePicker.isRequested.toggle()
themePicker.isActive = themePicker.isRequested // preserves current race-avoidance
```

Benefits: Encodes intent; safer future refactors; consistent pattern for other overlays.

---

## 2) Implicit Coupling

### Problem: Background focus gating is an OR over many flags
- Adding any new overlay risks forgetting to update every `allowsHitTesting(!modalBlockingFocus)` call.
- References: `Tiercade/Views/Main/MainAppView.swift:24–46`, `:102–170`

### Rewrite exemplar: Centralize the rule
```swift
extension AppState {
  var blocksBackgroundFocus: Bool {
    (detailItem != nil)
    || headToHead.isActive
    || themePicker.isActive
    || (quickMoveTarget != nil)
    || showThemeCreator
    || showTierListCreator
    || (showAIChat && AppleIntelligenceService.isSupportedOnCurrentPlatform)
  }
}
// Use
.allowsHitTesting(!app.blocksBackgroundFocus)
```

Benefits: Single maintenance point; fewer accidental holes in focus/interaction gating.

---

### Problem: Splits forced `private` → `internal` across files
- Scope leak after splitting views/helpers increases coupling and surface area.
- References: `ContentView+TierGrid+HardwareFocus.swift`

### Rewrite exemplar: Nest helpers to preserve privacy
```swift
extension TierGridView {
  fileprivate enum Navigation { /* move logic + state here, keep private */ }
}
```

Benefits: Keeps encapsulation; prevents incidental access from unrelated files.

---

### Problem: AI generation availability isn’t guarded at call-site
- tvOS overlay can accidentally reach iOS/macOS-only APIs at runtime.
- References: `AIItemGeneratorOverlay.swift`, `AppState+AIGeneration.swift`

### Rewrite exemplar: Guard with availability
```swift
Button {
  if #available(iOS 26.0, macOS 26.0, *) {
    Task { await appState.generateItems(description: itemDescription, count: itemCount) }
  }
} label: { Label("Generate", systemImage: "sparkles") }
```

Benefits: Compile-time safety and clear platform behavior.

---

## 3) Magic Numbers

### Problem: Exit-command debounce `0.35`
- Hidden behavioral contract; hard to tune and reuse.
- Reference: `Tiercade/State/AppState+HeadToHead.swift:218–223`

### Rewrite exemplar
```swift
#if os(tvOS)
enum TVInteraction { static let exitCommandDebounce: TimeInterval = 0.35 }
#endif
// Use
Date().timeIntervalSince(activatedAt) < TVInteraction.exitCommandDebounce
```

---

### Problem: Quick/refinement weighting `0.75`
- Product decision baked into code with no name.
- Reference: `Tiercade/State/AppState.swift:227–246`

### Rewrite exemplar
```swift
enum HeadToHeadWeights { static let quickPhase: Double = 0.75 }
// Use
progress = quickFraction.clamped01 * HeadToHeadWeights.quickPhase
```

---

### Problem: Quick-phase thresholds (`10→3`, `6→3`, else `2`)
- Bare values hide intent; scattered changes risky.
- Reference: `Tiercade/State/AppState+HeadToHead.swift:254–266`

### Rewrite exemplar
```swift
enum H2HHeuristics {
  static let largePool = 10, mediumPool = 6
  static let largeDesired = 3, mediumDesired = 3, smallDesired = 2
}
```

---

### Problem: UI dimensions (e.g., `640`, `1180`, corner radii, paddings)
- Hard-coded UI values fight the token system and create drift.
- References: `ThemeLibraryOverlay.swift` (max heights/widths), `QuickMoveOverlay.swift`

### Rewrite exemplar
```swift
enum OverlayMetrics {
  static let themeGridMaxHeight: CGFloat = 640
  static let themeContainerMaxWidth: CGFloat = 1180
}
// Replace raw numbers with OverlayMetrics.*
```

---

### Problem: Toast duration `3.0`
- Duplicated assumptions about user feedback timing.
- Reference: `AppState+Toast.swift`

### Rewrite exemplar
```swift
enum ToastDefaults { static let duration: TimeInterval = 3.0 }
// Default parameter uses ToastDefaults.duration
```

---

## 4) Hidden Invariants

### Problem: `tierOrder` excludes `unranked` but many flows need "all tiers"
- Frequent `tierOrder + ["unranked"]` recreations increase bug surface.
- References: `AppState+Items.swift`, `QuickMoveOverlay.swift`

### Rewrite exemplar (with typed tiers)
```swift
var rankedTierOrder: [TierIdentifier] = TierIdentifier.rankedTiers
var allTiers: [TierIdentifier] { rankedTierOrder + [.unranked] }
```

---

### Problem: `selectedTheme` and `selectedThemeID` must stay in sync
- Two sources of truth cause subtle persistence/apply issues.
- References: `AppState.swift:120–123`, `AppState+Theme.swift`, `AppState+Persistence.swift`

### Rewrite exemplar
```swift
var selectedTheme: TierTheme = TierThemeCatalog.defaultTheme
var selectedThemeID: UUID { selectedTheme.id } // computed
```

Persist only the ID and resolve `selectedTheme` once when restoring.

---

### Problem: Liquid Glass on containers behind focusable views
- On tvOS, system focus overlays become unreadable through glassy backgrounds. Apple recommends using Liquid Glass for chrome (buttons, headers), not section/container backgrounds.
- References: `ThemeLibraryOverlay.swift: glassEffect(...)` on the main container

### Rewrite exemplar
```swift
// Container: use a solid, opaque background
RoundedRectangle(cornerRadius: 24, style: .continuous)
  .fill(Color.black.opacity(0.85))
  .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15), lineWidth: 1))

// Apply glass to toolbar/buttons only
Button("Create Theme") { ... }.buttonStyle(.glass)
```

---

### Problem: AI retry telemetry invariants
- Per-attempt flags must reset each iteration; mixing local booleans and state struct fields risks stale metrics.
- References: Guided path reset is correct (`retryState.sessionRecreated = false`), but `generateTextArray` still uses a local `sessionRecreated`.

### Rewrite exemplar
```swift
// Unify per-attempt state under RetryState in both guided and unguided loops
for attempt in 0..<params.maxRetries {
  retryState.sessionRecreated = false
  // pass retryState into handlers; report retryState.sessionRecreated
}
```

---

## Apple Documentation References
- Focus handling
  - `focusSection()` — guides focus across cohorts (tvOS/macOS)
  - `onExitCommand(perform:)` — exit command on tvOS/macOS
  - `onMoveCommand(perform:)` — directional input
- Liquid Glass
  - `glassEffect(_:in:)` — Liquid Glass effect and guidance on using `GlassEffectContainer`
- Observation
  - Observation framework overview and migration to `@Observable`

These confirm the patterns used here for focus sections, exit/move commands on tvOS, and proper application of Liquid Glass only to chrome.

---

## Suggested First Patch Set
1) Introduce typed wrappers/constants
   - `HeadToHeadState`, `OverlayState`, `HeadToHeadWeights`, `H2HHeuristics`, `OverlayMetrics`, `ToastDefaults`.
2) Type-safe tiers
   - Store `TypedItems` and migrate tier access sites; keep boundary methods for string keyed interop.
3) Centralize background focus gating
   - Add `AppState.blocksBackgroundFocus`; replace all call sites in `MainAppView`.
4) Availability guards
   - Guard AI generation on tvOS and non-26 platforms at all call sites.
5) Glass sweep for overlays
   - Restrict `glassEffect` to header/buttons; use solid backgrounds for containers.

This improves readability, testability, and reduces future regressions in focus/fx behavior on tvOS while aligning with Apple’s current platform docs.

