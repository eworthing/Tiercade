# Tiercade Architecture & Security Review — Codebase Map, Dependencies, Data Flow, Risks (2025-11-03)

## Summary
- Scope: Map repository structure, enumerate external dependencies, trace data flow from inputs to outputs, and identify security vulnerabilities and architectural weaknesses. Includes actionable mitigations.
- Method: Static analysis of the repository combined with authoritative Apple documentation via apple-docs MCP for SwiftUI/Observation/SwiftData/tvOS focus/Liquid Glass/FoundationModels. No third‑party sources used.
- Primary platform: tvOS-first SwiftUI app; iOS/macOS parity via conditional compilation. Strict concurrency enabled across app and `TiercadeCore`.

## Repository Structure Map

### App Entry & Scenes
- `Tiercade/TiercadeApp.swift` — `@main` SwiftUI app.
  - Builds `ModelContainer` (SwiftData), initializes `@MainActor @Observable` `AppState`.
  - Hosts acceptance/AI test runners behind launch arguments; Apple Intelligence gated by `canImport(FoundationModels)` and availability checks.
  - Wires macOS commands via `TiercadeCommands`.

### State (single source of truth)
- `Tiercade/State/AppState.swift` — Central `@MainActor @Observable` state model.
- Feature extensions (non-exhaustive):
  - Items: `AppState+Items.swift` (reset/add/randomize/undo)
  - Import/Export: `AppState+Import.swift`, `AppState+Export.swift`
  - Persistence & Filesystem: `AppState+Persistence.swift`, `AppState+Persistence+FileSystem.swift`
  - Head-to-Head: `AppState+HeadToHead.swift`
  - Theme/Toast/Progress/Search/Sorting/etc.: dedicated `AppState+*.swift` files
  - AI prototype flows: `AppleIntelligence+*.swift` (platform-gated)

### Views
- Main composition: `Views/Main/*` (grid, sidebar, overlays composition, hardware focus helpers)
- Overlays: `Views/Overlays/*` (Wizard, H2H Arena, QuickMove, Sort Picker, Theme Library/Creator, AI Chat/Gen)
- Toolbar: `Views/Toolbar/*` (tvOS action bar, export formats, quick menu)
- Components: `Views/Components/*` (detail/inspector, analytics sidebar, media gallery)

### Design & Effects
- `Tiercade/Design/*` — Palette/TypeScale/Metrics/TVMetrics, TierTheme models, Liquid Glass helpers (`GlassEffects.swift`).

### Core Logic Package
- `TiercadeCore/Package.swift` — SwiftPM package (iOS/macOS/tvOS 26), strict concurrency flags enabled.
- Models & logic: `Sources/TiercadeCore/{Models,Logic,Utilities}`
- Tests: `TiercadeCore/Tests/TiercadeCoreTests/*`

### Build & Tooling
- Build script: `build_install_launch.sh` (tvOS default, also iOS/macOS; supports advanced-generation flags).
- AI test runner scripts and result analysis: `run_all_ai_tests.sh`, `analyze_test_results.py`.
- Documentation: `docs/AppleIntelligence/*`, `AGENTS.md` (engineering guardrails).

## External Dependencies (What & Why)

### Apple Frameworks
- SwiftUI — UI on all platforms.
- Observation — `@Observable`/`@Bindable` state model (Apple docs: Observation framework).
- SwiftData — `ModelContainer`/`ModelContext` for persistence.
- Accessibility — announcements, tvOS focus/accessibility behaviors.
- UniformTypeIdentifiers — export formats, media type detection.
- CoreGraphics/ImageIO — export rendering; image decoding utilities.
- AVKit (tvOS) — inline video playback in detail view.
- os.Logger — unified logging.
- FoundationModels (iOS/macOS 26+) — Apple Intelligence guided/un‑guided generation for prototype flows.

### Local Swift Package
- `TiercadeCore` — platform-agnostic models (`Item`, `Items`, `TierConfig`) and logic (`TierLogic`, `HeadToHeadLogic`, `RandomUtils`, `Sorting`). No third‑party SPM dependencies detected.

## Data Flow Overview (Inputs → State → Logic → Outputs)

### Launch & State Provisioning
- App builds `ModelContainer` and creates `AppState(modelContext:)`.
- `AppState.init` loads SwiftData-backed project if present; otherwise seeds first bundled project.

### User Actions Pipeline
- Pattern: View → `AppState` method → `TiercadeCore` logic → state mutation + `finalizeChange` (undo/telemetry) → SwiftUI refresh.

#### Examples
- Randomize
  - UI: Toolbar button invokes `app.randomize()`.
  - State: `performRandomize()` partitions locked/unlocked items, shuffles distribution into unlocked ranked tiers, writes `tiers`, records undo, shows toast.

- Move/Reorder
  - State calls `TiercadeCore.TierLogic.moveItem` / `reorderWithin`; updates `tiers`; `finalizeChange` for undo/redo.

- Head-to-Head (Matchup Arena)
  - Start: Build pool and warm-start queue via `HeadToHeadLogic.initialComparisonQueueWarmStart`, set `h2h*` session state.
  - Vote/Skip: Update records and progress, auto-advance to next pair; when queue drains, compute quick pass and optional refinement suggestions; finalize via `HeadToHeadLogic.finalizeTiers` and `finalizeChange`.

- Import
  - JSON: background decode with `ModelResolver`, apply `project` to state (`tiers`, labels/colors/locked), restore preferences; toast success.
  - CSV: background parse; write `tiers` and `finalizeChange`; toast success.

- Export
  - Text/CSV/Markdown/JSON via formatters; PNG/PDF (PDF excluded on tvOS) via `ExportRenderer`.
  - Bundle export (`*.tierproj`) writes `project.json` + media/thumbnail assets to `~/Library/Application Support/Tiercade/Projects/`.

- Persistence
  - SwiftData entity graph mirrors list state; autosave task runs every 30s when `hasUnsavedChanges` is true; explicit `save()` available.

- AI Prototype (iOS/macOS only)
  - `AppState.generateItems` creates `LanguageModelSession` and uses `FMClient` + `UniqueListCoordinator` to produce unique item strings with guided generation and retry invariants (per-attempt `RetryState` reset, telemetry).

## tvOS Focus & Liquid Glass Notes (Apple Docs)
- Focus: `.focusSection()` to boundary sections; `.focusable(interactions: .activate)` to limit interactions; `.onExitCommand` handles Menu/Escape to dismiss overlays.
- Liquid Glass: `.glassEffect(_:in:)` is tvOS/iOS/macOS 26+, use on chrome (toolbars/buttons) and avoid on large background surfaces behind focusable controls (prevents unreadable focus overlays).

## Security Findings

1) Bundle Path Traversal on Import Relocation
- Location: `AppState+Persistence+FileSystem.relocateFile(fromBundleURI:extractedAt:)` / `bundleRelativePath(from:)`.
- Issue: `file://` URIs inside `project.json` can contain `..` components (e.g., `file://../outside`). The code constructs `sourceURL = tempDirectory.appendingPathComponent(relativePath)` and copies it into Application Support without validating containment.
- Impact: Loading a malicious `.tierproj` could copy arbitrary local files (if readable) into the app’s stores (exfiltration vector).
- Mitigation:
  - Reject any `bundleRelativePath` containing `..` or absolute beginnings.
  - Resolve and validate: standardize and resolve symlinks for `sourceURL`, then ensure `resolved.path` has the `tempDirectory.resolvingSymlinksInPath().path` prefix before copying. If not, throw a typed error.

2) Unbounded Remote Image Fetch in Media Gallery
- Location: `Views/Components/MediaGalleryView` (uses `AsyncImage` directly with arbitrary URIs).
- Issue: No scheme whitelist or content-size guard; many unique URIs can cause memory/network load.
- Impact: Potential DoS/memory pressure; untrusted HTTP endpoints.
- Mitigation:
  - Accept only `https` (and optionally `file` from app-managed stores). Drop or warn on others.
  - If adopting `ImageLoader`, set `NSCache.totalCostLimit` and compute cost by pixels×bpp; set timeouts and per-host concurrency limits.

3) Arbitrary URL Open
- Location: `Util/OpenExternal.open` and `DetailView` “Play Video”.
- Issue: Opens any scheme via `NSWorkspace`/`UIApplication`.
- Impact: Potential phishing or invoking unexpected handlers (`mailto:`, custom schemes, `file://`).
- Mitigation:
  - Whitelist `https` (and known safe `http(s)` media hosts if desired). For `file://`, restrict to app-managed Application Support directories. Show a confirmation alert for non-HTTP(S) schemes.

4) Export Includes Arbitrary Local Files via `file://` URLs
- Location: `AppState+Export.makeMediaExport(from:)`.
- Issue: If items reference local `file://` paths, export bundles copy that content into the project archive.
- Impact: Unintended data disclosure if imported content includes crafted local paths.
- Mitigation:
  - Allow only app-managed media store files (or explicit user-chosen files via open panels). Reject other local paths.

5) CSV Import Deduplication & Validation Gaps
- Location: `AppState+Import.parseCSVInBackground` → `createItemFromCSVComponents`.
- Issue: IDs derived from names can collide; duplicates aren’t fully prevented across tiers.
- Impact: Inconsistent state; downstream assumptions about unique IDs may break.
- Mitigation:
  - Normalize and deduplicate IDs with a seen-set; suffix colliding IDs (`-2`, `-3`, …). Surface validation summary in a toast and return counts.

6) Network Session Defaults
- Location: `AsyncImage` and `ImageLoader` (if used later).
- Issue: Defaults for `URLSession.shared` (timeouts, cache) may be unsuitable for tvOS/iOS.
- Mitigation:
  - Provide a configured `URLSessionConfiguration` with reasonable resource/time limits and `waitsForConnectivity=false` for UI flows.

## Architectural Weaknesses
- Large `AppState` surface area
  - Good: Central orchestration via extensions, aligns with Observation+MainActor.
  - Risk: Cross-cutting responsibilities (import/export, H2H, AI, themes) in one type. Refactoring friction and harder unit testing.
  - Suggestion: Introduce internal protocols for storage/export/AI gateways and inject via `SharedCore.swift` to keep `AppState` lean while maintaining the extension pattern.

- Test runners in `TiercadeApp`
  - Suggest moving heavy runner logic behind a separate debug target or helper class and keep `@main` thin.

- Unused utilities
  - `ImageLoader` actor appears unused; either remove or wire with limits and cancellation.

- URI policy not centralized
  - Introduce a single `URIPolicy` helper that validates external opens and media loads to avoid drift across call sites.

## Recommended Mitigations (Actionable)
1) Harden bundle import relocation
```swift
// Pseudocode for containment check
let base = tempDirectory.resolvingSymlinksInPath()
let src = sourceURL.resolvingSymlinksInPath()
guard src.path.hasPrefix(base.path + "/") else {
  throw PersistenceError.fileSystemError("Invalid bundle path: \(src.path)")
}
// Also reject any relative path containing ".." in bundleRelativePath(from:)
```

2) Add URL scheme whitelist
- Helper: `isAllowedExternalURL(_:)` and `isAllowedMediaURL(_:)`.
- Enforce in `OpenExternal.open`, `DetailView`, and `MediaGalleryView`.

3) CSV import dedup + validation summary
- Track `seenIds`, normalize case; resolve collisions. Show toast with “added/skipped/duplicates” counts.

4) Image/network resource limits
- Adopt configured `URLSession` and, if using `ImageLoader`, set `totalCostLimit` and max in-flight fetches.

5) Isolate test runners
- Move runner orchestration into a debug-only service type; keep `TiercadeApp` lean.

## Apple Documentation References
- Observation: https://developer.apple.com/documentation/observation/
- SwiftUI Liquid Glass: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)/
- Focus interactions: https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)/
- Exit command: https://developer.apple.com/documentation/swiftui/view/onexitcommand(perform:)/
- SwiftData ModelContainer: https://developer.apple.com/documentation/swiftdata/modelcontainer/
- FoundationModels guided generation: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation/

## Next Steps
- I can implement:
  - Path traversal guards in `AppState+Persistence+FileSystem` with unit tests.
  - URL scheme whitelist utility and apply in `DetailView` and gallery.
  - CSV import dedup logic plus tests.
  - Optional: Extract test runners and add a small URIPolicy helper.

