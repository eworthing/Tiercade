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

## Quick Navigation

- [Apple Intelligence Prototype Scope](#apple-intelligence-prototype-scope)
- [Architecture Snapshot](#architecture-snapshot)
- [Swift 6 & Concurrency](#swift-6--concurrency)
- [Platform Strategy](#platform-strategy)
- [tvOS UX & Focus Management](#tvos-ux--focus-management)
- [Design System](#design-system)
- [Navigation Patterns](#navigation-patterns)
- [Build & Test](#build--test)
- [Linting & Formatting](#linting--formatting)
- [Tooling & Diagnostics](#tooling--diagnostics)
- [Data Contracts & Patterns](#data-contracts--patterns)
- [Debugging Notes](#debugging-notes)
- [Collaboration Norms](#collaboration-norms)

---

- Target tvOS-first SwiftUI app (iOS/iPadOS/macOS/visionOS 26+) using Swift 6 strict concurrency. Keep `.enableUpcomingFeature("StrictConcurrency")` and Xcode `-default-isolation MainActor` flags intact.

## Apple Intelligence Prototype Scope

**📚 AI Documentation Hub**: All AI-related specs, diagnostics, and testing docs → `docs/AppleIntelligence/README.md`

- Prototype-only: All Apple Intelligence list-generation, **item generation**, prompt testing, and chat integrations are for testing and evaluation. Do not ship this code path to production as-is.
- **Platform gating**: AI item generation (AIItemGeneratorOverlay) is **macOS/iOS-only** (requires FoundationModels, iOS 18.4+/macOS 15.4+). tvOS displays a platform notice and cannot invoke FoundationModels.
- Reference: See `docs/AppleIntelligence/DEEP_RESEARCH_2025-10.md` for the consolidated research plan and experiment matrix.
- Cross-domain prompts: Techniques must remain domain-agnostic. We cannot tailor prompts to specific item types because end-user requests may ask for any kind of list.
- Winning-method handoff: The final product will be re-architected using the best-performing approach discovered here. Treat current algorithms, prompts, and testers as disposable scaffolding.
- Feature-gated: Keep advanced generation behind compile-time flags and DEBUG defaults. Maintain platform gating (macOS/iOS only) and keep tvOS UI independent.
- Agent guidance: If you are an LLM modifying this repo, prefer improving test coverage, diagnostics, and documentation over deepening prototype coupling with production surfaces. Avoid migrating experimental code into main app flows.

---

## Architecture Snapshot

- `Tiercade/State/AppState.swift` is the only source of truth (`@MainActor @Observable`). Every mutation lives in `AppState+*.swift` extensions and calls TiercadeCore helpers—never mutate `tiers` or `selection` directly inside views.
- Shared logic comes from `TiercadeCore/` (`TierLogic`, `HeadToHeadLogic`, `RandomUtils`, etc.). Import the module instead of reimplementing `Items`/`TierConfig` types.
- Views are grouped by intent: `Views/Main` (tier grid / `MainAppView`), `Views/Toolbar`, `Views/Overlays`, `Views/Components`. Match existing composition when adding surfaces. **Proactive file size targets:** Keep overlays under ~400 lines, view files under ~600 lines; split helper views early to avoid reactive SwiftLint cleanup cycles (see [7f9fb84](https://github.com/eworthing/Tiercade/commit/7f9fb84), [373d731](https://github.com/eworthing/Tiercade/commit/373d731), [1837087](https://github.com/eworthing/Tiercade/commit/1837087) where files grew to 700+ lines before splitting).
- Design tokens live in `Tiercade/Design/` (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`). Reference these rather than hardcoding colors or spacing, especially for tvOS focus chrome.
- `SharedCore.swift` wires TiercadeCore + design singletons; keep dependency injection consistent with its patterns.

### Structure
- **App:** SwiftUI multi-platform app (tvOS, iOS, macOS, visionOS). Views in `Views/{Main,Overlays,Toolbar}` composed in `MainAppView.swift`
- **Core logic:** `TiercadeCore` Swift package (iOS 26+/macOS 26+/tvOS 26+) — platform-agnostic models and logic
  - Models: `Item`, `Items` (typealias for `[String: [Item]]`), `TierConfig`
  - Logic: `TierLogic`, `HeadToHeadLogic`, `RandomUtils`
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
Don't introduce separate view models for core tier logic; views bind `AppState` (via `@Bindable`) and call `AppState+*.swift` methods for all mutations.

### Persistence & Data Flow
- **Primary:** SwiftData via `ModelContainer` injected in `TiercadeApp.swift`
- **Legacy migration:** UserDefaults keys cleared on init for upgrades to SwiftData
- **Auto-save:** `AppState+Persistence.swift` handles save/load/autoSave
- **Export:** `exportToFormat(.text/.json/.markdown/.csv/.png/.pdf)` — tvOS excludes PDF via `#if os(tvOS)`
- **Import:** Use `ModelResolver.loadProject(from: data)` → `resolveTiers()` for JSON/CSV

### Typed Error Taxonomy
- `ExportError` (scoped to `AppState+Export`) — bubble to UI toast with destructive option on failure.
- `ImportError` — map validation failures to info toast; unexpected decoding issues should be rethrown for crash logging.
- `PersistenceError` — surfaced when manual save/load fails; retry after showing blocking alert.
- `AnalysisError` (future) should remain internal; analytics UI already checks `canShowAnalysis`.

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

---

## Swift 6 & Concurrency

### Strict Concurrency Guardrails
- **SwiftPM:**
  ```swift
  // Package.swift
  .target(
    name: "TiercadeCore",
    swiftSettings: [
      .swiftLanguageMode(.v6),
      .enableUpcomingFeature("StrictConcurrency"),
      .unsafeFlags(["-strict-concurrency=complete"])
    ]
  )
  ```
- **Xcode Build Settings:**
  - *Swift Compiler – Language* → **Strict Concurrency Checking** = `Complete` (`SWIFT_STRICT_CONCURRENCY=complete`)
  - *Other Swift Flags* → add `-strict-concurrency=complete` for legacy configurations.
  - *Swift Language Version* = `Swift 6`; keep **Enable Upcoming Features** consistent with the package manifest.
  These mirror Apple's Swift 6 migration notes and align with the README guardrails.

### Swift 6.2 Default Actor Isolation
Swift 6.2 introduces implicit `@MainActor` isolation for all types in a module:
- **Enable via:** Xcode build setting or `-default-isolation MainActor` flag (already enabled in Tiercade)
- **Benefit:** Reduces annotation overhead — no explicit `@MainActor` on views/models needed
- **Opt-out:** Use `nonisolated` for sync functions or `@concurrent` for background work
- **All patterns in this guide work with or without the new mode**

Reference: WWDC 2025 "Explore concurrency in SwiftUI" (Session 266)

### The `@concurrent` Attribute (Swift 6.2)
Explicitly run functions on a background thread instead of MainActor:
```swift
// Explicitly runs on background thread, not MainActor
@concurrent
func decodeImage(_ data: Data) async -> Image {
    // CPU-intensive work off main thread
    return processImage(data)
}
```
Reference: WWDC 2025 "Embracing Swift concurrency" (Session 268)

### APIs That May Run Off Main Thread
SwiftUI reserves the right to call these on background threads for performance:
- `Shape.path(in:)` — geometry calculations during animation
- `Layout` protocol methods — sizing and positioning
- `.visualEffect { }` closure — complex visual effects
- `.onGeometryChange { }` first closure (transform)

**Pattern:** Use capture lists to avoid Sendable errors:
```swift
.visualEffect { [pulse] content, _ in
    content.blur(radius: pulse ? 2 : 0)  // ✅ Captures Bool copy, not self
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

### SwiftData Background Operations
Use `@ModelActor` for thread-safe database access (iOS 17+):
```swift
@ModelActor
actor TierListActor {
    func fetchRecentLists(limit: Int = 20) throws -> [TierListDTO] {
        var descriptor = FetchDescriptor<TierListModel>()
        descriptor.sortBy = [SortDescriptor(\.lastModified, order: .reverse)]
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map(TierListDTO.init)
    }
}
```
**Pattern:** Return `Sendable` DTOs from actor, never raw `@Model` objects.

Reference: [Apple ModelActor Documentation](https://developer.apple.com/documentation/swiftdata/modelactor/)

### State & UI Expectations
- Views run on `@MainActor` data via `@Observable`/`@Bindable`; never fall back to `ObservableObject`, `@Published`, or deprecated `NavigationView`.
- Prefer structured concurrency (`async/await`, `AsyncSequence`, `TaskGroup`) plus SwiftData for new persistence flows; phase out Combine and legacy Core Data code paths.
- Use SwiftData (`ModelContext`, `@Model`) only in app targets; keep TiercadeCore free of SwiftUI/SwiftData so it stays a pure logic module.
- Add Swift Testing (`@Test`, `#expect`) coverage for new work and keep dependencies in SwiftPM.
- Keep files within lint thresholds (cyclomatic complexity warn=8, error=12) and wire multi-field forms with `.submitLabel(.next/.done)`, `.onSubmit {}`, and `@FocusState` to support keyboard navigation.

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

---

## Platform Strategy

**Platforms:** tvOS 26+ (primary) | iOS/iPadOS 26+ | macOS 26+ (native) | visionOS 26+
- Mac runs as **native macOS** app using AppKit/SwiftUI
- **Mac Catalyst removed** - Migration completed in #59 (Oct 27, 2025)
- Native AppKit APIs: NSWorkspace, NSPasteboard, NSImage
- Menu bar commands: TiercadeCommands.swift (⌘N, ⌘⇧H, ⌘A, ⌘E, ⌘I)
- tvOS remains primary focus (fundamentally different UX paradigm)

### Platform Checks
Use `#if canImport(UIKit)` / `#if canImport(AppKit)` for framework imports, and `#if os(tvOS)` / `#if os(iOS)` / `#if os(macOS)` / `#if os(visionOS)` for platform-specific behavior. See API Availability Matrix below for which APIs need gating.

### API Availability Matrix

| API | iOS | tvOS | macOS | Notes |
|-----|-----|------|-------|-------|
| `TabView .page` | ✅ | ✅ | ❌ | Use `.automatic` on macOS |
| `fullScreenCover` | ✅ | ✅ | ✅ | Available on macOS, but prefer `.sheet` for native window semantics |
| `editMode` | ✅ | ❌ | ❌ | iOS-only |
| `.topBarLeading/.topBarTrailing` | ✅ | ❌ | ❌ | Use `.principal`/`.automatic` elsewhere |
| `UIKit types` | ✅ | ✅ | ❌ | Use AppKit equivalents on macOS |
| `glassEffect` | ✅ | ✅ | ✅ | All platforms 26+ |
| `.sidebarAdaptable` TabViewStyle | ✅ | ✅ | ✅ | iOS 18+, adapts per platform |

### Native macOS Patterns
**Quick reference:** Reuse shared SwiftUI views whenever possible. macOS-specific UX (menu bar commands, hover affordances, toolbar customization) should be conditionally compiled behind `#if os(macOS)` checks.

**NavigationSplitView guardrails (macOS/iPad):**
- Always feed production content into the active detail column. `NavigationSplitView` defaults to showing the detail pane, so leaving it empty hides the toolbar and tier grid.
- Route macOS/iPad through the shared `tierGridLayer` + `ToolbarView` composition.
- Prefer the two-column initializer (`sidebar:detail:`) unless you truly need a middle content column.
- Whenever you add or rename toolbar actions on tvOS, wire the same control into the macOS/iOS toolbar and assign the shared accessibility identifier (e.g., `Toolbar_MultiSelect`). Reviews should fail if macOS or iOS loses parity with tvOS toolbar.
- Hardware keyboard parity: treat arrow keys and Escape/Return as first-class inputs. New overlays and interactive surfaces should forward tvOS `.onMoveCommand` handlers to shared directional helpers and register `.onKeyPress` equivalents for iPad and macOS.

---

## tvOS UX & Focus Management

### Focus API Reference

| API | Purpose | Platform |
|-----|---------|----------|
| `@FocusState` | Bind focusable items to state | All |
| `.focused(_:equals:)` | Connect view to focus state | All |
| `.focusSection()` | Group elements for focus traversal (critical for "shelves") | tvOS 15+, macOS 13+ |
| `.focusScope(_:)` | Namespace for default focus within a region | All |
| `.prefersDefaultFocus(_:in:)` | Set default focus in scope | All |
| `.focusable(interactions:)` | Specify focus interaction mode (`.activate`, `.edit`) | tvOS 26+ |
| `.onMoveCommand` | Handle remote/keyboard directional input | tvOS, macOS |
| `.onExitCommand` | Handle Menu/⌘ button | tvOS |
| `.onPlayPauseCommand` | Handle Play/Pause button | tvOS |

Reference: [Apple focusSection() Documentation](https://developer.apple.com/documentation/swiftui/view/focussection/)

### Focus Section Pattern
Use `.focusSection()` to keep focus within a grid during horizontal movement:
```swift
LazyVGrid(columns: columns, spacing: 40) {
    ForEach(items) { item in
        ItemCard(item: item)
            .focusable()
            .focused($focusedID, equals: item.id)
    }
}
.focusSection()  // Keep focus within grid as user moves horizontally
.onAppear {
    if focusedID == nil { focusedID = items.first?.id }
}
```

### Modal vs Transient Overlays

**Modal overlays** (ThemePicker, TierListBrowser, HeadToHead, Analytics, TierMove) use `.fullScreenCover()` which provides **automatic focus containment** via separate presentation context. This is Apple's recommended pattern for modal presentations that must trap focus.

**Transient overlays** (QuickRank) remain as ZStack overlays using `.focusSection()` and `.focusable()`. For these, keep background content interactive by toggling `.allowsHitTesting(!overlayActive)`—never `.disabled()`.

**Critical**: `.allowsHitTesting()` only blocks pointer interactions (taps/clicks), **not focus navigation**. For true focus containment, use `.fullScreenCover()` or `.sheet()` presentation modifiers.

**Decision tree:**
- ✅ Use `.fullScreenCover()` when: user must complete/cancel, focus must be contained, background not interactive
- ✅ Use ZStack + `.focusSection()` when: contextual info only, lightweight, focus containment not required

**If unsure:** Default to `.fullScreenCover()` - it's easier to relax to transient than to fix focus escape bugs later.

### Default Focus Pattern
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

### Remote & Keyboard Input
Use command modifiers for remote/keyboard directional and action input:
```swift
ContentView()
    .onMoveCommand { direction in
        switch direction {
        case .left:  model.moveSelectionLeft()
        case .right: model.moveSelectionRight()
        case .up:    model.moveSelectionUp()
        case .down:  model.moveSelectionDown()
        @unknown default: break
        }
    }
    .onPlayPauseCommand { model.togglePlayback() }
    .onExitCommand { model.handleBack() }
```

### ⚠️ Focus Anti-Pattern: Manual Focus Reset Loops

Never cache a `lastFocus` value or set focus back when it becomes `nil`. Use modal presentations (`.fullScreenCover()`/`.sheet()`) for containment, `.focusSection()` for guidance, and custom routing only to move focus predictably within complex grids.

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
- **Correct fix:** use modal presentation, declare a `@FocusState` default, and use helper methods to route arrows INSIDE the overlay rather than forcing focus back to a stored value.

### Legitimate Custom Routing
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

### Checklist for Any New Overlay

- [ ] Uses `.fullScreenCover()` (tvOS/iOS) or `.sheet()` (macOS) whenever focus must be contained
- [ ] **Does NOT** use `lastFocus`, `suppressFocusReset`, or manual focus reassignment
- [ ] `.onExitCommand` routes to the overlay's cancel method
- [ ] Accessibility IDs follow `{Component}_{Action}` on leaf elements
- [ ] Glass effects stay on chrome, content areas use opaque backgrounds
- [ ] Focus ring/halo is visible in the tvOS 26 Apple TV 4K (3rd gen) simulator
- [ ] Full hardware sweep with Siri Remote / keyboard arrows shows predictable directional routing
- [ ] Builds succeed on all platforms via `./build_install_launch.sh`
- [ ] Platform-specific behaviour is gated with `#if os(...)`

### Accessibility
- **Overlay Accessibility Pattern**: When adding new overlays for iOS/macOS, use `AccessibilityBridgeView` to ensure immediate accessibility tree presence. See `Tiercade/Views/OVERLAY_ACCESSIBILITY_PATTERN.md` for full pattern documentation.
- Accessibility IDs must follow `{Component}_{Action}` on leaf elements (e.g. `Toolbar_HeadToHead`, `TierMove_Sheet`). Avoid placing IDs on containers using `.accessibilityElement(children: .contain)`.
- **Key IDs:** `Toolbar_NewTierList`, `Toolbar_HeadToHead`, `Toolbar_Analysis`, `Toolbar_Themes`, `ActionBar_MoveBatch`, `TierMove_Sheet`, `HeadToHeadOverlay_Apply`, `AIGenerator_Overlay`.

**Critical bug pattern:** NEVER add `.accessibilityIdentifier()` to parent containers with `.accessibilityElement(children: .contain)` — this overrides all child IDs. Apply to leaf elements only.

---

## Design System

### Design Tokens
**Use `Design/` helpers exclusively** — no hardcoded values
- Colors: `Palette.primary`, `Palette.text`, `Palette.brand`
- Typography: `TypeScale.*` for every text surface; apply `TypeScale.IconScale` to SF Symbols
- Layout: Prefer `ScaledDimensions` with `@ScaledMetric(relativeTo:)` for Dynamic Type
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`

**Tier Colors (state-driven):**
- Tiers support custom names, custom ordering, and variable counts (not just SABCDF)
- **Always** use `Palette.tierColor(tierId, from: app.tierColors)` to respect theme customization
- Avoid hardcoded tier lookups (`Palette.tierS`) or static tier IDs ("S", "A", etc.)

### Liquid Glass APIs (Complete Reference)

**Core modifiers:**
- [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)) — apply glass to a shape behind content
- [`glassBackgroundEffect(in:displayMode:)`](https://developer.apple.com/documentation/swiftui/view/glassbackgroundeffect(in:displaymode:)) — fill background with glass and rounded rect
- [`GlassEffectContainer`](https://developer.apple.com/documentation/swiftui/glasseffectcontainer) — share sampling across multiple glass elements, enable morphing
- [`.buttonStyle(.glass)`](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass) / [`.glassProminent`](https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle) — glass button styles

**Morphing & transitions:**
- [`glassEffectID(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)) — coordinate morph transitions between glass elements
- [`glassEffectUnion(id:namespace:)`](https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)) — combine multiple views into one glass shape
- [`GlassEffectTransition`](https://developer.apple.com/documentation/swiftui/glasseffecttransition) — `.matchedGeometry` (default) or `.materialize`

**Interactive glass (iOS 26+):**
```swift
.glassEffect(.regular, in: Capsule())
    .interactive(true)  // React to touch/pointer like standard controls
```

**Glass container example:**
```swift
@Namespace private var glassNS

GlassEffectContainer {
    HStack(spacing: 16) {
        ForEach(tabs, id: \.self) { tab in
            Button(tab.title) { selected = tab }
                .glassEffect(.regular, in: Capsule())
                .glassEffectID(tab.id, in: glassNS)  // Enables morphing
        }
    }
}
```

Reference: [Apple Liquid Glass Documentation](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

### Liquid Glass Platform Matrix
- **tvOS 26+**: Use `glassEffect(_:in:)` with focus-safe spacing
- **iOS · iPadOS · macOS 26+**: Same APIs, also supports `interactive()`
- **Fallback**: `.ultraThinMaterial` / `.thinMaterial` for older OS

```swift
@ViewBuilder func GlassContainer<S: Shape, V: View>(_ shape: S, @ViewBuilder _ content: () -> V) -> some View {
    if #available(iOS 26.0, tvOS 26.0, macOS 26.0, *) {
        content().glassEffect(.regular, in: shape)
    } else {
        content().background(.ultraThinMaterial, in: shape)
    }
}
```

### ⚠️ Glass Effects and Focus Overlays

Keep glass on chrome, never behind focusable content—tvOS focus overlays turn unreadable when layered over translucent backgrounds.

```swift
// ✅ CORRECT
VStack {
  HStack { /* toolbar buttons */ }
    .glassEffect(.regular, in: Rectangle())  // chrome only

  TextField("Name", text: $name)
    .padding(12)
    .background(Color.black.opacity(0.7))    // solid background
}

// ❌ DON'T
VStack {
  TextField("Name", text: $name)
}
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))  // focus overlay unreadable
```

**Best practices:**
- ✅ Apply glass to toolbars, headers, and buttons only
- ✅ Keep content sections on opaque fills with subtle strokes for separation
- ✅ Leave `.focusEffectDisabled(false)` on text fields so system halo stays visible
- ✅ Never stack glass over glass — use `GlassEffectContainer` to group

### Accessibility Considerations
Respect user preferences for transparency and motion:
```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.background(reduceTransparency ? Color.secondary : .ultraThinMaterial)
.animation(reduceMotion ? nil : .smooth, value: isExpanded)
```

### Animation Presets
Use modern spring presets instead of custom durations:
```swift
withAnimation(.smooth) { }   // No bounce, clean transitions
withAnimation(.snappy) { }   // Small bounce, responsive feel
withAnimation(.bouncy) { }   // Playful, more bounce

// Customizable variants
withAnimation(.smooth(duration: 0.3, extraBounce: 0.1)) { }
```

**Phase & Keyframe animators** (for complex sequences):
```swift
Circle()
    .phaseAnimator([false, true]) { content, phase in
        content
            .scaleEffect(phase ? 1.3 : 1.0)
            .opacity(phase ? 0.4 : 1.0)
    } animation: { _ in
        .easeInOut(duration: 0.8).repeatForever()
    }
```

Reference: [Apple Animation Documentation](https://developer.apple.com/documentation/swiftui/animation/)

---

## Navigation Patterns

### TabView Patterns (iOS 18+)

**Sidebar adaptable style** (iPad/Mac):
```swift
TabView(selection: $selectedTab) {
    Tab("Home", systemImage: "house", value: .home) { HomeView() }
    Tab("Library", systemImage: "square.stack", value: .library) { LibraryView() }
}
.tabViewStyle(.sidebarAdaptable)  // Adapts per platform
```

**Search tab with TabRole**:
```swift
Tab(role: .search) {
    NavigationStack {
        SearchResultsView(query: searchText)
            .searchable(text: $searchText, prompt: "Search library")
    }
}
```

**Tab bar minimize on scroll** (iOS 26+):
```swift
TabView { ... }
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
        NowPlayingBar()  // Persistent above tab bar
    }
```

Reference: [TabBarMinimizeBehavior](https://developer.apple.com/documentation/swiftui/tabbarminimizebehavior), [TabRole](https://developer.apple.com/documentation/swiftui/tabrole/)

### Adaptive Layout with ViewThatFits
Prefer `ViewThatFits` over complex `GeometryReader` logic:
```swift
ViewThatFits {
    WidePlaybackControls()   // Try this first
    CompactPlaybackControls() // Fallback if doesn't fit
}
```

Reference: [Apple ViewThatFits Documentation](https://developer.apple.com/documentation/swiftui/viewthatfits/)

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

---

## Build & Test

> **DerivedData location:** Xcode and the build script always emit products to `~/Library/Developer/Xcode/DerivedData/`. Nothing lands in `./build/`, so upload artifacts and inspect logs from DerivedData when debugging.

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
./build_install_launch.sh tvos   # tvOS only
./build_install_launch.sh ios    # iOS only (iPhone)
./build_install_launch.sh ipad   # iPadOS only (iPad)
./build_install_launch.sh macos  # Native macOS only

# Manual tvOS build (low-level)
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' build
```

### Test Commands
TiercadeCore owns package tests. Run `swift test` inside `TiercadeCore/` (Swift Testing). UI automation stays lean—see UI test minimalism below.

```bash
cd TiercadeCore
swift test --enable-code-coverage
xcrun llvm-cov report \
  --instr-profile .build/debug/codecov/default.profdata \
  .build/debug/TiercadeCorePackageTests.xctest/Contents/MacOS/TiercadeCorePackageTests
```

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
- [ ] **CRITICAL**: After UI refactors or access-level changes, build succeeds on ALL platforms
- [ ] Visibility modifiers allow cross-file access within module
- [ ] Platform-specific code properly gated with `#if os(...)`

### UI Test Strategy
- **Framework:** Use minimal UI tests only when necessary. Prefer existence checks and direct access via accessibility identifiers.
- **Launch arg:** `-uiTest` can enable test-only hooks in the app when needed.
- **Focus:** Existence checks (`app.buttons["ID"].exists`), element counts, simple component verification.
- **Avoid:** Complex remote navigation; long paths cause timeouts. Target < 12 s per focus path.

| Screen | ID to assert | Expectation |
| --- | --- | --- |
| Toolbar | `Toolbar_NewTierList` | Exists, isEnabled before launching wizard |
| HeadToHead overlay | `HeadToHeadOverlay_Apply` | Appears once queue empties |
| Tier Move | `TierMove_Sheet` | Presented before accepting commands |
| Batch bar | `ActionBar_MoveBatch` | Visible only when selection count > 0 |
| Analytics | `Toolbar_Analysis` | Toggles analytics sidebar |

### Manual Verification
- Validate visuals in the latest tvOS 26 Apple TV 4K (3rd gen) simulator; that environment mirrors the focus halos and Liquid Glass chrome we care about.
- After builds: Keep simulator open, test focus/dismissal with Siri Remote simulator (or Mac keyboard arrows/Space/ESC)
- Manual focus sweep: cycle focus with remote/arrow keys to confirm overlays and default focus behave. Capture issues with `/tmp/tiercade_debug.log`.

---

## Linting & Formatting

This project uses **SwiftFormat** and **SwiftLint** with a clear separation of responsibilities, optimized for LLM-assisted development.

### Tool Responsibilities

| Tool | Owns | Config File |
|------|------|-------------|
| **SwiftFormat** | Layout, whitespace, wrapping, punctuation, code organization | `.swiftformat` |
| **SwiftLint** | Semantics, safety, correctness, complexity metrics, custom rules | `.swiftlint.yml` |

**Key principle:** SwiftFormat handles *how code looks*, SwiftLint handles *what code does*. SwiftLint's style rules are disabled to avoid conflicts.

### LLM-Oriented Design Rationale

The configuration prioritizes patterns that make LLM-generated code safer and easier to review:

**Vertical formatting** (`--wraparguments before-first`, `--wrapparameters before-first`):
```swift
// ✅ LLM-friendly: each parameter on its own line
func configure(
    title: String,
    subtitle: String,
    isEnabled: Bool,
) {
    // ...
}

// ❌ Horizontal: harder to diff, easy to miss changes
func configure(title: String, subtitle: String, isEnabled: Bool) {
```
- One parameter per line = cleaner git diffs
- LLMs can add/remove parameters without reformatting entire signature
- Easier to spot missing or extra parameters in review

**Trailing commas** (`--trailing-commas always`):
```swift
// ✅ Adding a new case only changes one line
enum State {
    case loading,
    case success,
    case error,  // ← trailing comma
}

// ❌ Without trailing comma, adding requires modifying previous line
enum State {
    case loading,
    case success,
    case error  // ← no comma, next addition touches this line too
}
```
- Reduces noise in diffs when appending items
- Prevents common LLM mistake of forgetting commas

**Explicit self** (`--self init-only`):
- Removes redundant `self.` in most contexts for cleaner code
- Keeps `self.` in initializers where it disambiguates parameters from properties
- **Exception:** Swift 6 strict concurrency requires explicit `self.` in `@autoclosure` contexts (see below)

**Code organization** (`--enable organizeDeclarations`, `--enable markTypes`):
- Auto-generates `// MARK: -` sections by visibility (Lifecycle, Internal, Private)
- Consistent structure helps LLMs understand and extend existing types
- Only triggers on types exceeding thresholds (struct: 40, class: 50, enum: 30 lines)

### Swift 6 Strict Concurrency Gotchas

**Logger `@autoclosure` requires explicit `self.`:**

Swift 6 strict concurrency requires explicit `self.` when capturing properties in `@autoclosure` contexts. This conflicts with SwiftFormat's `redundantSelf` rule.

```swift
// ❌ BUILD ERROR: Swift 6 strict concurrency
Logger.app.debug("Count: \(items.count)")  // 'items' needs 'self.'

// ✅ CORRECT: explicit self required
// swiftformat:disable redundantSelf - Swift 6 requires explicit self in @autoclosure
Logger.app.debug("Count: \(self.items.count)")
// swiftformat:enable redundantSelf
```

**When to use disable comments:**
- Single-line Logger calls: `// swiftformat:disable:next redundantSelf`
- Multi-line Logger calls: Use block disable/enable pair
- This is the **only** case where SwiftFormat disable comments are needed

**Files with known `self.` requirements:**
- `AppState+HeadToHead.swift` - Logger calls with `self.headToHead.*`
- `AIGenerationState.swift` - Logger calls with `self.messages`, `self.estimatedTokenCount`
- `ProgressState.swift` - Logger calls with `self.operationProgress`

### Running the Tools

**SwiftFormat:**
```bash
# Check what would change (no modifications)
swiftformat . --lint

# Apply formatting
swiftformat .

# Format specific file
swiftformat Tiercade/State/AppState.swift
```

**SwiftLint:**
```bash
# Run linter (warnings + errors)
swiftlint lint

# Run with quiet mode (errors only in output)
swiftlint lint --quiet

# Auto-fix what can be fixed
swiftlint lint --fix

# Analyze (slower, catches unused code)
swiftlint analyze
```

**Pre-commit verification:**
```bash
# Ensure both pass before committing
swiftformat . --lint && swiftlint lint --quiet
```

### Automated Enforcement (LLM-First)

This project is edited exclusively by LLM agents. Formatting runs automatically at multiple points:

**Claude Code PostToolUse hook** (`.claude/settings.json`):
- Runs SwiftFormat + SwiftLint `--fix` immediately after every `Edit` or `Write` on Swift files
- No delay - file is formatted and auto-fixed the moment it's modified
- Configured in `.claude/hooks/format-swift.sh`

**Build script integration** (`./build_install_launch.sh`):
- Runs SwiftFormat on entire codebase before building
- Checks SwiftLint for errors (blocks build if found)
- Final checkpoint before compilation

**Git pre-commit hook** (`.git/hooks/pre-commit`):
- Auto-formats staged Swift files with SwiftFormat
- Blocks commit if SwiftLint finds errors
- Safety net before code enters version control

**To reinstall hooks after cloning:**
```bash
./scripts/install-hooks.sh
```

**To bypass hook temporarily** (use sparingly):
```bash
git commit --no-verify -m "message"
```

### SwiftLint Rule Categories

**Safety rules** (opt-in, prevent crashes):
- `force_unwrapping`, `force_cast`, `force_try` - crash risks
- `unhandled_throwing_task` - Swift 6 concurrency safety
- `weak_delegate`, `unowned_variable_capture` - retain cycle prevention

**Accessibility rules** (opt-in):
- `accessibility_label_for_image` - images need labels
- `accessibility_trait_for_button` - buttons need traits

**Performance rules** (opt-in):
- `empty_count`, `first_where`, `contains_over_filter_count` - O(n) vs O(1)
- `reduce_into` - avoid unnecessary copies

**Complexity metrics** (LLM-friendly thresholds):
| Metric | Warning | Error | Rationale |
|--------|---------|-------|-----------|
| `cyclomatic_complexity` | 10 | 15 | Keep functions focused |
| `function_body_length` | 50 | 80 | Fits in LLM context window |
| `file_length` | 600 | 800 | Manageable review units |
| `line_length` | 120 | 180 | Readable without scrolling |

**Custom rules** (LLM mistake prevention):
- `no_print_statements` - Use Logger instead (excluded in test/debug paths)
- `avoid_force_unwrap_after_await` - Async results need safe unwrapping
- `task_self_capture` - Verify actor isolation in Task closures
- `prefer_mainactor_over_dispatch` - Use Swift Concurrency, not GCD

### Disabled Rules (SwiftFormat Handles)

These SwiftLint rules are disabled because SwiftFormat owns formatting:
- All whitespace rules (`trailing_whitespace`, `vertical_whitespace`, etc.)
- All punctuation rules (`colon`, `comma`, `trailing_comma`, etc.)
- All brace/indentation rules (`opening_brace`, `closing_brace`, etc.)
- Multiline rules (`multiline_arguments`, `multiline_parameters`, etc.)

### Adding New Disable Comments

When you need to disable a rule, use the most targeted approach:

```swift
// Single line - disable:next
// swiftlint:disable:next force_unwrapping
let value = dictionary["key"]!

// Block - disable/enable pair
// swiftlint:disable force_cast
let views = subviews as! [CustomView]
let buttons = buttons as! [CustomButton]
// swiftlint:enable force_cast

// File-level (use sparingly, at top of file)
// swiftlint:disable file_length
```

**Always include a reason:**
```swift
// swiftlint:disable:next force_unwrapping - Guaranteed by precondition above
// swiftformat:disable redundantSelf - Swift 6 requires explicit self in @autoclosure
```

---

## Tooling & Diagnostics

- Asset refresh: manage bundled artwork directly in `Tiercade/Assets.xcassets` and keep paths aligned with `AppState+BundledProjects`.
- Debug logging: `AppState.appendDebugFile` writes to `/tmp/tiercade_debug.log`; the CI pipeline emits `tiercade_build_and_test.log` plus before/after screenshots under `pipeline-artifacts/`. Attach those files when filing issues.
- **Build script feature flags**: `./build_install_launch.sh --enable-advanced-generation` (all platforms) or `./build_install_launch.sh macos --enable-advanced-generation` (single platform) - see `docs/AppleIntelligence/FEATURE_FLAG_USAGE.md`
- **AI test runner**: `./run_all_ai_tests.sh` with result analysis via `python3 analyze_test_results.py results/run-<TIMESTAMP>/`
  - Test suite configs: `Tiercade/TestConfigs/TestSuites.json`
  - Framework docs: `Tiercade/TestConfigs/TESTING_FRAMEWORK.md`
- SourceKit often flags "No such module 'TiercadeCore'"; defer to `xcodebuild` results before debugging module wiring.
- SwiftUI previews: use `PreviewHelpers.makeAppState` and static fixtures so views in `Views/Components` and `Views/Overlays` compile and render in isolation without wiring the full app.

---

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

---

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
| `docs/HeadToHead` | HeadToHead algorithm docs, telemetry specs | Reference for algorithm validation |
| `docs/AppleIntelligence` | AI feature specs, test framework | Prototype testing documentation |
| `TiercadeTests/SecurityTests` | OWASP-class security validation | Security test coverage |

---

## Debugging Notes

### Common Issues
1. **Build fails:** Check TiercadeCore is added as local package dependency
2. **UI test timeouts:** Reduce navigation complexity, use direct element access
3. **Focus loss:** Verify `.focusSection()` boundaries, check accessibility ID placement
4. iOS 26, macOS 26, and tvOS 26 require TLS 1.2+ by default for outbound `URLSession`/Network requests when the app links against the OS 26 SDKs; ensure remote endpoints negotiate an acceptable cipher suite or customize `NWProtocolTLS.Options` if absolutely necessary.

### Gatekeeper & UI Test Runner
- macOS can quarantine the native macOS UI test host, producing the dialog "`TiercadeUITests-Runner` is damaged and can't be opened." Remove the quarantine bit before rerunning UI tests:
  ```bash
  xattr -dr com.apple.quarantine ~/Library/Developer/Xcode/DerivedData/Tiercade-*/Build/Products/Debug/TiercadeUITests-Runner.app
  ```
- Repeat after DerivedData resets (the hash segment changes per build directory).

### Security & Runtime Checklist
- **ATS:** Keep App Transport Security enabled (default). Only add per-host exceptions with documented justification.
- **Network security:** Certificate pinning and retry policies should be documented when implemented.

---

## Collaboration Norms

- Use Conventional Commits with scopes (e.g. `feat(tvOS):`, `fix(core):`).
- Prefer Swift Testing (`@Test`, `#expect`) for new coverage; legacy XCTest lives beside new tests until migrated.
