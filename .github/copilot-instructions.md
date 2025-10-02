````instructions
````instructions
```instructions
When the question involves Apple platforms (iOS, macOS, tvOS, visionOS) or Apple APIs (SwiftUI, UIKit, Focus, HIG), consult authoritative Apple documentation via the apple-docs MCP tools before other sources.
```

## Tiercade playbook for AI agents

### Modernization mandates (OS 26 / Swift 6)
- Target iOS/iPadOS/tvOS/macOS 26 with Swift 6 toolchains. Enable **strict concurrency = complete** (`.enableUpcomingFeature("StrictConcurrency")` + `.unsafeFlags(["-strict-concurrency=complete"])`).
- **State**: `@Observable`+`@Bindable` (never `ObservableObject`/`@Published`). Use actors/`@MainActor` for isolation.
- **UI**: SwiftUI only. `NavigationStack`/`NavigationSplitView` (no `NavigationView`). UIKit only via representables.
- **Persistence**: SwiftData (`@Model`, `@Query`) for new features. Migrate Core Data incrementally.
- **Async**: Structured concurrency (`async`/`await`, `AsyncSequence`, `AsyncStream`, `TaskGroup`). Phase out Combine.
- **Testing**: Swift Testing (`@Test`, `#expect`) for new tests. Migrate XCTest gradually.
- **Dependencies**: SwiftPM only. Use SPM traits for feature flags: `traits: [.featureFlag("offline-mode")]`
- **Lint**: `cyclomatic_complexity` warning at 8, error at 12.

**Critical migrations:** `ObservableObject`→`@Observable` | Combine→`AsyncSequence` | `NavigationView`→`NavigationStack` | Core Data→SwiftData | XCTest→Swift Testing | callbacks→`async/await` | queues→actors

### Architecture & state flow
- **Structure**: SwiftUI tvOS app; partials in `Views/{Main,Overlays,Toolbar}` composed in `MainAppView.swift`. Business logic in `TiercadeCore` (never recreate TL* aliases).
- **State**: `@MainActor @Observable AppState` (`State/AppState.swift` + extensions). Flow: View → `AppState` method → TiercadeCore → mutate `tiers`/history → UI refresh.
- **History**: Route mutations through `move(_:to:)`, `batchMove(_:to:)`, `clearTier(_:)`, `undo()`, `redo()` (auto-calls `HistoryLogic.saveSnapshot`).
- **Async ops**: Wrap with `withLoadingIndicator(message:operation:)` + `updateProgress(_:)`. Show toasts via `AppState+Toast` (`showSuccessToast`, etc.).
- **Persistence**: `AppState+Persistence.swift` (UserDefaults + async file I/O). Export via `AppState+ExportImport.exportToFormat(.text/.json/.markdown/.csv/.png/.pdf)` (tvOS excludes PDF via `#if os(tvOS)`). Import: prefer `ModelResolver.loadProject` → `resolveTiers`.

### tvOS UX & testing
- **Focus**: Overlays in `Views/Overlays/` use `.focusSection()`/`.focusable()`. Expose accessibility IDs: `Toolbar_{H2H,Randomize,Reset}`, `QuickMove_{Overlay,S,A,B,C,U,More,Cancel}`, `ActionBar_{MultiSelect,Move_S,ClearSelection}`.
- **Head-to-Head overlay**: Keep the Skip card (`H2H_Skip`) centered with the `clock.arrow.circlepath` glyph, surface the live skip counter (`H2H_SkippedCount`), default focus to the left option while a pair is active, and fall through to Finish when the queue empties. Ensure the Exit command routes through `cancelH2H(fromExitCommand:)` so the debounce window remains intact.
- **Tokens**: Use `Design/` helpers for typography/spacing/colors (no hardcoded values). Liquid Glass on chrome only.
- **Tests**: New tests use Swift Testing. UI tests: `XCUIRemote` + `-uiTest` arg; artifacts to `/tmp`. After builds, manually verify focus/dismissal in simulator.
- **Accessibility bug pattern**: NEVER add `.accessibilityIdentifier()` to parent containers with `.accessibilityElement(children: .contain)` - this overrides all child IDs. Keep IDs on leaf elements only (buttons, cards, scrollviews). Both ActionBar and TierRow were fixed by removing parent IDs.
- **UI test strategy**: Focus on existence checks (`app.buttons["ID"].exists`), element counting, and component verification. Avoid complex navigation workflows (XCUIRemote navigation is too slow, tests timeout at ~12s). Production suite: 11 tests (~2min runtime, 100% passing) covering smoke tests, accessibility validation, and component structure.

### Build & verify
- **tvOS build**: VS Code task or `xcodebuild -project Tiercade.xcodeproj -scheme Tiercade -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'`
- **Core tests**: `cd TiercadeCore && swift test`
- **Full pipeline**: `./tools/tvOS_build_and_test.sh` → `./tools/tvOS_smoketest.sh` (artifacts to `/tmp`)

### Data & patterns
- **Tier order**: `["S","A","B","C","D","F","unranked"]`. Respect `displayLabel`/`displayColorHex` overrides.
- **Items**: Use TiercadeCore `Item` (fields: name, seasonString/number, imageUrl).
- **Commits**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`). Scope when helpful: `feat(tvOS): quick move`.

### Key paths
`State/` (AppState) | `Views/` (UI) | `Design/` (tokens) | `Export/` (renderers) | `Util/` (helpers) | `TiercadeCore/Sources/` (logic) | `tools/` (scripts)

### IDE notes
SourceKit false positives ("No such module 'TiercadeCore'") are common—trust `xcodebuild`. Debug logs: `/tmp/tiercade_debug.log` via `AppState.appendDebugFile`.
````

## Tiercade playbook for AI agents
- **Architecture snapshot**: SwiftUI-only tvOS client under `Tiercade/` with modular partials (`Views/Main`, `Views/Overlays`, `Views/Toolbar`) composed in `MainAppView.swift`.
- **Shared logic**: Keep business rules in `TiercadeCore` (models + `TierLogic`/`HistoryLogic`/`HeadToHeadLogic`); never recreate TL* aliases.
- **State flow**: Views call `AppState` methods (`Tiercade/State/AppState.swift` + extensions) → TiercadeCore → mutate `tiers`/history → UI updates; always route mutations through helpers like `move`, `batchMove`, `clearTier`, and add `HistoryLogic.saveSnapshot`.
- **Observation & concurrency**: All new state is `@MainActor @Observable`; replace `ObservableObject`/`@Published` when touched. Use `async/await`, `AsyncSequence`, actors, and keep strict concurrency enabled via `.enableUpcomingFeature("StrictConcurrency")` + `-strict-concurrency=complete`.
- **Persistence & progress**: For save/load use `AppState+Persistence` (UserDefaults + file I/O). Wrap async work with `withLoadingIndicator(message:operation:)` and `updateProgress(_:)`; surface feedback via `AppState+Toast`.
- **Overlays & focus**: tvOS modals live under `Views/Overlays/` (QuickMove, QuickRank, BundledTierlistSelector). Ensure `.focusSection()`/`.focusable()` and expose accessibility IDs (`Toolbar_H2H`, `QuickMove_Overlay`, `ActionBar_MultiSelect`, etc.) so UI tests in `TiercadeUITests` stay green.
- **Design tokens**: Pull typography, spacing, and colors from `Tiercade/Design/` helpers (avoid hard-coded values); Liquid Glass chrome stays on toolbars/overlays.
- **Export/import**: Extend `AppState+ExportImport.swift` for format work. tvOS excludes PDF via `#if os(tvOS)`. Prefer `ModelResolver.loadProject` → `resolveTiers` when importing JSON.
- **Directory map**: `Tiercade/State/` (AppState + extensions), `Tiercade/Views/` (SwiftUI surfaces), `Tiercade/Export/`, `Tiercade/Util/` (focus + helpers), `TiercadeCore/Sources/` (domain logic), `tools/` (automation scripts).
- **Build & verify**: Run the VS Code task “Build tvOS Tiercade (Debug)” (`xcodebuild -project Tiercade.xcodeproj -scheme Tiercade -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'`). Core unit tests: `cd TiercadeCore && swift test`. Full pipeline + screenshots/logs: `./tools/tvOS_build_and_test.sh` → `./tools/tvOS_smoketest.sh`.
- **Manual tvOS review**: After builds, keep the Apple TV simulator open, exercise touched surfaces with Siri Remote/keyboard, and confirm overlays dismiss via the Exit button.
- **Testing direction**: New tests use Swift Testing (`@Test`, `#expect`). UI automation relies on `XCUIRemote` with the `-uiTest` launch arg; screenshots/logs land in `/tmp`.
- **Data shape contracts**: Maintain tier order `["S","A","B","C","D","F","unranked"]`, respect `displayLabel`/`displayColorHex`, and seed tiers with TiercadeCore `Item` helpers.
- **SwiftData strategy**: New persistence adopts SwiftData (`@Model`, `@Query`); migrate remaining Core Data modules gradually without expanding scope.
- **Debug aids**: `AppState.appendDebugFile` mirrors logs to `/tmp/tiercade_debug.log`. SourceKit “No such module” squiggles are common—trust `xcodebuild` output instead.
````
