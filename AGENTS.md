# Tiercade AI Agent Playbook

<!-- markdownlint-disable -->

<!--
⚠️ WARNING: This is the SOURCE file for AI agent instructions.
Do NOT delete this file - it has two symlinks pointing to it:
- CLAUDE.md → AGENTS.md
- .github/copilot-instructions.md → ../AGENTS.md

To update AI instructions, edit THIS file (AGENTS.md).
Changes will automatically propagate through the symlinks.
-->

```instructions
When working with Apple platforms (iOS, macOS, tvOS, visionOS) or Apple APIs (SwiftUI, UIKit, Focus, HIG), consult authoritative Apple documentation via apple-docs MCP tools before other sources.
```

- Target tvOS-first SwiftUI app (iOS/iPadOS/macOS 26+) using Swift 6 strict concurrency. Keep `.enableUpcomingFeature("StrictConcurrency")` and Xcode `-default-isolation MainActor` flags intact.

## Apple Intelligence Prototype Scope (Read Me First)

**📚 AI Documentation Hub**: All AI-related specs, diagnostics, and testing docs → `docs/AppleIntelligence/README.md`

- Prototype-only: All Apple Intelligence list-generation, **item generation**, prompt testing, and chat integrations are for testing and evaluation. Do not ship this code path to production as-is.
- **Platform gating**: AI item generation (AIItemGeneratorOverlay) is **macOS/iOS-only**. tvOS displays a platform notice and cannot invoke FoundationModels.
- Reference: See `docs/AppleIntelligence/DEEP_RESEARCH_2025-10.md` for the consolidated research plan and experiment matrix.
- Cross-domain prompts: Techniques must remain domain-agnostic. We cannot tailor prompts to specific item types because end-user requests may ask for any kind of list.
- Winning-method handoff: The final product will be re-architected using the best-performing approach discovered here. Treat current algorithms, prompts, and testers as disposable scaffolding.
- Feature-gated: Keep advanced generation behind compile-time flags and DEBUG defaults. Maintain platform gating (macOS/iOS only) and keep tvOS UI independent.
- Agent guidance: If you are an LLM modifying this repo, prefer improving test coverage, diagnostics, and documentation over deepening prototype coupling with production surfaces. Avoid migrating experimental code into main app flows.

## Architecture snapshot

- `Tiercade/State/AppState.swift` is the only source of truth (`@MainActor @Observable`). Every mutation lives in `AppState+*.swift` extensions and calls TiercadeCore helpers—never mutate `tiers` or `selection` directly inside views.
- Shared logic comes from `TiercadeCore/` (`TierLogic`, `HeadToHeadLogic`, `RandomUtils`, etc.). Import the module instead of reimplementing `Items`/`TierConfig` types.
- Views are grouped by intent: `Views/Main` (tier grid / `MainAppView`), `Views/Toolbar`, `Views/Overlays`, `Views/Components`. Match existing composition when adding surfaces. **Proactive file size targets:** Keep overlays under ~400 lines, view files under ~600 lines; split helper views early to avoid reactive SwiftLint cleanup cycles (see [7f9fb84](https://github.com/eworthing/Tiercade/commit/7f9fb84), [373d731](https://github.com/eworthing/Tiercade/commit/373d731), [1837087](https://github.com/eworthing/Tiercade/commit/1837087) where files grew to 700+ lines before splitting).
- Design tokens live in `Tiercade/Design/` (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`). Reference these rather than hardcoding colors or spacing, especially for tvOS focus chrome.
- `SharedCore.swift` wires TiercadeCore + design singletons; keep dependency injection consistent with its patterns.

## State & async patterns

- Follow the pipeline `View → AppState method → TiercadeCore → state update → SwiftUI refresh`. Example: `AppState+Items.moveItem` wraps `TierLogic.moveItem` and auto-captures history.
- Long work must use `withLoadingIndicator` / `updateProgress` from `AppState+Progress`; success and failure feedback flows through `AppState+Toast`.
- Persistence & import/export: `AppState+Persistence` auto-saves to UserDefaults; `AppState+Export` and `+Import` wrap async file IO with typed errors (`ExportError`, `ImportError`). tvOS excludes PDF export via `#if os(tvOS)`.

### Parallelizing Independent Operations

Use `async let` to run independent async operations concurrently:

```swift
// ❌ Sequential (slow): waits for export before starting analysis
let exportResult = await generateExport()
let analysisResult = await computeAnalysis()

// ✅ Parallel (fast): both run simultaneously
async let exportResult = generateExport()
async let analysisResult = computeAnalysis()
let (export, analysis) = await (exportResult, analysisResult)
```

**When to use:** Operations have no dependencies and don't need sequencing
**Examples in Tiercade:** Export + Analysis, theme fetch + catalog refresh, concurrent tier calculations

### AI Generation Loop Invariants
**When working with Apple Intelligence retry logic** (AppleIntelligence+UniqueListGeneration.swift), preserve these critical state semantics:

**RetryState parameter object pattern ([ca46798](https://github.com/eworthing/Tiercade/commit/ca46798)):**
- State like `sessionRecreated`, `seed`, `options` lives in a `RetryState` struct passed by `inout`
- **Per-attempt scoping:** Reset flags at the **start** of each loop iteration
- **Telemetry accuracy:** Always report current attempt's state, not stale values from previous iterations

**Common bug pattern ([1c5d26b](https://github.com/eworthing/Tiercade/commit/1c5d26b)):**
```swift
// ❌ WRONG: Local variable shadows struct field, reports stale value
var sessionRecreated = false  // Never updated!
for attempt in 0..<maxRetries {
    // ... handleAttemptFailure updates retryState.sessionRecreated ...
    recordMetrics(sessionRecreated: sessionRecreated)  // ❌ Always false!
}

// ✅ CORRECT: Reset struct field per-attempt, report current value
for attempt in 0..<maxRetries {
    retryState.sessionRecreated = false  // ✅ Reset each iteration
    // ... handleAttemptFailure updates retryState.sessionRecreated ...
    recordMetrics(sessionRecreated: retryState.sessionRecreated)  // ✅ Accurate!
}
```

**After parameter-object refactors:**
1. Search for local variables with same names as new struct fields (shadowing)
2. Remove shadowing variables and update all references to use struct fields
3. Verify per-loop reset logic is preserved
4. Run acceptance tests: See debug hooks in `Tiercade/Views/Overlays/AIChat/AIChatOverlay+Tests.swift` for quick manual validation

## tvOS-first UX rules

- **Modal overlays** (ThemePicker, TierListBrowser, HeadToHead/HeadToHead, Analytics, QuickMove) use `.fullScreenCover()` which provides **automatic focus containment** via separate presentation context. This is Apple's recommended pattern for modal presentations that must trap focus.
- **Transient overlays** (QuickRank) remain as ZStack overlays using `.focusSection()` and `.focusable()`. For these, keep background content interactive by toggling `.allowsHitTesting(!overlayActive)`—never `.disabled()`.
- **Critical**: `.allowsHitTesting()` only blocks pointer interactions (taps/clicks), **not focus navigation**. For true focus containment, use `.fullScreenCover()` or `.sheet()` presentation modifiers.

### Modal vs Transient: Decision Tree

**When to use `.fullScreenCover()` (Modal):**
- ✅ User must complete or cancel the overlay (blocking interaction)
- ✅ Overlay content is the sole focus of attention
- ✅ Background should not be interactive during overlay
- ✅ Focus must be contained within overlay
- **Examples:** ThemePicker, TierListBrowser, HeadToHead, QuickMove, Analytics

**When to use ZStack + `.focusSection()` (Transient):**
- ✅ Overlay provides contextual information only
- ✅ User may want to interact with background simultaneously
- ✅ Overlay appears/dismisses frequently (lightweight)
- ✅ Focus containment not required
- **Examples:** QuickRank tooltip, contextual hints, non-blocking notifications

**If unsure:** Default to `.fullScreenCover()` - it's easier to relax to transient than to fix focus escape bugs later.

- **Overlay Accessibility Pattern**: When adding new overlays for iOS/macOS, use `AccessibilityBridgeView` to ensure immediate accessibility tree presence. See `Tiercade/Views/OVERLAY_ACCESSIBILITY_PATTERN.md` for full pattern documentation. This solves async timing issues between state updates and accessibility registration on non-tvOS platforms.
- Accessibility IDs must follow `{Component}_{Action}` on leaf elements (e.g. `Toolbar_HeadToHead`, `TierMove_Sheet`). Avoid placing IDs on containers using `.accessibilityElement(children: .contain)`.
- HeadToHead overlay contract: render skip card with `arrow.uturn.left.circle`, surface skip count in the metrics row, call `cancelHeadToHead(fromExitCommand:)` from `.onExitCommand`.
- Apply glass effects via `glassEffect`, `GlassEffectContainer`, or `.buttonStyle(.glass)` when touching toolbars/overlays; validate focus halos in the Apple TV 4K (3rd gen) tvOS 26 simulator.

## Build · Test · Verify

> **DerivedData location:** Xcode and the build script always emit products to `~/Library/Developer/Xcode/DerivedData/`. Nothing lands in `./build/`, so upload artifacts and inspect logs from DerivedData when debugging.

1. **Build all platforms** – `Cmd` + `Shift` + `B` in VS Code (task **Build, Install & Launch tvOS**). Script flow per platform: 🧹 clean → 🔨 build → 📦 install → 🚀 launch. Builds tvOS, iOS, iPadOS, and macOS by default. Confirm the timestamp and `BuildInfoView` (DEBUG) match.
2. **Single platform builds** – Use `./build_install_launch.sh tvos|ios|ipad|macos` to build individual platforms when iterating on platform-specific code.
3. **Run package tests** – `cd TiercadeCore && swift test`. The `TiercadeCoreTests` target covers tier manipulation, HeadToHead heuristics, bundled catalog metadata, and model decoding using Swift Testing (`@Test`, `#expect`) under the same strict concurrency flags.
4. **Manual focus sweep** – With the tvOS 26 Apple TV 4K simulator open, cycle focus with the remote/arrow keys to confirm overlays and default focus behave. Capture issues with `/tmp/tiercade_debug.log` (see Operational Notes).

Optional coverage pass:

```bash
cd TiercadeCore
swift test --enable-code-coverage
xcrun llvm-cov report \
  --instr-profile .build/debug/codecov/default.profdata \
  .build/debug/TiercadeCorePackageTests.xctest/Contents/MacOS/TiercadeCorePackageTests
```

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
- **State & UI expectations:** Views run on `@MainActor` data via `@Observable`/`@Bindable`; never fall back to `ObservableObject`, `@Published`, or deprecated `NavigationView`.
- **Async & persistence:** Prefer structured concurrency (`async/await`, `AsyncSequence`, `TaskGroup`) plus SwiftData for new persistence flows; phase out Combine and legacy Core Data code paths. Use SwiftData (`ModelContext`, `@Model`) only in app targets; keep TiercadeCore free of SwiftUI/SwiftData so it stays a pure logic module.
- **Testing & dependencies:** Add Swift Testing (`@Test`, `#expect`) coverage for new work and keep dependencies in SwiftPM with `traits: [.featureFlag("name")]`.
- **Complexity & forms:** Keep files within lint thresholds (cyclomatic complexity warn=8, error=12) and wire multi-field forms with `.submitLabel(.next/.done)`, `.onSubmit {}`, and `@FocusState` to support keyboard navigation.
- **Migration priorities:** Continue incrementally moving callbacks→`async/await`, queues→actors, string concatenation→interpolation, RTL test coverage, and destructive alerts→`confirmationDialog`.


## Tooling & diagnostics

- Asset refresh: manage bundled artwork directly in `Tiercade/Assets.xcassets` and keep paths aligned with `AppState+BundledProjects`.
- Debug logging: `AppState.appendDebugFile` writes to `/tmp/tiercade_debug.log`; the CI pipeline emits `tiercade_build_and_test.log` plus before/after screenshots under `pipeline-artifacts/`. Attach those files when filing issues.
- **Build script feature flags**: `./build_install_launch.sh --enable-advanced-generation` (all platforms) or `./build_install_launch.sh macos --enable-advanced-generation` (single platform) - see `docs/AppleIntelligence/FEATURE_FLAG_USAGE.md`
- **AI test runner**: `./run_all_ai_tests.sh` with result analysis via `python3 analyze_test_results.py results/run-<TIMESTAMP>/`
  - Test suite configs: `Tiercade/TestConfigs/TestSuites.json`
  - Framework docs: `Tiercade/TestConfigs/TESTING_FRAMEWORK.md`
- SourceKit often flags "No such module 'TiercadeCore'"; defer to `xcodebuild` results before debugging module wiring.
- SwiftUI previews: use `PreviewHelpers.makeAppState` and static fixtures so views in `Views/Components` and `Views/Overlays` compile and render in isolation without wiring the full app.

## Collaboration norms

- Use Conventional Commits with scopes (e.g. `feat(tvOS):`, `fix(core):`).
- Prefer Swift Testing (`@Test`, `#expect`) for new coverage; legacy XCTest lives beside new tests until migrated.

---

## Tiercade AI Agent Instructions

A SwiftUI tier list management app targeting tvOS 26+/iOS 26+ with Swift 6 strict concurrency. Primary platform is tvOS with remote-first UX patterns.

## Platform Strategy: Native macOS ✅ (Completed Oct 2025)

**Platforms:** tvOS 26+ (primary) | iOS/iPadOS 26+ | macOS 26+ (native)
- Mac runs as **native macOS** app using AppKit/SwiftUI
- **Mac Catalyst removed** - Migration completed in #59 (Oct 27, 2025)
- Native AppKit APIs: NSWorkspace, NSPasteboard, NSImage
- Menu bar commands: TiercadeCommands.swift (⌘N, ⌘⇧H, ⌘A, ⌘E, ⌘I)
- tvOS remains primary focus (fundamentally different UX paradigm)

### Native macOS Patterns

**Quick reference:** Reuse shared SwiftUI views whenever possible. macOS-specific UX (menu bar commands, hover affordances, toolbar customization) should be conditionally compiled behind `#if os(macOS)` checks.

**Platform checks:** Prefer module-availability checks plus explicit OS scopes so platform-specific code stays isolated:
```swift
#if canImport(UIKit)
import UIKit  // iOS + tvOS helpers
#endif

#if canImport(AppKit)
import AppKit  // native mac features
#endif

#if os(tvOS)
// tvOS-only behaviour (remote navigation, focus routing)
#endif

#if os(iOS)
// iOS/iPadOS-only behaviour (touch gestures, multitasking tweaks)
#endif
```

**Liquid Glass support:**
- Liquid Glass (`glassEffect`) is available on iOS, iPadOS, macOS, and tvOS 26+. We intentionally lead with tvOS styling, but the same modifiers work on other OSes.
- When a platform doesn't support the desired effect (older OS, watchOS, etc.) fall back to `.ultraThinMaterial` / `.thinMaterial`.
- `GlassEffects.swift` handles these decisions automatically via platform checks.

**API availability differences:**
- TabView `.page`: iOS/tvOS only — stick with `.automatic` on macOS.
- `fullScreenCover`: iOS/tvOS only — present as `.sheet` on macOS.
- `editMode` + `navigationBarTitleDisplayMode`: iOS-only — rely on `.navigationTitle` for macOS/tvOS.
- Toolbar `.topBarLeading` / `.topBarTrailing`: iOS-only — use `.principal` / `.automatic` elsewhere.
- UIKit types (`UIApplication`, `UIImage`, `UIPasteboard`, etc.) exist only on iOS/tvOS — swap for AppKit equivalents (`NSApplication`, `NSImage`, `NSPasteboard`) on macOS.

**Build script:** Use `./build_install_launch.sh` (all or per-platform arguments) as detailed in [Build & Test](#build--test).

**NavigationSplitView guardrails (macOS/iPad):**
- Always feed production content into the active detail column. `NavigationSplitView` defaults to showing the detail pane, so leaving it empty hides the toolbar and tier grid.
- Route macOS/iPad through the shared `tierGridLayer` + `ToolbarView` composition. If you need to debug layouts, keep scaffolding behind `#if DEBUG` and delete it before merging.
- Prefer the two-column initializer (`sidebar:detail:`) unless you truly need a middle content column.
- Whenever you add or rename toolbar actions on tvOS, wire the same control into the macOS/iOS toolbar and assign the shared accessibility identifier (e.g., `Toolbar_MultiSelect`). Reviews should fail if macOS or iOS loses parity with tvOS toolbar.
- Hardware keyboard parity: treat arrow keys and Escape/Return as first-class inputs. New overlays and interactive surfaces should forward tvOS `.onMoveCommand` handlers to shared directional helpers and register `.onKeyPress` equivalents for iPad and macOS so hardware keyboards mirror Siri Remote navigation.

## Architecture & Data Flow

### Structure
- **App:** SwiftUI multi-platform app (tvOS, iOS, macOS). Views in `Views/{Main,Overlays,Toolbar}` composed in `MainAppView.swift`
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
var headToHead = HeadToHeadState()
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
Don’t introduce separate view models for core tier logic; views bind `AppState` (via `@Bindable`) and call `AppState+*.swift` methods for all mutations.

### File Splitting & Access Control
**When splitting files for SwiftLint compliance,** manage Swift's visibility rules carefully:

**Critical visibility rules:**
- Properties/methods accessed across split files **must** be `internal` (not `private`)
- Extensions in separate files need `internal` visibility (Swift scopes `private` to the file)
- Example: After splitting `ContentView+TierGrid.swift` → `ContentView+TierGrid+HardwareFocus.swift`, shared properties like `hardwareFocus`, `lastHardwareFocus` must change from `private` → `internal`

**Mandatory build verification (prevents cross-platform regressions like [f662d34](https://github.com/eworthing/Tiercade/commit/f662d34)):**
```bash
# Build ALL platforms (tvOS, iOS, iPadOS, macOS)
./build_install_launch.sh
```

All four platforms **must** build successfully before merging structural splits. Each platform can surface different visibility and API availability issues:
- Native macOS often catches visibility issues that tvOS doesn't
- iOS/iPadOS may reveal UIKit-specific problems
- Platform-specific APIs must be properly gated with `#if os(...)`

**Pattern from recent splits:**
- [f662d34](https://github.com/eworthing/Tiercade/commit/f662d34) - Fixed macOS build errors: `private` → `internal` for cross-file access
- [5fe41fe](https://github.com/eworthing/Tiercade/commit/5fe41fe), [0060169](https://github.com/eworthing/Tiercade/commit/0060169) - HeadToHeadOverlay, TierListProjectWizardPages splits required visibility updates

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
- **Modal overlays:** Use `.fullScreenCover()` for automatic focus containment (ThemePicker, TierListBrowser, HeadToHead, Analytics, QuickMove)
- **Transient overlays:** ZStack overlays use `.focusSection()` + `.focusable()` (QuickRank)
- **Focus containment:** `.allowsHitTesting()` only blocks pointer input, **not focus**. For true focus trapping, use modal presentation modifiers (`.fullScreenCover()`, `.sheet()`)
- **Background interaction:** Set `.allowsHitTesting(!modalActive)` on background (never `.disabled()`) for transient overlays so scroll inertia and VoiceOver remain intact
- **Accessibility IDs:** Required for UI tests. Convention: `{Component}_{Action}` (e.g., `Toolbar_HeadToHead`, `TierMove_Sheet`, `ActionBar_MultiSelect`)

- **Key IDs:** `Toolbar_NewTierList`, `Toolbar_HeadToHead`, `Toolbar_Analysis`, `Toolbar_Themes`, `ActionBar_MoveBatch`, `TierMove_Sheet`, `HeadToHeadOverlay_Apply`, `AIGenerator_Overlay`.
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

### ⚠️ Focus Anti-Pattern: Manual Focus Reset Loops

Never cache a `lastFocus` value or set focus back when it becomes `nil`. Use modal presentations (`.fullScreenCover()`/`.sheet()`) for containment, `.focusSection()` for guidance, and custom routing only to move focus predictably within complex grids. **See [Focus Anti-Pattern Reference](#focus-anti-pattern-reference-nov-2025)** for the full examples and rationale.

### HeadToHead Overlay Specifics
Keep the header’s phase badge + metrics rail, surface the pass tile with `arrow.uturn.left.circle`, focus the active contender (falling back to `HeadToHeadOverlay_Apply` when the queue is empty), and route `.onExitCommand` through `cancelHeadToHead(fromExitCommand:)`.

### Design Tokens
**Use `Design/` helpers exclusively** — no hardcoded values
- Colors: `Palette.primary`, `Palette.text`, `Palette.brand`
- Typography: `TypeScale.*` for every text surface; apply `TypeScale.IconScale` (or text-style-driven `.imageScale`) to SF Symbols so they inherit Dynamic Type. Never use `.font(.system(size: …))` for icons or inline glyphs outside of prototypes.
- Layout: Prefer `ScaledDimensions` with `@ScaledMetric(relativeTo:)` for any fixed width/height/padding that must react to Dynamic Type. Avoid raw numeric frames unless the size truly never changes.
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`
- Effects: Apply Liquid Glass with SwiftUI's tvOS 26 APIs — `glassEffect(_:in:)`, `GlassEffectContainer`, and `buttonStyle(.glass)`/`GlassProminentButtonStyle` — for chrome surfaces in our tvOS 26 target; fallbacks are optional and only necessary if we later choose to support older devices.

**Tier Colors (state-driven):**
- Tiers support custom names, custom ordering, and variable counts (not just SABCDF)
- **Always** use `Palette.tierColor(tierId, from: app.tierColors)` to respect theme customization
- Avoid hardcoded tier lookups (`Palette.tierS`) or static tier IDs ("S", "A", etc.)
- When using focus effects, prefer `.punchyFocus(color:)` over `.punchyFocus(tier:)` for custom tier color support

### Liquid Glass support matrix
- **tvOS 26+**: Use `glassEffect(_:in:)` with focus-safe spacing.
- **iOS · iPadOS · macOS**: Fall back to `.ultraThinMaterial` inside the same shape.

```swift
@ViewBuilder func GlassContainer<S: Shape, V: View>(_ shape: S, @ViewBuilder _ content: () -> V) -> some View {
#if os(tvOS)
  content().glassEffect(.regular, in: shape)
#else
  content().background(.ultraThinMaterial, in: shape)
#endif
}
```

### ⚠️ Critical: Glass Effects and Focus Overlays

Keep glass on chrome, never behind focusable content—tvOS focus overlays turn unreadable when layered over translucent backgrounds.

```swift
VStack {
  HStack { /* toolbar buttons */ }
    .glassEffect(.regular, in: Rectangle())  // chrome only

  TextField("Name", text: $name)
    .padding(12)
    .background(Color.black.opacity(0.7))    // solid background
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 2))
}
```

Solid backgrounds + subtle borders keep focus legible on every platform; validate in the tvOS 26 Apple TV 4K simulator.

❌ **DON'T**
```swift
VStack {
  TextField("Name", text: $name)
}
.padding(20)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))  // focus overlay becomes unreadable
```

**Best practices:**
- ✅ Apply glass to toolbars, headers, and buttons only.
- ✅ Keep content sections on opaque fills (e.g., `Color.black.opacity(0.6)`) with subtle strokes for separation.
- ✅ Leave `.focusEffectDisabled(false)` on text fields so the system halo stays visible.
- ✅ Re-test in the tvOS 26 Apple TV 4K simulator after UI changes to confirm focus overlays remain legible.

### Context Menus (iOS/macOS)

Provide long-press/right-click actions on items:

```swift
ItemCardView(item: item)
    .contextMenu {
        Button("Move to S") { app.moveItem(item.id, to: "S") }
        Button("Edit") { app.editItem(item.id) }
        Button("Delete", role: .destructive) { app.deleteItem(item.id) }
    }
```

**Platform considerations:**
- iOS/iPadOS: Long-press reveals menu
- macOS: Right-click or two-finger tap
- tvOS: Long-press on Play/Pause button works but may conflict with focus UX—test thoroughly

**Accessibility:** Ensure all context menu actions have keyboard/VoiceOver equivalents in toolbars or menus.

## Focus Anti-Pattern Reference (Nov 2025)

The November 2025 sweep cataloged every place we tried to “trap” focus manually. Treat this as a living checklist for future overlays.

### Manual reset loop (never reintroduce)

```swift
// ❌ Anti-pattern: fighting the focus system
@State private var lastFocus: HeadToHeadFocusAnchor?
@State private var suppressReset = false

.onChange(of: focusAnchor) { _, newValue in
    guard !suppressReset else { return }
    if let newValue { lastFocus = newValue }
    else if let lastFocus { focusAnchor = lastFocus } // <-- wrong
}
```

- Breaks tvOS hardware navigation and VoiceOver.
- **Correct fix:** use modal presentation (`.fullScreenCover()`/`.sheet()`), declare a `@FocusState` default, and use helper methods to route arrows INSIDE the overlay rather than forcing focus back to a stored value.

### Legitimate custom routing

```swift
func handleMoveCommand(_ direction: MoveCommandDirection) {
    switch direction {
    case .left:  focusAnchor = anchorToLeft(of: focusAnchor)
    case .right: focusAnchor = anchorToRight(of: focusAnchor)
    case .up:    focusAnchor = anchorAbove(focusAnchor)
    case .down:  focusAnchor = anchorBelow(focusAnchor)
    }
}
```

Use this when the grid/layout is too custom for the default focus engine; it *guides* focus without trapping it.

### Overlay status snapshot

| Overlay | Status (Nov 2025) |
| --- | --- |
| HeadToHeadOverlay.swift | ✅ Modal + `@FocusState`, no manual reset |
| QuickMoveOverlay.swift | ✅ Converted to modal |
| TierListBrowserScene.swift | ✅ Converted to modal |
| ThemeCreatorOverlay.swift | ⚠️ Keep verifying it stays modal after edits |
| ThemeLibraryOverlay.swift | ⚠️ Ensure obsolete `.onChange` workarounds stay removed |

### Checklist for any new overlay

- [ ] Uses `.fullScreenCover()` (tvOS/iOS) or `.sheet()` (macOS) whenever focus must be contained; transient overlays rely on `.focusSection()`.
- [ ] **Does NOT** use `lastFocus`, `suppressFocusReset`, or manual focus reassignment—default focus is established via `@FocusState` + `.prefersDefaultFocus`.
- [ ] `.onExitCommand` routes to the overlay’s cancel method and hardware arrows cannot escape to background content in any direction.
- [ ] Accessibility IDs follow `{Component}_{Action}` on leaf elements, and the overlay registers in the accessibility hierarchy immediately on iOS/macOS.
- [ ] Glass effects stay on chrome (toolbars/buttons), while content areas use opaque backgrounds so focus halos remain legible.
- [ ] Focus ring/halo is visible and readable in the tvOS 26 Apple TV 4K (3rd gen) simulator.
- [ ] Full hardware sweep with Siri Remote / keyboard arrows shows predictable directional routing (no dead ends or traps).
- [ ] Builds succeed on all platforms via `./build_install_launch.sh` (tvOS Apple TV 4K 3rd gen, iOS iPhone 17 Pro, iPadOS iPad mini A17 Pro, macOS native app).
- [ ] Platform-specific behaviour is gated with `#if os(...)` and uses the correct presentation style per OS.
- [ ] Overlay-specific accessibility actions (buttons, default controls) remain reachable via VoiceOver / Switch Control.

## Build & Test

### Build Commands

**⚠️ CRITICAL: Always build ALL platforms before merging**

The default build script builds all four platforms to catch platform-specific issues early.

**Primary**: VS Code task "Build, Install & Launch tvOS" (Cmd+Shift+B) — runs `./build_install_launch.sh`

**Multi-platform builds:**
```bash
# Build all platforms (tvOS, iOS, iPadOS, macOS) - RECOMMENDED
./build_install_launch.sh
# or explicitly
./build_install_launch.sh all

# Build all platforms without launching
./build_install_launch.sh --no-launch
```

**Single platform builds:**
```bash
# tvOS only
./build_install_launch.sh tvos

# iOS only (iPhone)
./build_install_launch.sh ios

# iPadOS only (iPad)
./build_install_launch.sh ipad

# Native macOS only
./build_install_launch.sh macos

# Manual tvOS build (low-level)
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' build
```

### Test Commands
TiercadeCore owns package tests. Run `swift test` inside `TiercadeCore/` (Swift Testing). UI automation stays lean—see UI test minimalism below.

### Critical Test Scenarios
**Import/Export validation before merging** (prevents regressions like [99dc534](https://github.com/eworthing/Tiercade/commit/99dc534), [f93d735](https://github.com/eworthing/Tiercade/commit/f93d735)):

**CSV Import (AppState+Import):**
- [ ] Preserves unique item IDs (no duplicates after import)
- [ ] Handles malformed CSV gracefully (validation errors, not crashes)
- [ ] Correctly maps columns to item attributes

**Export Formats (AppState+Export):**
- [ ] All formats include custom tiers (not just S-F defaults)
- [ ] Empty tiers are handled correctly
- [ ] Edge-case tier names (special characters, long names) export cleanly

**Cross-Platform:**
- [ ] **CRITICAL**: After UI refactors or access-level changes, build succeeds on ALL platforms:
  - `./build_install_launch.sh` (builds tvOS, iOS, iPadOS, macOS)
  - OR individually: `./build_install_launch.sh tvos`, `./build_install_launch.sh ios`, `./build_install_launch.sh ipad`, `./build_install_launch.sh macos`
- [ ] Visibility modifiers allow cross-file access within module
- [ ] Platform-specific code properly gated with `#if os(tvOS)`, `#if os(iOS)`, `#if os(macOS)`

### UI test minimalism
- Prefer existence checks and stable accessibility IDs over long remote navigation. Target < 12 s per focus path.

| Screen | ID to assert | Expectation |
| --- | --- | --- |
| Toolbar | `Toolbar_NewTierList` | Exists, isEnabled before launching wizard |
| HeadToHead overlay | `HeadToHeadOverlay_Apply` | Appears once queue empties |
| Tier Move | `TierMove_Sheet` | Presented before accepting commands |
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
4. iOS 26, macOS 26, and tvOS 26 require TLS 1.2+ by default for outbound `URLSession`/Network requests when the app links against the OS 26 SDKs; ensure remote endpoints negotiate an acceptable cipher suite or customize `NWProtocolTLS.Options` if absolutely necessary.

### Gatekeeper & UI test runner
- macOS can quarantine the native macOS UI test host, producing the dialog "`TiercadeUITests-Runner` is damaged and can't be opened." Remove the quarantine bit before rerunning UI tests:
  ```bash
  xattr -dr com.apple.quarantine ~/Library/Developer/Xcode/DerivedData/Tiercade-*/Build/Products/Debug/TiercadeUITests-Runner.app
  ```
- Repeat after DerivedData resets (the hash segment changes per build directory).

### Security & runtime checklist
- **ATS:** Keep App Transport Security enabled (default). Only add per-host exceptions with documented justification.
- **Network security:** Certificate pinning and retry policies should be documented when implemented.
