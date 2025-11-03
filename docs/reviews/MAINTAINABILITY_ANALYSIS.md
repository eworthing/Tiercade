# Tiercade Codebase Maintainability Analysis

## 1. NAMING PATTERNS & UNCLEAR ABBREVIATIONS

### 1.1 Heavy Use of `h2h` / `H2H` Throughout State Management

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState.swift` (lines 140-160)

```swift
var h2hActive: Bool = false
enum H2HSessionPhase: Sendable {
    case quick
    case refinement
}
var h2hPool: [Item] = []
var h2hPair: (Item, Item)?
var h2hRecords: [String: H2HRecord] = [:]
var h2hPairsQueue: [(Item, Item)] = []
var h2hDeferredPairs: [(Item, Item)] = []
var h2hTotalComparisons: Int = 0
var h2hCompletedComparisons: Int = 0
var h2hSkippedPairKeys: Set<String> = []
var h2hActivatedAt: Date?
var h2hPhase: H2HSessionPhase = .quick
var h2hArtifacts: H2HArtifacts?
var h2hSuggestedPairs: [(Item, Item)] = []
var h2hInitialSnapshot: TierStateSnapshot?
var h2hRefinementTotalComparisons: Int = 0
var h2hRefinementCompletedComparisons: Int = 0
```

**Problem:** While "H2H" (Head-to-Head) is domain-clear to domain experts, 17+ properties using this abbreviation make it difficult to search, autocomplete, and understand for new maintainers. The prefix is repeated on every property name.

**New Maintainer Friction:** Takes 30+ seconds to recognize pattern. Adding new property requires pattern lookup.

---

### 1.2 Generic Handler Naming with Vague Intent

**File:** `/Users/Shared/git/Tiercade/Tiercade/Views/Overlays/MatchupArenaOverlay.swift` (lines 103-110, 308, 325, 331, 391)

```swift
private func handleFocusAnchorChange(newValue: MatchupFocusAnchor?) {
    guard !suppressFocusReset else { return }
    if let newValue {
        lastFocus = newValue
    } else {
        focusAnchor = lastFocus
    }
}

private func handleAppear() { ... }
private func handleMoveCommand(_ direction: MoveCommandDirection) { ... }
private func handleDirectionalInput(_ move: DirectionalMove) { ... }
private func handlePrimaryAction() { ... }
```

**Problem:** "Handle" is too generic. Without reading the full implementation, unclear whether this:
- Updates state only
- Triggers side effects
- Returns values
- Modifies focus state
- Has hidden dependencies

**New Maintainer Friction:** Must read each handler's implementation to understand control flow. Five different handlers with similar names but different semantics.

---

### 1.3 Unclear Method Name: `quickPhaseTargetComparisons`

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState+HeadToHead.swift` (lines 254-266)

```swift
private func quickPhaseTargetComparisons(for poolCount: Int) -> Int {
    guard poolCount > 1 else { return 0 }
    let maxUnique = poolCount - 1
    let desired: Int
    if poolCount >= 10 {
        desired = 3
    } else if poolCount >= 6 {
        desired = 3  // ← Same value in both branches! Why?
    } else {
        desired = 2
    }
    return max(1, min(desired, maxUnique))
}
```

**Problem:** 
- Name is opaque about what "target comparisons" means in the head-to-head algorithm
- The magic numbers (10, 6, 3, 2) are unexplained
- Both branches return 3, suggesting dead code or copy-paste error

**New Maintainer Questions:**
- What is "target comparisons per item"?
- Why threshold 10 and 6?
- Are those thresholds tied to statistical requirements?
- Can these be tuned independently?

---

### 1.4 Ambiguous State Property Naming

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState.swift` (lines 102-105)

```swift
var quickRankTarget: Item?
var quickMoveTarget: Item?
var batchQuickMoveActive: Bool = false
```

**Problem:** 
- `quickMoveTarget` vs `quickRankTarget` — subtle difference, easy to mix up
- Unclear if `batchQuickMoveActive` should be a boolean or if it's tied to selection state
- No docstrings explaining the relationship between these three properties

**New Maintainer Questions:**
- What's the difference between Quick Rank and Quick Move?
- Can both be active simultaneously?
- What triggers `batchQuickMoveActive`?

---

## 2. IMPLICIT COUPLING & HIDDEN INITIALIZATION ORDER

### 2.1 Silent Initialization Order Dependency

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState.swift` (lines 253-277)

```swift
internal init(modelContext: ModelContext) {
    self.modelContext = modelContext
    let didLoad = load()                           // ← Loads persisted data
    if !didLoad {
        seed()                                     // ← Seeds with default project
    } else if isLegacyBundledListPlaceholder(tiers) {
        logEvent("init: detected legacy bundled list placeholder; reseeding default project")
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: tierListStateKey)
        defaults.removeObject(forKey: tierListRecentsKey)
        seed()
    }
    setupAutosave()
    let tierSummary = tierOrder
        .map { "\($0):\(tiers[$0]?.count ?? 0)" }
        .joined(separator: ", ")
    let unrankedCount = tiers["unranked"]?.count ?? 0
    let initMsg = "init: tiers counts=\(tierSummary) unranked=\(unrankedCount)"
    logEvent(initMsg)
    restoreTierListState()                        // ← Restores UI selection state
    if !didLoad {
        loadActiveTierListIfNeeded()               // ← Loads the actual tier list
    }
    prefillBundledProjectsIfNeeded()              // ← Pre-caches bundled projects
}
```

**Problem:** 
1. **Order dependency not documented:** `restoreTierListState()` must run AFTER `seed()`, but nothing enforces this
2. **Conditional load logic unclear:** 
   - If `didLoad == true`, `loadActiveTierListIfNeeded()` is skipped
   - But `restoreTierListState()` runs regardless
   - What if the handle from `restoreTierListState()` points to a file that doesn't exist yet?
3. **Side effects mixed with initialization:** `setupAutosave()` starts a background task during `__init__`, but cancellation is not guaranteed if exceptions occur

**New Maintainer Risk:** 
- Moving any line will silently break state
- Adding early returns becomes dangerous
- Testing initialization requires understanding all five method interactions

---

### 2.2 State Mutation Pattern Relies on Manual Snapshot Discipline

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState+Items.swift` (lines 21-39)

```swift
internal func performReset(showToast: Bool = false) {
    let snapshot = captureTierSnapshot()           // ← Manual snapshot capture
    if let defaultProject = bundledProjects.first {
        let state = resolvedTierState(for: defaultProject)
        tierOrder = state.order
        tiers = state.items
        tierLabels = state.labels
        tierColors = state.colors
        lockedTiers = state.locked
    } else {
        tiers = makeEmptyTiers()
    }
    finalizeChange(action: "Reset Tier List", undoSnapshot: snapshot)
    // ...
}
```

**Problem:** 
- Every state mutation method must remember to call `captureTierSnapshot()` BEFORE mutations
- No compile-time enforcement; forgetting this breaks undo/redo silently
- 20+ extension methods all follow this pattern, all vulnerable to the same mistake
- `finalizeChange()` is called unconditionally but there's no verification that the snapshot is correct

**Implicit Coupling Points:**
1. Snapshot must be taken before ANY mutation
2. `finalizeChange()` always expects a valid "before" snapshot
3. Undo system depends on exact property ordering in `TierStateSnapshot`
4. If a new state property is added, `TierStateSnapshot` MUST be updated or undo breaks silently

---

### 2.3 Head-to-Head State Machine with No State Validation

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState+HeadToHead.swift` (lines 9-56)

```swift
internal func startH2H() {
    if h2hActive {
        showInfoToast("Head-to-Head Already Active", message: "Finish or cancel the current matchup first")
        return
    }
    // ... initialization ...
    h2hInitialSnapshot = captureTierSnapshot()
    h2hPool = pool
    h2hRecords = [:]
    h2hPairsQueue = pairs
    h2hDeferredPairs = []
    h2hTotalComparisons = pairs.count
    h2hCompletedComparisons = 0
    h2hRefinementTotalComparisons = 0
    h2hRefinementCompletedComparisons = 0
    h2hSkippedPairKeys = []
    h2hPair = nil
    h2hActive = true                               // ← Activated last
    h2hActivatedAt = Date()
    h2hPhase = .quick
    h2hArtifacts = nil
    h2hSuggestedPairs = []

    nextH2HPair()                                  // ← Calls logic that checks h2hActive
}
```

**Problem:** 
- `h2hActive = true` is set AFTER all initialization, but `nextH2HPair()` immediately checks `h2hActive`
- If initialization fails between snapshot and activation, `h2hActive` remains false but partial state is initialized
- No invariant validation: 
  - What if `h2hPairsQueue.isEmpty` but `h2hTotalComparisons > 0`?
  - What if `h2hPool.count != poolCount`?
  - What if `h2hRecords` contains items not in `h2hPool`?

**Implicit Assumption:** The 17 assignments must all succeed and be consistent with each other, but this is unenforced.

---

## 3. MAGIC NUMBERS SCATTERED & UNDOCUMENTED

### 3.1 Tuning Constants in HeadToHead Logic

**File:** `/Users/Shared/git/Tiercade/TiercadeCore/Sources/TiercadeCore/Logic/HeadToHead+Internals.swift` (lines 34-52)

```swift
internal enum Tun {
    internal static let maximumTierCount = 20
    internal static let minimumComparisonsPerItem = 2
    internal static let frontierWidth = 2
    internal static let zQuick: Double = 1.0
    internal static let zStd: Double = 1.28
    internal static let zRefineEarly: Double = 1.0
    internal static let softOverlapEps: Double = 0.010
    internal static let confBonusBeta: Double = 0.10
    internal static let maxSuggestedPairs = 6
    internal static let hysteresisMaxChurnSoft: Double = 0.12
    internal static let hysteresisMaxChurnHard: Double = 0.25
    internal static let hysteresisRampBoost: Double = 0.50
    internal static let minWilsonRangeForSplit: Double = 0.015
    internal static let epsTieTop: Double = 0.012
    internal static let epsTieBottom: Double = 0.010
    internal static let maxBottomTieWidth: Int = 4
    internal static let ubBottomCeil: Double = 0.20
}
```

**Problem:** 
- No docstrings explaining what each constant does
- Some constants (like `zQuick = 1.0` and `zRefineEarly = 1.0`) are identical but not documented why
- `epsTieTop = 0.012` vs `epsTieBottom = 0.010` — unclear what these epsilon values represent
- `hysteresisMaxChurnSoft` vs `hysteresisMaxChurnHard` — unclear what "churn" means in this context
- Wilson score constants (zQuick, zStd) suggest statistical confidence intervals, but this isn't documented

**New Maintainer Questions:**
- What is the statistical significance of z=1.0 vs z=1.28?
- Why is frontierWidth exactly 2?
- Can these be tuned? What are safe ranges?
- Are these values empirically derived or theoretical?

---

### 3.2 Magic Numbers in Opacity & Styling

**File:** `/Users/Shared/git/Tiercade/Tiercade/Views/Overlays/QuickMoveOverlay.swift` (lines 28-48, 267-272)

```swift
ZStack {
    Color.black.opacity(0.65)    // ← Magic: Why 0.65?
        .ignoresSafeArea()
        .allowsHitTesting(false)

    VStack(spacing: 28) {        // ← Magic: Why 28?
        Text(title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

        tierButtons(...)

        Divider()
            .opacity(0.3)         // ← Magic: Why 0.3?
            .padding(.horizontal, 24)

        actionButtons(...)
    }
    .padding(32)                  // ← Magic: Why 32?
    .background(...)
    .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.black.opacity(0.85))      // ← Magic: Why 0.85?
    )
    // ...
    .tint(tierColor.opacity(isCurrentTier ? 0.36 : 0.24))  // ← Magic: 0.36 vs 0.24?

    // In TierButton:
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                isFocused ? Color.white : tierColor.opacity(isCurrentTier ? 0.95 : 0.55),
                lineWidth: isFocused ? 4 : (isCurrentTier ? 3 : 2)
            )
    )
}
```

**Problem:** 
- 12+ magic numbers with no documentation
- Opacity values (0.65, 0.3, 0.85, 0.36, 0.24, 0.95, 0.55) are scattered and appear arbitrary
- Spacing values (28, 24, 32) have no design system reference
- Line widths (4, 3, 2) are tied to focus state but not documented

**New Maintainer Questions:**
- Are these WCAG compliant contrast ratios?
- Why 0.36 opacity for tint instead of 0.40?
- Can I adjust spacing safely without breaking layout?
- Where is the design token that specifies overlay background opacity?

---

### 3.3 Hidden Thresholds in Layout System

**File:** `/Users/Shared/git/Tiercade/Tiercade/Design/TVMetrics.swift` (lines 46-57)

```swift
var effective = preference
if itemCount >= denseThreshold * 4 {
    effective = .ultraMicro                      // ← itemCount >= 72
} else if itemCount >= denseThreshold * 3 {
    effective = minDensity(effective, .micro)   // ← itemCount >= 54
} else if itemCount >= denseThreshold * 2 {
    effective = minDensity(effective, .tight)   // ← itemCount >= 36
} else if itemCount >= denseThreshold {
    effective = minDensity(effective, .compact) // ← itemCount >= 18
}
```

Where:
```swift
internal static let denseThreshold: Int = 18
```

**Problem:** 
- Hardcoded multipliers (4, 3, 2, 1) with no explanation
- Thresholds at 72, 54, 36, 18 items are magic numbers derived from `denseThreshold`
- If `denseThreshold` changes, behavior changes in 4 places simultaneously
- No docstring explaining the algorithm

**New Maintainer Questions:**
- Why is 18 the threshold?
- What UI metric drove the choice of 18 vs 16 vs 20?
- Are these thresholds tested for user perception?
- Can I change `denseThreshold` independently, or does it affect other calculations?

---

## 4. HIDDEN INVARIANTS & UNENFORCED ASSUMPTIONS

### 4.1 Undocumented Tier Order Invariant

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState.swift` (lines 97-98)

```swift
var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]
```

**Problem:** 
- `tiers` dictionary is initialized with a fixed set of keys, but `tierOrder` only includes 6 items (excludes "unranked")
- The code assumes `"unranked"` is special and should NOT be in `tierOrder`, but this is nowhere documented
- Many helper methods rely on this assumption:

```swift
// AppState+Items.swift line 9
let hasAnyData = (tierOrder + ["unranked"]).contains { tierName in
    (tiers[tierName] ?? []).count > 0
}
```

**Hidden Invariants:**
1. `tiers.keys` ⊇ `tierOrder` ∪ {"unranked"}
2. `tierOrder` must NOT contain "unranked" (implicit)
3. `tiers["unranked"]` must exist (else nil coalescing needed everywhere)
4. Custom tiers can be added to `tierOrder`, but they must be in `tiers` first

**New Maintainer Risk:** 
- Adding a tier might forget to add to both `tiers` and `tierOrder`
- Creating a custom tier might accidentally include "unranked" in `tierOrder`
- No runtime validation catches these mistakes

---

### 4.2 Head-to-Head Progress Calculation Invariant

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppState.swift` (lines 227-247)

```swift
var h2hOverallProgress: Double {
    let quickWeight = 0.75                        // ← Magic: Why 0.75?
    var progress: Double = 0

    if h2hTotalComparisons > 0 {
        let quickFraction = Double(min(h2hCompletedComparisons, h2hTotalComparisons)) / Double(h2hTotalComparisons)
        progress = min(max(quickFraction, 0), 1) * quickWeight
    }

    if h2hRefinementTotalComparisons > 0 {
        let refinementFraction = Double(
            min(h2hRefinementCompletedComparisons, h2hRefinementTotalComparisons)
        ) / Double(h2hRefinementTotalComparisons)
        progress = min(progress, quickWeight)      // ← Logic unclear: why min()?
        progress += (1 - quickWeight) * min(max(refinementFraction, 0), 1)
    } else if !h2hActive && h2hTotalComparisons > 0 && h2hCompletedComparisons >= h2hTotalComparisons {
        progress = 1.0
    }

    return min(max(progress, 0), 1)
}
```

**Hidden Invariants:**
1. Quick phase is weighted 75%, refinement 25%
2. If refinement hasn't started, progress is pure quick-phase progress
3. The line `progress = min(progress, quickWeight)` is cryptic — it appears to cap progress before adding refinement
4. Refinement only matters if `h2hRefinementTotalComparisons > 0`
5. Special case: if H2H completes with NO refinement, progress jumps to 1.0

**New Maintainer Questions:**
- Why is 0.75 the weight for quick phase?
- What does `progress = min(progress, quickWeight)` do? Is it a bug or a feature?
- Why the special case at the end? Why not just return 1.0 when queues empty?
- If refinement adds pairs that increase `h2hRefinementTotalComparisons`, does progress recalculate correctly?

---

### 4.3 Implicit Retry State Semantics in AI Generation

**File:** `/Users/Shared/git/Tiercade/Tiercade/State/AppleIntelligence+UniqueListGeneration.swift` (lines 49-101)

```swift
for attempt in 0..<params.maxRetries {
    let attemptStart = Date()
    // INVARIANT: Reset per-attempt flags to preserve telemetry accuracy (see 1c5d26b).
    retryState.sessionRecreated = false           // ← Reset per-attempt

    logAttemptDetails(attempt: attempt, maxRetries: params.maxRetries, options: retryState.options)

    do {
        let response = try await executeGuidedGeneration(
            prompt: params.prompt,
            options: retryState.options
        )

        handleSuccessResponse(
            context: ResponseContext(
                response: response,
                attempt: attempt,
                attemptStart: attemptStart,
                totalStart: start,
                currentSeed: retryState.seed,
                sessionRecreated: retryState.sessionRecreated,  // ← Reports current attempt's state
                params: params
            ),
            telemetry: &telemetry
        )

        return response.content.items

    } catch let e as LanguageModelSession.GenerationError {
        retryState.lastError = e

        if try await handleAttemptFailure(
            error: e,
            attempt: attempt,
            attemptStart: attemptStart,
            params: params,
            retryState: &retryState,  // ← May update sessionRecreated
            telemetry: &telemetry
        ) {
            continue
        } else {
            break
        }
    }
}
```

**Hidden Invariant:** 
- `retryState.sessionRecreated` MUST be reset to false at the START of each attempt
- If reset is done at the END, telemetry reports stale values from the previous attempt
- This was a bug (commit 1c5d26b), and the fix is documented inline

**New Maintainer Risk:** 
- Code is correct now, but the invariant is easily broken if someone refactors
- Moving the reset line even slightly can introduce the bug again
- No compile-time enforcement

---

## 5. FOCUS MANAGEMENT COUPLING (tvOS)

### 5.1 Coupled Focus State Machines

**File:** `/Users/Shared/git/Tiercade/Tiercade/Views/Overlays/MatchupArenaOverlay.swift` (lines 15-20, 103-114)

```swift
@FocusState private var focusAnchor: MatchupFocusAnchor?
@State private var lastFocus: MatchupFocusAnchor = .primary
@State private var suppressFocusReset = false

private func handleFocusAnchorChange(newValue: MatchupFocusAnchor?) {
    guard !suppressFocusReset else { return }
    if let newValue {
        lastFocus = newValue
    } else {
        focusAnchor = lastFocus                   // ← Resets to last valid focus
    }
}
```

**Problem:** 
- Three state variables (`focusAnchor`, `lastFocus`, `suppressFocusReset`) manage focus
- When focus becomes nil (lost), the handler restores `lastFocus`
- `suppressFocusReset` acts as a gate, but it's unclear when it's set/unset
- The relationship between these three variables is implicit

**New Maintainer Questions:**
- When is `suppressFocusReset` set to true?
- How is it reset back to false?
- Why not use `.onChange()` modifier instead of the handler?
- What happens if focus cycles through multiple elements rapidly?

---

### 5.2 Magic Numbers in Focus Spacing

**File:** `/Users/Shared/git/Tiercade/Tiercade/Views/Overlays/MatchupArenaOverlay.swift` (lines 22, 116-128)

```swift
private let minOverlayWidth: CGFloat = 960      // ← Magic: Why 960?

private func overlayMaxWidth(for proxy: GeometryProxy) -> CGFloat {
    #if os(tvOS)
    let safeArea = proxy.safeAreaInsets
    let available = max(proxy.size.width - safeArea.leading - safeArea.trailing, 0)
    let horizontalMargin = Metrics.grid * 4     // ← Why 4 grids? What's a grid?
    let desired = max(available - horizontalMargin, minOverlayWidth)
    return min(desired, available)
    #else
    let available = proxy.size.width
    let horizontalMargin = Metrics.grid * 4
    let desired = max(available - horizontalMargin, 860)  // ← 860 vs 960: why different?
    return min(desired, available)
    #endif
}
```

**Problem:** 
- Minimum overlay width is 960 on tvOS but 860 on non-tvOS
- Horizontal margin is `Metrics.grid * 4`, but what's the base grid size?
- No comment explaining the 960/860 difference or the philosophy

---

## 6. SUMMARY TABLE: CODE LOCATIONS NEEDING CLARIFICATION

| Issue | File | Lines | Problem | Impact |
|-------|------|-------|---------|--------|
| `h2h` abbreviation overuse | AppState.swift | 140-160 | 17 properties with vague prefix | Search/refactor friction |
| Generic `handle*` methods | MatchupArenaOverlay.swift | 103-391 | No semantic meaning | Control flow unclear |
| `quickPhaseTargetComparisons` | AppState+HeadToHead.swift | 254-266 | Magic numbers (10, 6, 3, 2), duplicate logic | Algorithm tuning error-prone |
| Init order dependency | AppState.swift | 253-277 | 5 methods with implicit order | Silent state corruption if reordered |
| Manual snapshot discipline | AppState+Items.swift | 21-39 | No compile enforcement | Undo/redo breaks if forgotten |
| H2H state machine | AppState+HeadToHead.swift | 9-56 | No invariant validation | Partial initialization crash risk |
| Tuning constants | HeadToHead+Internals.swift | 34-52 | 17 constants, no documentation | Algorithm changes break unexpectedly |
| Opacity/spacing magic numbers | QuickMoveOverlay.swift | 28-272 | 12+ hardcoded values | Design changes scattered |
| Layout thresholds | TVMetrics.swift | 46-57 | Threshold calculations opaque | Density tuning unclear |
| Tier order invariant | AppState.swift | 97-98 | Implicit "unranked" exclusion | Adding tiers breaks silently |
| Progress calculation | AppState.swift | 227-247 | Weighted average with magic 0.75 | Progress semantics unclear |
| Retry state reset | UniqueListGeneration.swift | 49-54 | Per-attempt flag reset required | Telemetry bug if moved |
| Focus coupling | MatchupArenaOverlay.swift | 15-20, 103-114 | 3-variable state machine | Focus loss behavior fragile |

---

## 7. RECOMMENDATIONS FOR NEW MAINTAINERS

### Immediate Actions (Before Modifying State Logic)
1. **Read CLAUDE.md** for architectural patterns (already provided in repo)
2. **Map the state initialization** — print AppState.__init__ call sequence
3. **Verify the tier invariants** — check that custom tiers work end-to-end
4. **Test undo/redo** — ensure snapshots are captured correctly for new operations
5. **Document the "Tun" enum** — add docstrings explaining each tuning constant

### High-Risk Refactoring Areas
- Renaming any `h2h*` property → will break 20+ call sites
- Reordering initialization methods → will silently corrupt state
- Changing magic numbers in TVMetrics → will break layout density calculations
- Modifying retry loop structure → will break telemetry accuracy

### Testing Strategy
- Unit test the tier invariant: `tiers.keys ⊇ tierOrder ∪ {"unranked"}`
- Unit test progress calculation: verify it's always in [0.0, 1.0]
- Integration test init sequence: verify state is consistent after each step
- Property-based test undo: verify snapshot + mutation + undo = original state

