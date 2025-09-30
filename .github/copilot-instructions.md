````instructions
```instructions
When the question involves Apple platforms (iOS, macOS, tvOS, visionOS) or Apple APIs (SwiftUI, UIKit, Focus, HIG), consult the apple-docs MCP tools first. Use them to search/fetch authoritative Apple documentation before other sources.
```

## Tiercade guidance for AI coding agents

- Development practices
  - Commit style: Use Conventional Commits (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`)
  - Write concise, present-tense commit messages. Include scope when helpful (e.g., `feat(tvOS): quick move overlay`)
  - Keep views platform-agnostic; use `#if os(...)` for platform specifics
  - Build and test before committing: `swift test` in TiercadeCore, build for simulators
  - Avoid committing build artifacts, DerivedData, or .DS_Store files

- Targets and stack
  - SwiftUI app; shared logic in `TiercadeCore` (Swift Package). This branch focuses on tvOS.
  - Central UI state: `@MainActor` `AppState` (`Tiercade/AppState.swift`). Use Swift 6 concurrency.
  - Use canonical `TiercadeCore` models/APIs (`Item`, `Items`, `TierLogic`, `HistoryLogic`, `HeadToHeadLogic`). Don’t reintroduce legacy TL* aliases.

- Architecture and flow
  - Views are modular partials (e.g., `ContentView+Toolbar.swift`, `ContentView+TierGrid.swift`) composed in `MainAppView.swift`.
  - Flow: View → `AppState` method → TiercadeCore logic → mutate `tiers`/history → UI refresh.
  - tvOS uses overlays/bars: `TVToolbarView`, `TVActionBar`, `QuickMoveOverlay` with `.focusSection()`/`.focusable()`.

- State, history, progress
  - Mutate tiers via `AppState` helpers to preserve history and UX: `move`, `batchMove`, `clearTier`, `undo/redo` (call `HistoryLogic.saveSnapshot`).
  - Wrap async work with `withLoadingIndicator(message:operation:)`; update via `updateProgress(_:)` (drives `ProgressIndicatorView`).
  - Toasts: `AppState+Toast.swift` (`showSuccessToast`, `showErrorToast`, etc.).
  - Persistence (`AppState+Persistence.swift`): `save`/`load` (UserDefaults) and `saveToFile`/`loadFromFile` (+ async) with legacy JSON fallbacks.

- Export/import
  - `AppState+ExportImport.swift` implements `exportToFormat(.text/.json/.markdown/.csv/.png/.pdf)`; tvOS excludes PDF via `#if os(tvOS)`.
  - JSON import prefers `ModelResolver.loadProject` + `resolveTiers`, falls back to legacy flat JSON.

- tvOS UX and testing
  - Stable accessibility identifiers are required. Examples used in tests:
    - Toolbar: `Toolbar_H2H`, `Toolbar_Randomize`, `Toolbar_Reset`
    - Quick Move: `QuickMove_Overlay`, `QuickMove_S/A/B/C/U`, `QuickMove_More`, `QuickMove_Cancel`
    - Action bar: `ActionBar`, `ActionBar_MultiSelect`, `ActionBar_Move_S`, `ActionBar_ClearSelection`
  - UI tests (`TiercadeUITests/SmokeTests.swift`): launch with `-uiTest`, use `XCUIRemote` (not `.tap()`), write screenshots to `/tmp/tiercade_ui_before.png` and `_after.png`; assert overlays/buttons by accessibility id (e.g., `QuickRank_Overlay` or `H2H_Finish`).
  - Debug logging mirrored to `/tmp/tiercade_debug.log` and Documents via `AppState.appendDebugFile` (scripts collect this).

- Build/run and scripts
  - VS Code task: “Build tvOS Tiercade (Debug)” runs `xcodebuild -project Tiercade.xcodeproj -scheme Tiercade -destination 'platform=tvOS Simulator,…'`.
  - Full tvOS automation: `tools/tvOS_build_and_test.sh` (build + focused UI test) → `tools/tvOS_smoketest.sh` (screenshots/logs under `/tmp`); scripts auto-detect `.app` and `CFBundleIdentifier` (fallback `eworthing.Tiercade`).

- Project patterns
  - Maintain `tierOrder` keys: "S","A","B","C","D","F","unranked". Use `displayLabel`/`displayColorHex` for UI-only overrides.
  - New async features should use `withLoadingIndicator` + progress + toasts; ensure history snapshots on state changes.
  - For migrations, construct `Item` with canonical fields (name, seasonString/number, imageUrl, etc.); see `AppState.normalizedTiers(from:)`.

- Pointers
  - App state and features: `Tiercade/AppState.swift` (+ `AppState+*.swift`).
  - tvOS composition/bars/overlays: `Tiercade/Views/MainAppView.swift`, `TVActionBar.swift`, `QuickMoveOverlay.swift`.
  - Toolbar/actions and platform sheets: `Tiercade/Views/ContentView+Toolbar.swift`.
  - Core package docs: `TiercadeCore/README.md`; tvOS test/CI: `tools/README.md` and scripts in `tools/`.

- SourceKit & IDE troubleshooting
  - The IDE may show "No such module 'TiercadeCore'" or "Cannot find 'Metrics/Palette/TypeScale'" errors—these are **SourceKit false positives**. If `xcodebuild` succeeds, ignore red squiggles.
  - After restructures, close old file tabs and reopen from new locations (e.g., `State/AppState.swift`, `Views/Main/ContentView+*.swift`).
  - Workarounds: Clean Build Folder (⇧⌘K), restart Swift Language Server, or trust terminal builds over IDE diagnostics.

Questions or gaps? If simulator targets, scheme names, or expected accessibility IDs are unclear, ask to confirm before large refactors.
