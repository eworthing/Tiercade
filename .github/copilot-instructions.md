```instructions
When working with Apple platforms (iOS, macOS, tvOS, visionOS) or Apple APIs (SwiftUI, UIKit, Focus, HIG), consult authoritative Apple documentation via apple-docs MCP tools before other sources.
```

# Tiercade AI Agent Playbook

- Target tvOS-first SwiftUI app (iOS/iPadOS/macOS 26+) using Swift 6 strict concurrency. Keep `.enableUpcomingFeature("StrictConcurrency")` and Xcode `-default-isolation MainActor` flags intact.

## Architecture snapshot
- `Tiercade/State/AppState.swift` is the only source of truth (`@MainActor @Observable`). Every mutation lives in `AppState+*.swift` extensions and calls TiercadeCore helpers—never mutate `tiers` or `selection` directly inside views.
- Shared logic comes from `TiercadeCore/` (`TierLogic`, `HistoryLogic`, `HeadToHeadLogic`, `RandomUtils`, etc.). Import the module instead of reimplementing `Items`/`TierConfig` types.
- Views are grouped by intent: `Views/Main` (tier grid / `MainAppView`), `Views/Toolbar`, `Views/Overlays`, `Views/Components`. Match existing composition when adding surfaces.
- Design tokens live in `Tiercade/Design/` (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`). Reference these rather than hardcoding colors or spacing, especially for tvOS focus chrome.
- `SharedCore.swift` wires TiercadeCore + design singletons; keep dependency injection consistent with its patterns.

## State & async patterns
- Follow the pipeline `View → AppState method → TiercadeCore → state update → SwiftUI refresh`. Example: `AppState+Items.moveItem` wraps `TierLogic.moveItem` and auto-captures history.
- Long work must use `withLoadingIndicator` / `updateProgress` from `AppState+Progress`; success and failure feedback flows through `AppState+Toast`.
- Persistence & import/export: `AppState+Persistence` auto-saves to UserDefaults; `AppState+Export` and `+Import` wrap async file IO with typed errors (`ExportError`, `ImportError`). tvOS excludes PDF export via `#if os(tvOS)`.

## tvOS-first UX rules
- Overlays (QuickMove, HeadToHead, ThemePicker, etc.) are separate focus sections using `.focusSection()` and `.focusable(interactions: .activate)`. Keep background content interactive by toggling `.allowsHitTesting(!overlayActive)`—never `.disabled()`.
- Accessibility IDs must follow `{Component}_{Action}` on leaf elements (e.g. `Toolbar_H2H`, `QuickMove_Overlay`). Avoid placing IDs on containers using `.accessibilityElement(children: .contain)`.
- Head-to-head overlay contract: render skip card with `clock.arrow.circlepath`, maintain `H2H_SkippedCount`, call `cancelH2H(fromExitCommand:)` from `.onExitCommand`.
- Apply glass effects via `glassEffect`, `GlassEffectContainer`, or `.buttonStyle(.glass)` when touching toolbars/overlays; validate focus halos in the Apple TV 4K (3rd gen) tvOS 26 simulator.

## Build, test, verify
- Fast build: use the VS Code task “Build tvOS Tiercade (Debug)” or
  ```bash
  xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
    -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
    -configuration Debug build
  ```
- Core logic tests: `cd TiercadeCore && swift test`.
- Full tvOS pipeline (build + UI tests + artifacts in `/tmp`): `./tools/tvOS_build_and_test.sh`.
- UI automation relies on accessibility IDs and short paths—use existence checks, avoid long XCUIRemote navigation (>12 s causes timeouts).
- Manual sign-off keeps the tvOS 26 simulator open, cycling focus via Siri Remote or keyboard arrows after each build.

## Tooling & diagnostics
- Asset refresh: `TMDB_API_KEY=… ./tools/fetch_bundled_images.sh` (see `tools/README_IMAGES.md`).
- Debug logging: `AppState.appendDebugFile` writes to `/tmp/tiercade_debug.log`; pipeline script also emits `tiercade_build_and_test.log` and before/after screenshots.
- SourceKit often flags “No such module 'TiercadeCore'”; defer to `xcodebuild` results before debugging module wiring.

## Collaboration norms
- Use Conventional Commits with scopes (e.g. `feat(tvOS):`, `fix(core):`).
- Prefer Swift Testing (`@Test`, `#expect`) for new coverage; legacy XCTest lives beside new tests until migrated.

---

# Tiercade AI Agent Instructions

A SwiftUI tier list management app targeting tvOS 26+/iOS 26+ with Swift 6 strict concurrency. Primary platform is tvOS with remote-first UX patterns.

## Swift 6 / OS 26 Modernization Mandates

**Target:** iOS/iPadOS/tvOS/macOS 26 with Swift 6 strict concurrency
- **Strict concurrency:** `.enableUpcomingFeature("StrictConcurrency")` + `.unsafeFlags(["-strict-concurrency=complete"])`
- **State management:** `@Observable` + `@Bindable` + `@MainActor` (never `ObservableObject`/`@Published`)
- **UI:** SwiftUI only. `NavigationStack`/`NavigationSplitView` (no deprecated `NavigationView`)
- **Async:** Structured concurrency (`async`/`await`, `AsyncSequence`, `TaskGroup`). Phase out Combine
- **Testing:** Swift Testing (`@Test`, `#expect`) for new tests. Migrate XCTest incrementally
- **Persistence:** SwiftData (`@Model`, `@Query`) for new features. Migrate Core Data gradually
- **Dependencies:** SwiftPM only. Use SPM traits: `traits: [.featureFlag("feature-name")]`
- **Complexity:** `cyclomatic_complexity` warning at 8, error at 12

**Migration priorities:** `ObservableObject`→`@Observable` | Combine→`AsyncSequence` | `NavigationView`→`NavigationStack` | Core Data→SwiftData | XCTest→Swift Testing | callbacks→`async/await` | queues→actors

## Architecture & Data Flow

### Structure
- **App:** SwiftUI tvOS app with iOS support. Views in `Views/{Main,Overlays,Toolbar}` composed in `MainAppView.swift`
- **Core logic:** `TiercadeCore` Swift package (iOS 17+/macOS 14+/tvOS 17+) — platform-agnostic models and logic
  - Models: `Item`, `Items` (typealias for `[String: [Item]]`), `TierConfig`, `History`
  - Logic: `TierLogic`, `HistoryLogic`, `HeadToHeadLogic`, `RandomUtils`
  - **Never recreate TL* aliases** — import from TiercadeCore directly

### State Management
**Central state:** `@MainActor @Observable final class AppState` in `State/AppState.swift`
- Extensions in `State/AppState+*.swift`: `+Persistence`, `+Export`, `+Import`, `+Analysis`, `+Toast`, `+Progress`, `+HeadToHead`, `+Selection`, `+Theme`, etc.
- **Flow:** View → `AppState` method → TiercadeCore logic → mutate `tiers`/history → SwiftUI auto-refresh

### Core State Properties
```swift
var tiers: Items = ["S":[],"A":[],"B":[],"C":[],"D":[],"F":[],"unranked":[]]
var tierOrder: [String] = ["S","A","B","C","D","F"]
var selection: Set<String> = []
var h2hActive: Bool, h2hPair: (Item, Item)?
var tierLabels: [String: String], tierColors: [String: String]
var selectedTheme: TierTheme
```

### State Mutation Pattern
**Always route through AppState methods** that call TiercadeCore logic:
```swift
// Correct pattern - no direct mutation methods in AppState.swift
// Mutations happen via TiercadeCore in extension methods:
func moveItem(_ id: String, to tier: String) {
    tiers = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
    // History auto-captured by HistoryLogic
}
```

### Async Operations & Progress
Wrap long operations with loading indicators and progress tracking:
```swift
await withLoadingIndicator(message: "Loading...") {
    updateProgress(0.5)
    // async work
}
// Shows toast on success/error via AppState+Toast
```

### Persistence
- **Auto-save:** UserDefaults via `AppState+Persistence.swift` (save/load/autoSave)
- **Export:** `exportToFormat(.text/.json/.markdown/.csv/.png/.pdf)` — tvOS excludes PDF via `#if os(tvOS)`
- **Import:** Use `ModelResolver.loadProject(from: data)` → `resolveTiers()` for JSON/CSV

## tvOS UX & Focus Management

### Focus System
- **Overlays:** `Views/Overlays/` use `.focusSection()` + `.focusable()`
- **Modal blocking:** Set `.allowsHitTesting(!modalActive)` on background (never `.disabled()` — breaks accessibility)
- **Accessibility IDs:** Required for UI tests. Convention: `{Component}_{Action}` (e.g., `Toolbar_H2H`, `QuickMove_Overlay`, `ActionBar_MultiSelect`)
- **tvOS 26 interactions:** Use `.focusable(interactions: .activate)` for action-only surfaces and opt into additional interactions (text entry, directional input) only when needed so the new multi-mode focus model stays predictable on remote hardware.
- **Focus effects:** When supplying custom focus visuals, gate the system halo with `.focusEffectDisabled(_:)` and validate both the default glass halo and any overrides using the Apple TV 4K (3rd gen) tvOS 26 simulator profile.

**Critical bug pattern:** NEVER add `.accessibilityIdentifier()` to parent containers with `.accessibilityElement(children: .contain)` — this overrides all child IDs. Apply to leaf elements only (buttons, cards, specific views).

### Exit Command Pattern
tvOS Exit button (Menu/⌘) should dismiss modals, not exit app:
```swift
#if os(tvOS)
.onExitCommand { app.dismissCurrentOverlay() }
#endif
```

### Head-to-Head Overlay Specifics
- **Skip card:** Centered with `clock.arrow.circlepath` icon, live counter (`H2H_SkippedCount`)
- **Focus default:** Left option when pair is active
- **Queue exhaustion:** Auto-show Finish button when queue empties
- **Exit handling:** Route through `cancelH2H(fromExitCommand:)` for debounce

### Design Tokens
**Use `Design/` helpers exclusively** — no hardcoded values
- Colors: `Palette.primary`, `Palette.text`, `Palette.tierS`, etc.
- Typography: `TypeScale.h1`, `TypeScale.body`, etc.
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`
- Effects: Apply Liquid Glass with SwiftUI’s tvOS 26 APIs — `glassEffect(_:in:)`, `GlassEffectContainer`, and `buttonStyle(.glass)`/`GlassProminentButtonStyle` — for chrome surfaces in our tvOS 26 target; fallbacks are optional and only necessary if we later choose to support older devices.

## Build & Test

### Build Commands
**VS Code task:** "Build tvOS Tiercade (Debug)"
**Manual:**
```bash
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'
```

### Test Commands
```bash
# Core logic tests (Swift Testing)
cd TiercadeCore && swift test

# Full pipeline (build + UI tests + artifacts)
./tools/tvOS_build_and_test.sh

# Artifacts land in /tmp:
# - tiercade_ui_before.png, tiercade_ui_after.png
# - tiercade_debug.log
# - tiercade_build_and_test.log
```

### UI Test Strategy
- **Framework:** Swift Testing for new tests. UI tests use `XCUIRemote.shared` for tvOS remote simulation
- **Launch arg:** `-uiTest` enables test-only hooks
- **Focus:** Existence checks (`app.buttons["ID"].exists`), element counts, component verification
- **Avoid:** Complex navigation (XCUIRemote too slow, causes timeouts ~12s)
- **Current suite:** 11 tests, ~2min runtime, 100% passing

### Manual Verification
- Validate visuals in the latest tvOS 26 Apple TV 4K simulator; that environment mirrors the focus halos and Liquid Glass chrome we care about.
- After builds: Keep simulator open, test focus/dismissal with Siri Remote simulator (or Mac keyboard arrows/Space/ESC)

## Data Contracts & Patterns

### Tier Structure
**Order:** `["S","A","B","C","D","F","unranked"]` (always respect `displayLabel`/`displayColorHex` overrides)
**Items:** TiercadeCore `Item` type:
```swift
Item(id: String, attributes: [String: Any])
// Key fields: name, seasonString/seasonNumber, imageUrl
```

### Error Handling
Use typed errors (Swift 6 pattern):
```swift
enum ExportError: Error { case formatNotSupported, dataEncodingFailed, ... }
enum ImportError: Error { case invalidFormat, missingRequiredField, ... }
```

### Commits
Conventional Commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
Add scope for clarity: `feat(tvOS): implement quick move overlay`

## Key Directories
```
Tiercade/
  State/           # AppState + extensions
  Views/           # Main, Overlays, Toolbar, Components
  Design/          # Tokens (Palette, Metrics, TypeScale, TVMetrics)
  Export/          # Format renderers
  Util/            # Focus helpers, utilities
TiercadeCore/      # Platform-agnostic Swift package
  Sources/         # Models, Logic, Formatters
  Tests/           # Swift Testing unit tests
tools/             # Build/test automation, image fetching
```

## Debugging Notes

### SourceKit False Positives
"No such module 'TiercadeCore'" errors in Xcode/SourceKit are common — **trust `xcodebuild` output**

### Debug Logging
`AppState.appendDebugFile(message)` writes to `/tmp/tiercade_debug.log`

### Image Asset Management
```bash
export TMDB_API_KEY='your-key'
./tools/fetch_bundled_images.sh  # Fetch images for bundled tierlists
# See tools/README_IMAGES.md for details
```

### Common Issues
1. **Build fails:** Check TiercadeCore is added as local package dependency
2. **UI test timeouts:** Reduce navigation complexity, use direct element access
3. **Focus loss:** Verify `.focusSection()` boundaries, check accessibility ID placement
4. tvOS 26 requires TLS 1.2+ by default for outbound network requests; ensure remote endpoints negotiate an acceptable cipher suite or customize `NWProtocolTLS.Options` if absolutely necessary.
