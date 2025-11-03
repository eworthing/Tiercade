# Tiercade Codebase Review — 2025-11-03

This document summarizes a targeted review of the Tiercade repository with concrete, file-level recommendations. Scope covers code quality, potential bugs, performance, maintainability, and security/privacy.

## Summary
- Strong Swift 6 modernization: @Observable, @MainActor, Swift Testing, os.Logger, strict concurrency flags, and platform gating are well applied.
- Clear separation of concerns: Tiercade app vs. TiercadeCore package; views vs. state extensions; tvOS-first with platform-specific implementations.
- Key improvements: tvOS overlay glass usage, CSV duplicate handling/tests, AI debug file gating, consistent Logger usage, in-flight image request coalescing, and optional ID→tier index for hot paths.

## Code Quality & Best Practices
- Concurrency and observation
  - App state uses `@MainActor` + `@Observable` consistently (Observation best practices). Keep Xcode `-default-isolation MainActor` in sync with package `.enableUpcomingFeature("StrictConcurrency")` flags to avoid accidental UI mutations off main.
  - Consider adding brief `@available` notes where platform-constrained code compiles under conditions but isn’t available everywhere (e.g., FoundationModels paths).
- Foundation Models integration
  - Error handling aligns with Apple’s `LanguageModelSession.GenerationError` taxonomy, with special handling for `.decodingFailure` and `.exceededContextWindowSize`. Keep retry policy rationale documented near the code that adjusts seeds/tokens/temperature so future changes are easy to reason about.
  - References:
    - LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/
    - GenerationError: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/
- Unified logging
  - Replace remaining `print` usage with `os.Logger` (privacy-aware, filterable, integrates with Console):
    - `Tiercade/State/AppState+AppleIntelligence.swift` (sendMessage logging, token estimates)
    - `Tiercade/State/AppleIntelligence+UniqueListGeneration+FMClient.swift` (DEBUG logs)

## Potential Bugs & Edge Cases
- tvOS glass on overlay containers
  - AGENTS.md rule: never apply glass on backgrounds behind focused controls. Quick Rank currently applies glass to the overlay container:
    - `Tiercade/Views/Main/ContentView+Overlays.swift:216` uses `.tvGlassRounded(18)` around focusable buttons.
  - Fix: Use opaque background (e.g., `Color.black.opacity(0.85)` + stroke) to ensure system focus/keyboard overlays remain legible.
- CSV import duplicates and ID collisions
  - CSV import derives IDs from names and doesn’t check for duplicates across rows or tiers:
    - `Tiercade/State/AppState+Import.swift:38, 84`
  - Risk: Silent duplicate IDs cause inconsistencies and overwrite semantics during persistence/export.
  - Fix: Track a `Set<String>` of IDs during parsing, skip or uniquify duplicates (append numeric suffix), and surface a toast with the number of skipped/renamed entries. Add Swift Testing coverage for duplicate rows and mixed-tier duplicates.
- Unguided AI debug file writes to disk
  - Unguided path writes raw responses/parse failures to `/tmp/unguided_debug` unconditionally:
    - `Tiercade/State/AppleIntelligence+UniqueListGeneration+FMClient.swift:338, 353, 391, 416`
  - Risk: Persisting prompts/responses to disk may leak sensitive content.
  - Fix: Gate behind `#if DEBUG` and a runtime opt‑in flag; redact/scrub content as needed and prune old files.
- Undo/redo target lifecycle
  - `UndoManager` retains its target (`AppState`), which is app‑lifetime in practice. Add a short comment documenting this assumption to avoid future retain-cycle concerns when refactoring.
- Export scaling edge cases
  - Very large lists may exceed intended single-page layouts. PNG scaling clamps appropriately; consider multi‑page PDF for macOS/iOS if export needs to preserve legibility.

## Performance
- O(#tiers×N) lookups for item moves
  - `TiercadeCore/Sources/TiercadeCore/Logic/TierLogic.swift:6` scans all tiers to find an item on move. For very large projects, maintaining an optional `id → (tierName,index)` index in `AppState` (kept in sync on moves/reorders) reduces lookup to O(1). This can also accelerate `currentTier(of:)`, selection checks, and hover/focus hints.
- Image loading
  - `Tiercade/Util/ImageLoader.swift:21` uses `NSCache` without cost limits and doesn’t coalesce concurrent in-flight loads:
    - Set `cache.totalCostLimit` (e.g., several tens of MBs) and compute cost from `CGImage` dimensions/bytes-per-row.
    - Track in-flight tasks `[URL: Task<CGImage, Error>]` to dedupe concurrent requests; cancel tasks when views disappear.
    - Consider a tuned `URLSessionConfiguration` (timeouts/cache policy) and background priority for prefetch.
- Rendering/export
  - `ExportRenderer` is efficient for single-pass outputs. If used programmatically for multiple renditions, memoize section measurements or batch scalings to avoid repeat layout work.
- Head‑to‑head pairing
  - Pair generation uses Fisher–Yates over combinations; good. For pools >1–2K, consider lazy/windowed generation to cap peak memory during queue assembly.

## Readability & Maintainability
- Platform notes near usage
  - Add short doc comments where platform-specific behavior differs (e.g., glass fallbacks in `Tiercade/Design/GlassEffects.swift`, PDF gating on tvOS in `ExportRenderer`). Helps prevent future regressions.
- Centralize tier constants
  - Replace scattered literals (`"S","A","B","C","D","F","unranked"`) with a central definition/enum and canonical order. Reduces drift across import/export/UI:
    - Affects `AppState.swift`, `AppState+Export.swift`, `AppState+Import.swift`, etc.
- Consolidate AI logging helpers
  - Abstract repeated attempt logging/telemetry blocks into small helpers to reduce duplication across `UniqueListGeneration` and `+FMClient`.
- Documentation
  - Add brief docs for `.tierproj` bundle structure and media hashing (sha256 naming) to aid external tooling. A small `EXPORT.md` would help.

## Security & Privacy
- Debug artifact gating and retention
  - As above, wrap unguided debug dumps in `#if DEBUG` with runtime opt‑in, scrub data, and prune old files.
- External URL opens
  - `Tiercade/Util/OpenExternal.swift` opens arbitrary URLs. Add a scheme allowlist (`http`, `https`, `mailto`) and reject `file:`/custom schemes unless explicitly user-initiated, returning `.unsupported` with a toast.
- ATS and network usage
  - Keep ATS enabled (default). If adding remote hosts for media, document per-host exceptions and reasons. Avoid logging prompt/response bodies in release; use `.debug` level and redact.

## High‑Impact Quick Fixes
- tvOS overlay glass
  - Replace glass on Quick Rank container with opaque background: `Tiercade/Views/Main/ContentView+Overlays.swift:216`.
- CSV duplicate protection + tests
  - Add duplicate guard and a toast summarizing skipped/renamed entries; add Swift Testing for duplicates and malformed CSV quoting.
- Gate AI debug file output
  - Wrap `prepareDebugDirectory`, `saveUnguidedDebugData`, `saveParseSuccessDebug`, and parse‑fail dumps with `#if DEBUG` and a user toggle; redact content and prune files.
- Logger consistency
  - Replace remaining `print` usage in AI code paths with `Logger.*` categories.
- ImageLoader hardening
  - Add `totalCostLimit` and in‑flight coalescing to avoid duplicate downloads and unbounded memory growth.

## Nice‑to‑Have Improvements
- Maintain optional `id → tier` index in `AppState` for hot paths.
- Group `tierLabels/tierColors/lockedTiers` into a `TierMetadata` struct to clarify mutation boundaries and ease undo snapshots.
- Expand head‑to‑head tests to cover refinement frontier heuristics and churn thresholds (builds on your already strong coverage).

## References (Apple Docs)
- Foundation Models
  - LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/
  - GenerationError: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/
- Observation / @Observable
  - https://developer.apple.com/documentation/observation/observable/
  - Migration guide: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/
- Swift Testing
  - https://developer.apple.com/documentation/testing/

## Proposed Next Steps
- Implement the tvOS Quick Rank background fix and CSV duplicate guard with tests.
- Gate AI debug file output behind DEBUG + runtime toggle; replace prints with Logger.
- Add `NSCache.totalCostLimit` and in‑flight coalescing to `ImageLoader`.
- If desired, introduce a central tier constants source and optional `id → tier` index.

