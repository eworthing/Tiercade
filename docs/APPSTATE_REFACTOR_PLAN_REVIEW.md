# AppState Refactor Plan Review

Last updated: 2025-11-03

Context: Review of the AppState decomposition work against `docs/APPSTATE_REFACTOR_PLAN.md` using the current repository state. This document captures concerns, gaps, and suggested follow-ups. It is a companion to the plan and should guide the remaining implementation.

## Alignment With Plan (Snapshot)

- PR 1 (Protocols + DI) – DONE
  - Protocols exist and are `Sendable`: `UniqueListGenerating`, `TierPersistenceStore`, `ThemeCatalogProviding`.
  - Implementations exist: `AppleIntelligenceListGenerator` (actor), `SwiftDataPersistenceStore` (actor), `BundledThemeCatalog` (MainActor class).
  - AppState initializer injects or defaults to production adapters.

- PR 2 (Extract AIGenerationState) – DONE
  - `AIGenerationState` created with `@Observable @MainActor`; chat visibility/messages/state moved.
  - Sanitization uses `PromptValidator`.
  - Placeholder FoundationModels integration; availability gated.

- PR 3 (Extract PersistenceState + OverlaysState) – PARTIAL ✔️
  - `PersistenceState` created and injected; tracks unsaved changes, recents, active handle.
  - `OverlaysState` created and used; centralized overlay routing.
  - Concern: `OverlaysState.activeOverlay` doesn’t consider `showThemeCreator`, but `OverlaysState` defines that property (focus blocking bug risk). See “Gaps & Risks”.

- PR 4 (Extract TierListState) – NOT DONE ❗
  - Tier operations (`AppState+Items.swift`) remain in AppState; `tiers/tierOrder/selection/history` still live on AppState.
  - Undo/redo and all tier mutations bypass an extracted state.

- PR 5 (Cleanup/Middleware) – NOT STARTED
  - Test/diagnostic middleware not extracted; AppState still hosts various non-production paths (better than before, but still coupled).

## Gaps & Risks

1) Missing TierListState (largest remaining refactor)
   - Impact: AppState still owns tier data and item operations (move, randomize, undo). This limits testability and keeps the monolith shape for core flows.
   - Action: Create `TierListState` and migrate `AppState+Items`, undo/redo helpers, selection, and tier metadata (labels/colors/locks). AppState coordinates and forwards calls.

2) Overlays focus blocking omission
   - `OverlaysState.activeOverlay` does not include `showThemeCreator`. `OverlaysState` has the property but the computed doesn’t return `.themeCreator` when true, so `blocksBackgroundFocus` can be false while theme creator is visible.
   - Action: Add `if showThemeCreator { return .themeCreator }` to `activeOverlay` and re-check tvOS focus.

3) Theme responsibilities split across AppState and ThemeState
   - `ThemeState.applyTheme(_:to:)` returns color mapping, but `AppState+Theme.applyCurrentTheme()` still writes to `tierColors` directly using `theme.selectedTheme`.
   - Action: Route theme application through `ThemeState.applyTheme(_:to:)` and assign the returned dictionary to `tierColors`. Keep `ThemeState` the single source of theme semantics.

4) Duplicate/competing flags between ThemeState and OverlaysState
   - `ThemeState.themeCreatorActive` and `OverlaysState.showThemeCreator` both exist. These can diverge and confuse focus gating.
   - Action: Choose one owner (prefer `OverlaysState` for presentation; `ThemeState` should not mirror UI flags). Remove or derive the other.

5) Progress state not extracted
   - Plan shows a `progress` aggregate; current `AppState+Progress` remains on AppState.
   - Action: Consider a small `ProgressState` (isLoading, message, progress double) to complete decomposition. Not critical, but consistent.

6) Undo/Redo still coupled to AppState
   - Action: Move snapshot capture and finalizeChange into `TierListState` to localize tier history. AppState can expose wrapper methods to maintain external API.

7) Test coverage for new states
   - Security tests exist; state-specific tests are missing.
   - Action: Add unit tests for:
     - `OverlaysState.activeOverlay` and `blocksBackgroundFocus` (esp. theme creator path)
     - `ThemeState.applyTheme(_:to:)` color mapping correctness
     - `PersistenceState` recents max size, markUnsaved/markSaved

8) DI: Mock implementations for tests
   - Protocols are present but repository lacks simple mocks in test target.
   - Action: Add lightweight mocks (e.g., in `TiercadeTests/Mocks/`) for injection in state tests.

9) FoundationModels adapter placeholder
   - `AppleIntelligenceListGenerator` returns empty array (placeholder) and logs.
   - Action: Track a follow-up to wire to `LanguageModelSession` when advancing AI integration.

10) Visibility and `@Observable` usage
   - New state classes are `@Observable @MainActor` as intended. Ensure all cross-file methods are `internal` for Swift Testing import and maintain strict concurrency.

## Suggested Next Steps (Ordered)

1) Fix `OverlaysState.activeOverlay` to include `showThemeCreator`; validate tvOS focus.
2) Consolidate theme application logic into `ThemeState` usage; remove duplication in `AppState+Theme`.
3) Extract `TierListState`; move item operations, selection, tier metadata, and undo/redo; update call sites.
4) (Optional) Extract `ProgressState` to complete plan parity.
5) Add mocks + unit tests for `OverlaysState`, `ThemeState`, `PersistenceState`.
6) Review remaining AppState extensions; migrate any residual responsibilities into the appropriate state or service.

## Cross-Platform & Apple Docs Notes

- Observation macro guidance supports smaller observable types for more efficient updates and cleaner architecture (see Apple’s “Migrating to Observable macro”).
- Maintain strict concurrency flags and isolation for injected services (`actor` types are appropriate for persistence and AI generators).
- Keep tvOS overlay and focus patterns per AGENTS.md; validate changes with Apple TV 4K tvOS 26 simulator.

