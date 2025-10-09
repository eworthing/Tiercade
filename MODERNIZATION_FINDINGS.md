# Tiercade Modernization Findings & Recommendations

**Generated:** 2025-10-08
**Target:** Swift 6.2, iOS/tvOS 26+
**Codebase Size:** 68 Swift files, ~11,500 LOC

## Executive Summary

The Tiercade codebase is well-structured with good separation of concerns and modern SwiftUI patterns. However, there are significant opportunities to reduce complexity and leverage Swift 6.2 and OS 26 features, particularly around logging, async patterns, and API modernization.

**Priority Highlights:**
1. ✅ **Completed**: Migrated all logging to Swift's `Logger`
2. ✅ **Completed**: Removed `appendDebugFile` and reaffirmed snapshot-based undo
3. ✅ **Completed**: Persisted card density across sessions (stored with preferences)
4. 🟢 **Low Impact**: Continue adopting latest SwiftUI/Foundation convenience APIs where practical

---

## 1. Logging System Modernization ✅ **COMPLETED**

### What Changed (October 2025)
- All manual `print`/`NSLog` usage and ad-hoc logging Tasks were replaced with Swift's `Logger` API.
- Shared logger namespaces live alongside `AppState` (`Logger.appState`, `Logger.headToHead`, `Logger.persistence`).
- Every `AppState+*.swift` extension now emits structured logs with the appropriate level (`debug`, `info`, `error`).
- The legacy `appendDebugFile` pipeline and `/tmp/tiercade_debug.log` writer were removed entirely.

### Benefits Realised
- **Performance:** Removed 16+ fire-and-forget Tasks per session and eliminated file I/O from the hot path.
- **Observability:** Console.app and unified logging filters now work out of the box (subsystem `com.tiercade.app`).
- **Maintainability:** Log formatting is centralized; adding new categories only requires extending the `Logger` helper.

### Follow-ups
- None at this time. If we ever need persisted logs for UI automation, consider the OSLogStore APIs instead of reviving file writers.

---

## 2. Remove `appendDebugFile` Boilerplate ✅ **COMPLETED**

### What Changed
- Deleted the `appendDebugFile` helper and migrated all call sites to the unified `Logger` flow.
- Updated documentation (including this playbook and CLAUDE.md) to remove references to the legacy `/tmp/tiercade_debug.log` file.

### Impact
- **Complexity:** `AppState` shed ~50 lines of redundant file handling code.
- **Concurrency:** No more `nonisolated` async entry points or fire-and-forget Tasks for logging.
- **Reliability:** Logging failures now surface via `Logger` rather than being silently swallowed.

### Follow-ups
- None. Should persisted logs ever be required again, evaluate OSLogStore before reintroducing manual file writes.

---

## 3. Modernize Swift APIs 🟢 **LOW IMPACT**

### A. Resolve Cyclomatic Complexity Discrepancy ✅

- `.swiftlint.yml` now sets `warning: 8` / `error: 12`, matching the guidance in CLAUDE.md.
- No further action required unless we decide to tighten thresholds in the future.

### B. Task.sleep Modernization (Already Done! ✅)

**Current usage is already modern:**
```swift
// AppState+Toast.swift:16
try? await Task.sleep(for: .seconds(duration))
```

This is the Swift 6+ recommended pattern. No changes needed.

### C. Consider @Entry Macro for Design Tokens (Swift 6.2)

**Current:** Manual enum-based design tokens work well
```swift
enum Palette {
    static let bg = Color.dynamic(light: "#FFFFFF", dark: "#0B0F14")
    // ...
}
```

**Optional Enhancement:** Swift 6.2 `@Entry` macro for future extensibility
```swift
@Entry(keypath: \.palette.background)
static let background = Color.dynamic(light: "#FFFFFF", dark: "#0B0F14")
```

**Verdict:** Keep current approach. It's clean and the `@Entry` macro is best for plugin/extension systems.

### D. Leverage Swift 6.2 Typed Throws (Already Using! ✅)

**Current usage:**
```swift
// AppState+Persistence.swift:70
func save() throws(PersistenceError) { ... }
```

Excellent! Already using typed throws correctly. No changes needed.

---

## 4. SwiftUI & tvOS 26 Optimizations 🟢 **LOW IMPACT**

### A. Already Using Modern Patterns ✅

The codebase already leverages:
- ✅ `@Observable` instead of `ObservableObject`
- ✅ `@Bindable` for two-way bindings
- ✅ `NavigationStack` (not deprecated `NavigationView`)
- ✅ Structured concurrency (`async`/`await`)
- ✅ `Task.sleep(for:)` with Duration API
- ✅ `.focusSection()` for tvOS focus management
- ✅ `.allowsHitTesting(!modalActive)` instead of `.disabled()`
- ✅ Glass effects for tvOS 26 (`glassEffect`, `GlassEffectContainer`)
- ✅ Swift Testing (`@Test`, `#expect`) in TiercadeCore

### B. Potential Micro-Optimizations

**1. Reduce ZStack Complexity in MainAppView** ✅

- `MainAppView` now routes tvOS and iOS content through helper builders (`tvOSPrimaryContent`, `platformPrimaryContent`) and a shared `tierGridLayer`, keeping the core ZStack small and focused.
- The dedicated `overlayStack` continues to manage modal overlays, so z-index handling stays isolated from the primary layout logic.

**Impact:** Marginally better SwiftUI diffing, clearer structure.

**2. Consider @Previewable for PreviewProvider** (OS 26+)

Currently using `#Preview` correctly. No changes needed.

---

## 5. TiercadeCore Analysis 🟢 **EXCELLENT STATE**

### Findings

The `TiercadeCore` package is **exemplary**:
- ✅ Clean, functional logic with no side effects
- ✅ Simple, testable functions (TierLogic.swift is only 45 lines!)
- ✅ Already nonisolated by default (correct for library code)
- ✅ Proper `Sendable` conformance
- ✅ No complexity warnings

**Recommendation:** No changes needed. This is well-designed platform-agnostic code.

---

## 6. Architecture & Patterns 🟢 **STRONG**

### Strengths
1. ✅ **Excellent separation**: AppState extensions by feature
2. ✅ **View modularity**: ContentView+TierRow, ContentView+TierGrid, etc.
3. ✅ **Design tokens**: Centralized Palette/Metrics/TypeScale
4. ✅ **Proper MainActor isolation**: All UI state on @MainActor
5. ✅ **Undo pattern**: Undo/redo via UndoManager snapshots

### Minor Suggestions

**A. Consider Observation for Smaller State Slices**

**Current:** Single massive `AppState` with 50+ properties

**Alternative:** Break into focused observable objects:
```swift
@Observable final class HeadToHeadState { ... }
@Observable final class ThemeState { ... }
@Observable final class TierState { ... }

// In AppState:
let h2h: HeadToHeadState
let theme: ThemeState
let tiers: TierState
```

**Pros:** Better encapsulation, smaller recompilation units, clearer ownership
**Cons:** More boilerplate, need to pass multiple objects
**Verdict:** Current approach is fine for this app size. Consider if AppState grows >100 properties.

---

## Summary of Recommended Actions

### Recently Completed
- ✅ Replaced all manual logging with Swift `Logger` (AppState + extensions)
- ✅ Removed `appendDebugFile` and related file I/O helpers
- ✅ Updated `.swiftlint.yml` cyclomatic thresholds to 8/12

### Opportunities Ahead
1. **Investigate state slicing** (future exploration)
   - Only if the single `AppState` starts to grow beyond current scope.

---

## Metrics

### Before Modernization
- **Custom logging**: 30+ locations in State files alone
- **Fire-and-forget Tasks**: 16+ in State files
- **appendDebugFile complexity**: 50 lines
- **Manual log formatting**: 15+ unique patterns

### Current (October 2025)
- **Logger calls**: ~40 single-line statements across AppState extensions
- **Fire-and-forget Tasks**: 0
- **appendDebugFile**: Removed
- **Log formatting helpers**: 0 (handled by Logger)

### Total Impact
- **~150 lines removed**
- **~16 Task spawns eliminated**
- **Better Console.app integration**
- **Improved debugging ergonomics**

---

## Migration Priority

All previously flagged high/medium items (logging migration, appendDebugFile removal, SwiftLint alignment) were completed in October 2025. The remaining work is optional refinement (e.g. overlay composition cleanup) and can be scheduled as time permits.

---

## Files Requiring Changes

- **High Priority:** None outstanding
- **Optional:** None currently flagged

---

## Additional Notes

### What NOT to Change

1. ✅ **TiercadeCore** - Already excellent, don't touch
2. ✅ **Design tokens** - Well structured, keep as-is
3. ✅ **Task.sleep patterns** - Already modern
4. ✅ **@Observable usage** - Correct for Swift 6
5. ✅ **Focus management** - Proper tvOS patterns
6. ✅ **Async/await patterns** - Well implemented

### Swift 6.2 / OS 26 Features Already Adopted

- ✅ Typed throws (`throws(ErrorType)`)
- ✅ `@Observable` macro
- ✅ `Task.sleep(for: Duration)`
- ✅ Strict concurrency checking
- ✅ `@MainActor` isolation
- ✅ Glass effects (tvOS 26)
- ✅ `.focusSection()` (tvOS modern focus)
- ✅ Swift Testing framework

### Conclusion

This codebase is **already modern** and well-architected. The previously identified high-impact items (logging + undo improvements, overlay refactor) are complete, with only stretch ideas (like state slicing) remaining for future exploration.

**Remaining modernization effort:** Optional / as time permits
**Risk level:** Low (no structural changes pending)
**Testing impact:** None beyond standard regression checks when optional refactors occur
