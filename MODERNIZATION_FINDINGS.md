# Tiercade Modernization Findings & Recommendations

**Generated:** 2025-10-08
**Target:** Swift 6.2, iOS/tvOS 26+
**Codebase Size:** 68 Swift files, ~11,500 LOC

## Executive Summary

The Tiercade codebase is well-structured with good separation of concerns and modern SwiftUI patterns. However, there are significant opportunities to reduce complexity and leverage Swift 6.2 and OS 26 features, particularly around logging, async patterns, and API modernization.

**Priority Areas:**
1. 🔴 **High Impact**: Replace manual logging system with Swift's Logger
2. 🟡 **Medium Impact**: Simplify AppState.appendDebugFile complexity
3. 🟢 **Low Impact**: Update to latest SwiftUI/Foundation APIs
4. 🔵 **Documentation**: Fix cyclomatic_complexity discrepancy

---

## 1. Logging System Modernization 🔴 **HIGH PRIORITY**

### Current State
- **30+ manual print/NSLog statements** in State files alone
- **16+ fire-and-forget Task spawns** for async logging (`Task { await appendDebugFile(...) }`)
- Custom `appendDebugFile` method duplicates file writing logic across /tmp and Documents
- Repetitive logging patterns throughout all AppState extensions

### Problems
1. **Performance**: Every log creates a new unstructured Task
2. **Complexity**: 50+ lines in `appendDebugFile` with duplicate code
3. **Maintainability**: Changing log format requires updates in 30+ locations
4. **Missing features**: No log levels, no subsystem filtering, no Console.app integration

### Recommendation: Adopt Swift's Logger (os)

**Benefits:**
- Native Console.app integration for debugging
- Type-safe, compile-time optimized logging
- Automatic log level management (debug/info/error)
- Privacy-aware by default (redacts sensitive data)
- Zero performance impact when logging disabled
- Subsystem/category filtering

**Implementation:**

```swift
// In AppState.swift or new Logging.swift file
import os

extension Logger {
    static let appState = Logger(subsystem: "com.tiercade.app", category: "AppState")
    static let headToHead = Logger(subsystem: "com.tiercade.app", category: "HeadToHead")
    static let persistence = Logger(subsystem: "com.tiercade.app", category: "Persistence")
}
```

**Before:**
```swift
// AppState+HeadToHead.swift:48-60
let log = [
    "[AppState] startH2H:",
    "poolCount=\(h2hPool.count)",
    "initialTarget=\(targetComparisons)",
    "scheduledPairs=\(h2hTotalComparisons)"
].joined(separator: " ")
print(log)
NSLog("%@", log)
Task {
    await appendDebugFile(
        "startH2H: poolCount=\(h2hPool.count) totalPairs=\(h2hTotalComparisons)"
    )
}
```

**After:**
```swift
// Simple, fast, integrated with Console.app
Logger.headToHead.info("Starting H2H: pool=\(h2hPool.count) target=\(targetComparisons) pairs=\(h2hTotalComparisons)")
```

**Migration Strategy:**
1. Create Logger extensions in `Util/Logging.swift`
2. Replace all `print`/`NSLog`/`Task { await appendDebugFile(...) }` with Logger calls
3. Use `.debug()` for verbose logs, `.info()` for state changes, `.error()` for failures
4. Remove `appendDebugFile()` method entirely (50+ lines eliminated)
5. For UI tests that need file logs, add conditional OSLog store reading

**Impact:**
- **Remove:** ~100+ lines of logging boilerplate
- **Simplify:** All logging to single-line calls
- **Performance:** Eliminate 16+ Task spawns per user session
- **Developer Experience:** Better debugging with Console.app integration

---

## 2. Simplify AppState.appendDebugFile() 🟡 **MEDIUM PRIORITY**

### Current State (AppState.swift:190-239)

```swift
nonisolated func appendDebugFile(_ message: String) async {
    // 50 lines of duplicate code writing to both /tmp and Documents
    // Manual FileHandle management
    // Error handling silently ignored
}
```

### Problems
1. **Code duplication**: Same file-writing logic repeated twice
2. **Complexity**: 50 lines for what should be simple logging
3. **Error handling**: All errors silently ignored (`catch { // ignore }`)
4. **Nonisolated async**: Creates unnecessary concurrency complexity

### Recommendation

**Option A (If keeping custom file logging):**
```swift
private func writeToLogFile(at path: String, message: String) throws {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let pid = ProcessInfo.processInfo.processIdentifier
    let line = "\(timestamp) [pid:\(pid)] \(message)\n"

    let url = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: path) {
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
    } else {
        try Data(line.utf8).write(to: url, options: .atomic)
    }
}

nonisolated func appendDebugFile(_ message: String) async {
    let paths = [
        "/tmp/tiercade_debug.log",
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tiercade_debug.log").path
    ].compactMap { $0 }

    for path in paths {
        try? writeToLogFile(at: path, message: "[AppState] \(message)")
    }
}
```

**Option B (Recommended - Use Logger):**
Remove entirely and use Logger with optional OSLog store reading for test artifacts.

**Impact:**
- **Reduce:** 50 lines → 20 lines (Option A) or 0 lines (Option B)
- **Clarity:** Single responsibility, better error visibility

---

## 3. Modernize Swift APIs 🟢 **LOW IMPACT**

### A. Resolve Cyclomatic Complexity Discrepancy

**Current:**
- `.swiftlint.yml` line 10: `warning: 7`
- `CLAUDE.md` line 128: "warning at 8, error at 12"

**Recommendation:**
Update `.swiftlint.yml` to match documentation or vice versa. Recommended unified setting:

```yaml
cyclomatic_complexity:
  warning: 8
  error: 12
```

This aligns with documentation and industry standards (8-10 is typical warning threshold).

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

**1. Reduce ZStack Complexity in MainAppView**

**Current (MainAppView.swift:138-259):** 12+ overlays in single ZStack with manual zIndex management

**Recommendation:** Extract overlay composition into computed property or ViewBuilder:

```swift
@ViewBuilder
private var overlayStack: some View {
    Group {
        if app.isLoading {
            ProgressIndicatorView(...)
                .zIndex(50)
        }
        QuickRankOverlay(app: app).zIndex(40)
        // ... etc
    }
}

var body: some View {
    // ... main content
    .overlay { overlayStack }
}
```

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
5. ✅ **History pattern**: Undo/redo via HistoryLogic

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

### Immediate (High ROI)

1. **Replace logging system with Logger** (2-4 hours)
   - Files: All `AppState+*.swift` files
   - Lines removed: ~100+
   - Impact: Better debugging, performance, maintainability

2. **Simplify or remove appendDebugFile** (30 minutes)
   - File: `AppState.swift:190-239`
   - Lines removed: ~50
   - Impact: Reduced complexity

### Quick Wins (Low effort, clear benefit)

3. **Fix cyclomatic_complexity discrepancy** (2 minutes)
   - File: `.swiftlint.yml:10`
   - Change: `warning: 7` → `warning: 8`

### Optional Enhancements

4. **Extract overlay stack in MainAppView** (1 hour)
   - File: `MainAppView.swift`
   - Impact: Better code organization

5. **Consider state slicing** (Future)
   - Impact: Scalability for future growth

---

## Metrics

### Before Modernization
- **Custom logging**: 30+ locations in State files alone
- **Fire-and-forget Tasks**: 16+ in State files
- **appendDebugFile complexity**: 50 lines
- **Manual log formatting**: 15+ unique patterns

### After Modernization (Estimated)
- **Logger calls**: ~40 one-liners
- **Fire-and-forget Tasks**: 0
- **appendDebugFile**: Removed (or 20 lines if keeping)
- **Log formatting**: 0 (handled by Logger)

### Total Impact
- **~150 lines removed**
- **~16 Task spawns eliminated**
- **Better Console.app integration**
- **Improved debugging ergonomics**

---

## Migration Priority

```
PRIORITY 1: Logging System (Logger)
├─ Create Logger+Extensions.swift
├─ Update AppState+HeadToHead.swift
├─ Update AppState+Persistence.swift
├─ Update AppState+Items.swift
├─ Update AppState.swift (remove appendDebugFile)
└─ Test with Console.app

PRIORITY 2: Documentation Fixes
└─ Update .swiftlint.yml

PRIORITY 3: Code Organization
└─ Extract MainAppView overlay composition
```

---

## Files Requiring Changes

### High Priority (Logging Migration)
```
Tiercade/State/AppState.swift
Tiercade/State/AppState+HeadToHead.swift
Tiercade/State/AppState+Persistence.swift
Tiercade/State/AppState+Progress.swift
Tiercade/State/AppState+Items.swift
Tiercade/State/AppState+Export.swift
Tiercade/State/AppState+Import.swift
Tiercade/Util/Logging.swift (NEW)
```

### Documentation
```
.swiftlint.yml
```

### Optional
```
Tiercade/Views/Main/MainAppView.swift
```

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

This codebase is **already modern** and well-architected. The main opportunity for improvement is replacing the custom logging infrastructure with Swift's unified logging system. The rest of the code follows current best practices and doesn't require significant changes.

**Estimated modernization time:** 4-6 hours
**Risk level:** Low (logging is mostly additive changes)
**Testing impact:** Minimal (behavior unchanged, just logging mechanism)
