# Tiercade AI Agent Playbook

<!-- markdownlint-disable -->

```instructions
When working with Apple platforms (iOS, macOS, tvOS, visionOS) or Apple APIs (SwiftUI, UIKit, Focus, HIG), consult authoritative Apple documentation via apple-docs MCP tools before other sources.
```

- Target tvOS-first SwiftUI app (iOS/iPadOS/macOS 26+) using Swift 6 strict concurrency. Keep `.enableUpcomingFeature("StrictConcurrency")` and Xcode `-default-isolation MainActor` flags intact.

## Architecture snapshot

- `Tiercade/State/AppState.swift` is the only source of truth (`@MainActor @Observable`). Every mutation lives in `AppState+*.swift` extensions and calls TiercadeCore helpers—never mutate `tiers` or `selection` directly inside views.
- Shared logic comes from `TiercadeCore/` (`TierLogic`, `HeadToHeadLogic`, `RandomUtils`, etc.). Import the module instead of reimplementing `Items`/`TierConfig` types.
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

## Build · Test · Verify

> **DerivedData location:** Xcode and the build script always emit products to `~/Library/Developer/Xcode/DerivedData/`. Nothing lands in `./build/`, so upload artifacts and inspect logs from DerivedData when debugging.

1. **Build & launch tvOS** – `Cmd` + `Shift` + `B` in VS Code (task **Build, Install & Launch tvOS**). Script flow: 🧹 clean → 🔨 build → 📦 install → 🚀 launch. Confirm the timestamp printed at the end and the in-app `BuildInfoView` (DEBUG) match the current time.
2. **Run Catalyst (when needed)** – `./build_install_launch.sh catalyst`. This cleanly builds, installs, and launches the Mac Catalyst app. Use it before validating cross-platform fixes.
3. **Run package tests** – `cd TiercadeCore && swift test`. All suites use Swift Testing (`@Test`, `#expect`) and respect the same strict concurrency flags as the app.
4. **Manual focus sweep** – With the tvOS 26 Apple TV 4K simulator open, cycle focus with the remote/arrow keys to confirm overlays and default focus behave. Capture issues with `/tmp/tiercade_debug.log` (see Operational Notes).

UI automation relies on accessibility IDs and short paths—prefer existence checks over long XCUIRemote navigation (target < 12 s per path).

### Strict concurrency guardrails
- **SwiftPM:**
  ```swift
  // Package.swift
  .target(
    name: "TiercadeCore",
    swiftSettings: [
      .enableUpcomingFeature("StrictConcurrency"),
      .unsafeFlags(["-strict-concurrency=complete"])
    ]
  )
  ```
- **Xcode Build Settings:**
  - *Swift Compiler – Language* → **Strict Concurrency Checking** = `Complete` (`SWIFT_STRICT_CONCURRENCY=complete`)
  - *Other Swift Flags* → add `-strict-concurrency=complete` for legacy configurations.
  - *Swift Language Version* = `Swift 6`; keep **Enable Upcoming Features** consistent with the package manifest.
  These mirror Apple’s Swift 6 migration notes and align with the README guardrails.


## Tooling & diagnostics

- Asset refresh: manage bundled artwork directly in `Tiercade/Assets.xcassets` and keep paths aligned with `AppState+BundledProjects`.
- Debug logging: `AppState.appendDebugFile` writes to `/tmp/tiercade_debug.log`; the CI pipeline emits `tiercade_build_and_test.log` plus before/after screenshots under `pipeline-artifacts/`. Attach those files when filing issues.
- SourceKit often flags “No such module 'TiercadeCore'”; defer to `xcodebuild` results before debugging module wiring.

## Collaboration norms

- Use Conventional Commits with scopes (e.g. `feat(tvOS):`, `fix(core):`).
- Prefer Swift Testing (`@Test`, `#expect`) for new coverage; legacy XCTest lives beside new tests until migrated.

---

## Tiercade AI Agent Instructions

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

## Platform Strategy: Mac Catalyst

**Platforms:** tvOS 26+ (primary) | iOS/iPadOS/macOS 26+ via Mac Catalyst
- Mac runs as **Mac Catalyst** app (UIKit-based iOS app on macOS), NOT native AppKit
- Benefits: Single iOS/iPadOS/Mac codebase, reduced platform conditionals, unified design system
- tvOS remains separate (fundamentally different UX paradigm)

### Catalyst-Aware Patterns

**Quick reference:** Reuse shared SwiftUI views whenever possible. Catalyst-only UX (menu bar commands, hover affordances) should live in the same files behind `targetEnvironment(macCatalyst)` checks, or move into helpers under `Views/Platform/Catalyst` if the code grows.

**Platform checks:**
```swift
// Correct: Check for UIKit availability
#if canImport(UIKit)
import UIKit
#endif

// Correct: iOS family (includes Catalyst)
#if os(iOS) || targetEnvironment(macCatalyst)
  // iOS, iPadOS, and Mac Catalyst code
#endif

// Correct: tvOS-specific
#if os(tvOS)
  // tvOS-only code
#endif

// Avoid: Checking for macOS (Catalyst is iOS, not macOS)
#if os(macOS)  // ❌ This excludes Catalyst!
```

**Liquid Glass fallbacks:**
- Liquid Glass (`glassEffect`) is available on iOS, iPadOS, macOS (including Catalyst), and tvOS 26+. We intentionally lead with tvOS styling, but the same modifiers work on other OSes.
- When a platform doesn’t support the desired effect (older OS, watchOS, etc.) fall back to `.ultraThinMaterial` / `.thinMaterial`.
- `GlassEffects.swift` handles these decisions automatically via platform checks.

**API availability:**
- TabView `.page` style is available on Catalyst 14.0+; prefer `.automatic` unless you explicitly want page-style paging on desktop.
- UIKit APIs available on Catalyst (UIApplication, UIImage, etc.)
- NavigationSplitView works identically across iOS/iPadOS/Catalyst

**Build script:**
```bash
# tvOS (default)
./build_install_launch.sh

# Mac Catalyst
./build_install_launch.sh catalyst
```

## Architecture & Data Flow

### Structure
- **App:** SwiftUI tvOS app with iOS support. Views in `Views/{Main,Overlays,Toolbar}` composed in `MainAppView.swift`
- **Core logic:** `TiercadeCore` Swift package (iOS 26+/macOS 26+/tvOS 26+) — platform-agnostic models and logic
  - Models: `Item`, `Items` (typealias for `[String: [Item]]`), `TierConfig`
  - Logic: `TierLogic`, `HeadToHeadLogic`, `RandomUtils`
  - **Never recreate TL* aliases** — import from TiercadeCore directly

### State Management
**Central state:** `@MainActor @Observable final class AppState` in `State/AppState.swift`
- Extensions in `State/AppState+*.swift`: `+Persistence`, `+Export`, `+Import`, `+Analysis`, `+Toast`, `+Progress`, `+HeadToHead`, `+Selection`, `+Theme`, etc.
- **Flow:** View → `AppState` method → TiercadeCore logic → mutate `tiers`/history → SwiftUI auto-refresh

### Core State Properties
```
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
    let snapshot = captureTierSnapshot()
    tiers = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
    finalizeChange(action: "Move Item", undoSnapshot: snapshot)
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

### Typed error taxonomy
- `ExportError` (scoped to `AppState+Export`) — bubble to UI toast with destructive option on failure.
- `ImportError` — map validation failures to info toast; unexpected decoding issues should be rethrown for crash logging.
- `PersistenceError` — surfaced when manual save/load fails; retry after showing blocking alert.
- `AnalysisError` (future) should remain internal; analytics UI already checks `canShowAnalysis`.

## tvOS UX & Focus Management

### Focus System
- **Overlays:** `Views/Overlays/` use `.focusSection()` + `.focusable()`
- **Modal blocking:** Set `.allowsHitTesting(!modalActive)` on background (never `.disabled()`) so scroll inertia and VoiceOver focus remain intact while overlays are up
- **Accessibility IDs:** Required for UI tests. Convention: `{Component}_{Action}` (e.g., `Toolbar_H2H`, `QuickMove_Overlay`, `ActionBar_MultiSelect`)

| Accessibility ID | Purpose |
| --- | --- |
| `Toolbar_NewTierList` | Primary entry point for the tier list wizard |
| `Toolbar_H2H` | Head-to-head launch action (enabled when enough items) |
| `Toolbar_Analysis` | Opens/closes analytics overlay |
| `Toolbar_Themes` | Presents theme library |
| `ActionBar_MoveBatch` | Batch move button in selection mode |
| `QuickMove_Overlay` | tvOS quick-move overlay root – ensures UI tests can wait for presentation |
| `MatchupOverlay_Apply` | Commit action for head-to-head queue |
- **tvOS 26 interactions:** Use `.focusable(interactions: .activate)` for action-only surfaces and opt into additional interactions (text entry, directional input) only when needed so the new multi-mode focus model stays predictable on remote hardware.
- **Default focus:** Use `.prefersDefaultFocus(true, in:)` and a scoped `@FocusState` to land on the primary control when overlays appear.

```swift
@Namespace private var defaultFocusNamespace
@FocusState private var activeField: Field?
enum Field { case primary }

VStack { /* primary controls */ }
  .prefersDefaultFocus(true, in: defaultFocusNamespace)
  .focused($activeField, equals: .primary)
  .onAppear { activeField = .primary }
  .onExitCommand { appState.cancelOverlay(fromExitCommand: true) }
```
- **Focus effects:** When supplying custom focus visuals, gate the system halo with `.focusEffectDisabled(_:)` and validate both the default glass halo and any overrides using the Apple TV 4K (3rd gen) tvOS 26 simulator profile.

**Critical bug pattern:** NEVER add `.accessibilityIdentifier()` to parent containers with `.accessibilityElement(children: .contain)` — this overrides all child IDs. Apply to leaf elements only (buttons, cards, specific views).

### Exit Command Pattern
tvOS Exit button (Menu/⌘) should dismiss modals, not exit app:
```swift
#if os(tvOS)
.onExitCommand { app.dismissCurrentOverlay() }
#endif
```

### Head-to-Head (Matchup Arena) Overlay Specifics
- **Pass tile:** Centered with `arrow.uturn.left.circle` icon, live counter (`MatchupOverlay_SkippedBadge`)
- **Focus default:** Primary contender when a pair is active
- **Queue exhaustion:** Auto-show Commit button (`MatchupOverlay_Apply`) when queue empties
- **Exit handling:** Route through `cancelH2H(fromExitCommand:)` for debounce

### Design Tokens
**Use `Design/` helpers exclusively** — no hardcoded values
- Colors: `Palette.primary`, `Palette.text`, `Palette.tierS`, etc.
- Typography: `TypeScale.h1`, `TypeScale.body`, etc.
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`
- Effects: Apply Liquid Glass with SwiftUI’s tvOS 26 APIs — `glassEffect(_:in:)`, `GlassEffectContainer`, and `buttonStyle(.glass)`/`GlassProminentButtonStyle` — for chrome surfaces in our tvOS 26 target; fallbacks are optional and only necessary if we later choose to support older devices.

### Liquid Glass support matrix
| Platform | Implementation | Helper |
| --- | --- | --- |
| tvOS 26+ | `glassEffect` / `glassBackgroundEffect` with focus-ready spacing | See `GlassContainer` helper below |
| iOS · iPadOS · macOS (Catalyst) | `.ultraThinMaterial` fallback inside the same shape | See `GlassContainer` helper below |

```swift
@ViewBuilder func GlassContainer<S: Shape, V: View>(_ shape: S, @ViewBuilder _ content: () -> V) -> some View {
  #if os(tvOS)
  content().glassBackgroundEffect(in: shape, displayMode: .fill)
  #else
  content().background(.ultraThinMaterial, in: shape)
  #endif
}
```

## Build & Test

### Build Commands
**Primary**: VS Code task "Build, Install & Launch tvOS" (Cmd+Shift+B) — runs `./build_install_launch.sh`
**Manual:**
```bash
# tvOS
./build_install_launch.sh
# Catalyst
./build_install_launch.sh catalyst
# Manual tvOS build only
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' build
```

### Test Commands
TiercadeCore owns package tests. Run `swift test` inside `TiercadeCore/` (Swift Testing). UI automation stays lean—see UI test minimalism below.

### UI test minimalism
- Prefer existence checks and stable accessibility IDs over long remote navigation. Target < 12 s per focus path.

| Screen | ID to assert | Expectation |
| --- | --- | --- |
| Toolbar | `Toolbar_NewTierList` | Exists, isEnabled before launching wizard |
| Head-to-Head overlay | `MatchupOverlay_Apply` | Appears once queue empties |
| Quick Move | `QuickMove_Overlay` | Presented before accepting commands |
| Batch bar | `ActionBar_MoveBatch` | Visible only when selection count > 0 |
| Analytics | `Toolbar_Analysis` | Toggles analytics sidebar |

### UI Test Strategy
- **Framework:** Use minimal UI tests only when necessary. Prefer existence checks and direct access via accessibility identifiers.
- **Launch arg:** `-uiTest` can enable test-only hooks in the app when needed.
- **Focus:** Existence checks (`app.buttons["ID"].exists`), element counts, simple component verification.
- **Avoid:** Complex remote navigation; long paths cause timeouts.

### Manual Verification
- Validate visuals in the latest tvOS 26 Apple TV 4K simulator; that environment mirrors the focus halos and Liquid Glass chrome we care about.
- After builds: Keep simulator open, test focus/dismissal with Siri Remote simulator (or Mac keyboard arrows/Space/ESC)

## Data Contracts & Patterns

### Tier Structure
**Order:** `["S","A","B","C","D","F","unranked"]` (always respect `displayLabel`/`displayColorHex` overrides)
- Attribute contract:
  - **MUST** provide a unique `id` per project and a display `name` (stored in `attributes["name"]`).
  - **SHOULD** supply `seasonNumber` when a numeric season exists; use `seasonString` when free-form text is required.
  - **MAY** attach additional metadata (tags, status, URLs) via the `attributes` dictionary—ModelResolver preserves unknown keys.

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
| Path | Responsibility | Tests / Expectations |
| --- | --- | --- |
| `Tiercade/State` | `AppState` and feature extensions | Covered via integration, keep strict concurrency & typed errors |
| `Tiercade/Views` | SwiftUI surfaces (Main, Overlays, Toolbar, Components) | Manual focus sweep + targeted UI assertions |
| `Tiercade/Design` | Tokens (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`) | Visual inspection; no direct tests |
| `Tiercade/Export` | Export formatters (text/CSV/JSON/PNG/PDF) | Swift Testing snapshots cover output |
| `Tiercade/Util` | Focus helpers, reusable utilities | Unit tests or inline assertions where behaviour is complex |
| `TiercadeCore/Sources` | Pure Swift models, logic, formatters | `swift test` (Swift Testing) required for changes |
| `TiercadeCore/Tests` | Swift Testing suites | Additive; keep deterministic RNG seeds |

## Debugging Notes

### SourceKit False Positives
"No such module 'TiercadeCore'" errors in Xcode/SourceKit are common — **trust `xcodebuild` output**

### Debug Logging
`AppState.appendDebugFile(message)` writes to `/tmp/tiercade_debug.log`

### Image Asset Management
Maintain bundled images manually within `Tiercade/Assets.xcassets`. Ensure any changes stay consistent with identifiers referenced in `AppState+BundledProjects`.

### Common Issues
1. **Build fails:** Check TiercadeCore is added as local package dependency
2. **UI test timeouts:** Reduce navigation complexity, use direct element access
3. **Focus loss:** Verify `.focusSection()` boundaries, check accessibility ID placement
4. tvOS 26 requires TLS 1.2+ by default for outbound network requests; ensure remote endpoints negotiate an acceptable cipher suite or customize `NWProtocolTLS.Options` if absolutely necessary.

### Security & runtime checklist
- **ATS:** Keep App Transport Security enabled (default). Only add per-host exceptions with documented justification.
- **Pinned hosts:** If we pin certificates, update the list in `Networking/TrustedHosts.swift` and cover it with integration tests.
- **Retry/backoff:** Networking helpers default to exponential backoff (see `Networking/RetryPolicy.swift`). Respect those defaults unless a backend owner approves changes.

