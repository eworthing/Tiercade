## Modularization Plan: Move shared logic into TiercadeCore

Goal: Move non-UI, pure logic and model code from the `Tiercade` app target into the `TiercadeCore` Swift package. This will centralize data models and business logic, simplify testing, and make the app layer focused on UI.

Quick checklist
- Identify files to move
  - HistoryLogic.swift -> TiercadeCore (already exists)
  - Models.swift -> TiercadeCore (already exists)
  - TierLogic.swift -> TiercadeCore
  - QuickRankLogic.swift -> TiercadeCore
  - HeadToHeadLogic.swift -> TiercadeCore
  - ExportFormatter / Export logic -> TiercadeCore (export helpers that are pure functions)
  - ModelResolver helpers that parse project files -> TiercadeCore
  - Any helpers that are fully pure and not UI-dependent

- API compatibility
  - Keep public types stable: `Item`, `Items`, `History<T>`, and `HistoryLogic` functions.
  - Add convenience initializers in `TiercadeCore` if needed to accept legacy attribute bags.
  - Provide `@available` or deprecated shims in the app if names change.

- Migration steps (safe order)
  1. Add tests for existing `TiercadeCore` APIs (history, models). Ensure package tests pass.
  2. Move one small logic file (e.g., `TierLogic.swift`) into `TiercadeCore` and update `Tiercade` target to depend on the product. Run full Xcode build and package tests.
  3. Move other logic files incrementally, one at a time, and run builds/tests after each move.
  4. Remove duplicate code in the app and add compatibility shims if needed.

- Tests & CI
  - Add unit tests for HistoryLogic (undo/redo/save snapshot/init) and TierLogic behaviors.
  - Update CI workflow to run `swift test` for `TiercadeCore` and `xcodebuild` for the app.

- Cleanup
  - Decide whether to keep the top-level `Package.swift` used for LSP indexing. If kept, document it in README.
  - Remove any app-only helper code left behind.

Notes
- Work incrementally; keep the app runnable and tests green at each step.
- Prefer public, versioned APIs in `TiercadeCore` and keep breaking changes behind the `feat/modularize` branch.
