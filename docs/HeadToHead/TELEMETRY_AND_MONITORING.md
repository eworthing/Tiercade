# HeadToHead Telemetry & Monitoring (Future Implementation)

**Status:** Planned - Not Yet Implemented
**Priority:** High (prerequisite for production optimization)
**Estimated Effort:** 1-2 days
**Date:** November 2025

---

## Executive Summary

This document provides a complete specification for HeadToHead session telemetry and monitoring. The current HeadToHead algorithm is well-architected and validated by 600+ Monte Carlo simulations. **Telemetry is the only missing piece** before production optimization.

**Purpose:** Validate that adaptive comparison budgets work correctly in production and establish baseline metrics for future optimization.

**Key Principle:** Observe production behavior BEFORE optimizing. Don't solve hypothetical problems.

---

## Why Telemetry Before Optimization

### What We Know (From Simulation)

✅ **Algorithm works mathematically:**

- Tau: 0.40-0.45 for 20 items @ 4-5 comp/item
- Variance: std(tau) = 0.108-0.135 (acceptable)
- Small pools (10 items): tau = 0.628 (exceeds targets)
- Adaptive budgets scale correctly (3→4→5→6 comp/item)

### What We Don't Know (Need Production Data)

❓ **User behavior:**

- Do users finish sessions? (completion rate)
- How long do sessions take? (actual duration vs estimates)
- What skip patterns emerge? (when/why users skip)
- Do results feel trustworthy? (re-run stability)

❓ **Domain-specific patterns:**

- Are movies easier than music? (noise level validation)
- Do large pools (30+) have issues? (scaling validation)
- Are skip rates acceptable? (pair selection validation)

### Decision Framework

**Telemetry tells us:**

- ✅ If current system is good enough → ship as-is
- ⚠️ If specific issues exist → optimize those issues
- ❌ If major problems → investigate root cause

**Without telemetry we risk:**

- Over-engineering solutions for non-existent problems
- Missing real issues that affect users
- Optimizing the wrong metrics (tau vs user satisfaction)

---

## Telemetry Architecture

### Core Metrics Struct

**File:** `Tiercade/State/HeadToHeadSessionMetrics.swift` (to be created)

**Note:** The name `HeadToHeadSessionMetrics` avoids collision with the existing `HeadToHeadMetrics` struct in `TiercadeCore/Logic/HeadToHead+Internals.swift` (which tracks per-item ranking metrics like Wilson bounds).

```swift
import Foundation

/// Session-level telemetry data captured during a HeadToHead ranking session
struct HeadToHeadSessionMetrics: Codable, Sendable {
    // MARK: - Session Identification
    let sessionId: UUID
    let startTime: Date
    var endTime: Date?

    // MARK: - Pool Configuration
    let poolSize: Int
    let targetComparisonsPerItem: Int  // From adaptive budget
    let plannedTotalComparisons: Int

    // MARK: - Completion Status
    enum CompletionStatus: String, Codable {
        case completed      // User finished all comparisons
        case cancelled      // User explicitly cancelled
        case abandoned      // Session never formally ended
    }
    var status: CompletionStatus = .abandoned

    // MARK: - Progress Metrics
    var quickPhaseComparisons: Int = 0
    var refinementPhaseComparisons: Int = 0
    var totalComparisons: Int {
        quickPhaseComparisons + refinementPhaseComparisons
    }
    var skipCount: Int = 0

    // MARK: - Derived Performance Metrics
    var sessionDuration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var comparisonsPerMinute: Double? {
        guard let duration = sessionDuration, duration > 0 else { return nil }
        return Double(totalComparisons) / (duration / 60.0)
    }

    var skipRate: Double {
        let total = totalComparisons + skipCount
        guard total > 0 else { return 0 }
        return Double(skipCount) / Double(total)
    }

    var completionRate: Double {
        guard plannedTotalComparisons > 0 else { return 0 }
        return Double(totalComparisons) / Double(plannedTotalComparisons)
    }

    // MARK: - Comparison Events (Optional)
    struct ComparisonEvent: Codable, Sendable {
        let timestamp: Date
        let itemA: String  // item ID
        let itemB: String  // item ID
        let winner: String?  // nil if skipped
        let phase: String  // "quick" or "refinement"
        let thinkTime: TimeInterval?  // Time between comparisons
    }
    var comparisonEvents: [ComparisonEvent] = []

    // MARK: - Quality Metrics (Post-Session)
    var finalTierDistribution: [String: Int]?  // tierName -> count
    var maxTierFraction: Double?  // Largest tier as % of pool
    var emptyTierCount: Int?

    // MARK: - Optional: Domain Tracking
    var domain: String?  // e.g., "movies", "games", "restaurants"

    // MARK: - Initializer
    init(poolSize: Int, targetComparisonsPerItem: Int, plannedComparisons: Int) {
        self.sessionId = UUID()
        self.startTime = Date()
        self.poolSize = poolSize
        self.targetComparisonsPerItem = targetComparisonsPerItem
        self.plannedTotalComparisons = plannedComparisons
    }
}
```

**Design Rationale:**

- **Codable:** Easy JSON export for analysis
- **Sendable:** Swift 6 concurrency safe
- **Computed properties:** Derived metrics calculated on demand
- **Optional events:** Can disable to reduce memory if needed
- **Mutable post-session properties:** `finalTierDistribution`, `maxTierFraction`, `emptyTierCount`, `domain` are declared as `var` to allow setting after session completion

---

## Integration Points

### 1. Session Start

**Location:** `AppState+HeadToHead.swift:startHeadToHead()`
**Current code (line ~9-57):**

```swift
func startHeadToHead() {
    // ... existing validation ...

    headToHead.isActive = true
    headToHead.activatedAt = Date()
    headToHead.phase = .quick

    // ADD HERE:
    headToHead.currentMetrics = HeadToHeadSessionMetrics(
        poolSize: pool.count,
        targetComparisonsPerItem: targetComparisons,
        plannedComparisons: pairs.count
    )

    Logger.headToHead.info(
        "Started HeadToHead: pool=\(pool.count) sessionId=\(headToHead.currentMetrics!.sessionId)"
    )
}
```

---

### 2. Record Comparisons

**Location:** `AppState+HeadToHead.swift:voteHeadToHead(winner:)`
**Current code (line ~79-112):**

```swift
func voteHeadToHead(winner: Item) {
    // ... existing logic ...

    if headToHead.phase == .refinement {
        headToHead.refinementCompletedComparisons += 1
        // ADD HERE:
        headToHead.currentMetrics?.refinementPhaseComparisons += 1
    } else {
        headToHead.completedComparisons += 1
        // ADD HERE:
        headToHead.currentMetrics?.quickPhaseComparisons += 1
    }

    // OPTIONAL: Record detailed event
    if headToHead.trackComparisonEvents {
        let event = HeadToHeadSessionMetrics.ComparisonEvent(
            timestamp: Date(),
            itemA: a.id,
            itemB: b.id,
            winner: winner.id,
            phase: headToHead.phase == .quick ? "quick" : "refinement",
            thinkTime: calculateThinkTime()  // Time since last comparison
        )
        headToHead.currentMetrics?.comparisonEvents.append(event)
    }
}
```

---

### 3. Record Skips

**Location:** `AppState+HeadToHead.swift:skipCurrentHeadToHeadPair()`
**Current code (line ~114-121):**

```swift
func skipCurrentHeadToHeadPair() {
    // ... existing logic ...

    // ADD HERE:
    headToHead.currentMetrics?.skipCount += 1

    // OPTIONAL: Record skip event
    if headToHead.trackComparisonEvents {
        let event = HeadToHeadSessionMetrics.ComparisonEvent(
            timestamp: Date(),
            itemA: pair.0.id,
            itemB: pair.1.id,
            winner: nil,  // nil indicates skip
            phase: headToHead.phase == .quick ? "quick" : "refinement",
            thinkTime: nil
        )
        headToHead.currentMetrics?.comparisonEvents.append(event)
    }
}
```

---

### 4. Session Completion

**Location:** `AppState+HeadToHead.swift:finalizeHeadToHead(with:)`
**Current code (line ~171-192):**

```swift
private func finalizeHeadToHead(with artifacts: HeadToHeadArtifacts?) {
    // ... existing finalization ...

    // ADD HERE (before resetHeadToHeadSession):
    if var metrics = headToHead.currentMetrics {
        metrics.endTime = Date()
        metrics.status = .completed

        // Compute tier distribution
        let distribution = tierOrder.reduce(into: [String: Int]()) { result, tierName in
            result[tierName] = tiers[tierName]?.count ?? 0
        }
        metrics.finalTierDistribution = distribution

        // Compute max tier fraction
        let maxCount = distribution.values.max() ?? 0
        metrics.maxTierFraction = Double(maxCount) / Double(metrics.poolSize)

        // Count empty tiers
        metrics.emptyTierCount = distribution.values.filter { $0 == 0 }.count

        // Export metrics
        exportMetrics(metrics)

        headToHead.currentMetrics = nil
    }
}
```

---

### 5. Session Cancellation

**Location:** `AppState+HeadToHead.swift:cancelHeadToHead(fromExitCommand:)`
**Current code (line ~218-229):**

```swift
func cancelHeadToHead(fromExitCommand: Bool = false) {
    guard headToHead.isActive else { return }

    // ADD HERE (before resetHeadToHeadSession):
    if var metrics = headToHead.currentMetrics {
        metrics.endTime = Date()
        metrics.status = .cancelled
        exportMetrics(metrics)
        headToHead.currentMetrics = nil
    }

    resetHeadToHeadSession()
    // ...
}
```

---

### 6. Export Functionality

**Location:** `AppState+HeadToHead.swift` (new section)

```swift
// MARK: - Telemetry Export

private func exportMetrics(_ metrics: HeadToHeadSessionMetrics) {
    #if DEBUG
    // In DEBUG, always export to temporary directory
    exportMetricsToFile(metrics, directory: .temporaryDirectory)
    #else
    // In production, just log summary (future: add user opt-in)
    logMetricsSummary(metrics)
    #endif
}

private func exportMetricsToFile(_ metrics: HeadToHeadSessionMetrics, directory: FileManager.SearchPathDirectory) {
    do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(metrics)

        let fileManager = FileManager.default
        let directoryURL = try fileManager.url(
            for: directory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let filename = "headtohead_\(metrics.sessionId)_\(Int(metrics.startTime.timeIntervalSince1970)).json"
        let fileURL = directoryURL.appendingPathComponent(filename)

        try data.write(to: fileURL)

        Logger.headToHead.info("Exported metrics to \(fileURL.path)")
    } catch {
        Logger.headToHead.error("Failed to export metrics: \(error.localizedDescription)")
    }
}

private func logMetricsSummary(_ metrics: HeadToHeadSessionMetrics) {
    let summary = """
    HeadToHead Session Summary:
      SessionID: \(metrics.sessionId)
      Pool Size: \(metrics.poolSize)
      Target Comp/Item: \(metrics.targetComparisonsPerItem)
      Completed: \(metrics.totalComparisons)/\(metrics.plannedTotalComparisons)
      Skipped: \(metrics.skipCount) (\(String(format: "%.1f%%", metrics.skipRate * 100)))
      Duration: \(String(format: "%.1f", metrics.sessionDuration ?? 0))s
      Rate: \(String(format: "%.1f", metrics.comparisonsPerMinute ?? 0)) comp/min
      Status: \(metrics.status.rawValue)
      Max Tier: \(String(format: "%.1f%%", (metrics.maxTierFraction ?? 0) * 100))
    """
    Logger.headToHead.info("\(summary)")
}
```

**Export Locations:**

- **DEBUG builds:** `/tmp/headtohead_<sessionId>_<timestamp>.json`
- **Production builds:** Log summary only (no file I/O)

---

## State Changes Required

### HeadToHeadState.swift

Add two properties:

```swift
internal struct HeadToHeadState: Sendable {
    // ... existing properties ...

    // MARK: - Telemetry (NEW)

    /// Current session metrics (nil when no session active)
    var currentMetrics: HeadToHeadSessionMetrics?

    /// Whether to track detailed comparison events
    var trackComparisonEvents: Bool = {
        #if DEBUG
        true
        #else
        false  // Disable in production to reduce memory
        #endif
    }()
}
```

---

## Metrics Analysis Framework

### What to Measure

#### Primary Metrics (Must Track)

1. **Completion Rate**
   - Formula: `totalComparisons / plannedTotalComparisons`
   - Target: >80% for typical pools (10-25 items)
   - Red flag: <60%

2. **Skip Rate**
   - Formula: `skipCount / (totalComparisons + skipCount)`
   - Target: <25%
   - Red flag: >35%

3. **Session Duration**
   - Target: <5 minutes for 20-item pools
   - Red flag: >8 minutes (user fatigue)

4. **Max Tier Fraction**
   - Formula: `max(tierCounts) / poolSize`
   - Target: <40% (good distribution)
   - Red flag: >50% (clustering)

#### Secondary Metrics (Nice to Have)

1. **Comparisons Per Minute**
   - Expected: 2-4 comp/min
   - Useful for time estimation

2. **Empty Tier Count**
   - Expected: 0-2 empty tiers
   - Useful for distribution quality

3. **Think Time Distribution**
   - Detect fatigue (increasing think time)
   - Detect confusion (very long pauses)

#### Diagnostic Metrics (Advanced)

1. **Phase Transition Time**
   - How long in quick vs refinement?

2. **Skip Timing**
   - When do skips happen? (early, late, boundaries?)

3. **Comparison Event Patterns**
    - Are certain item pairs always skipped?

---

### Success Criteria by Pool Size

| Pool Size | Target Comp/Item | Planned Comparisons | Expected Duration | Success: Completion Rate | Success: Skip Rate |
|-----------|------------------|---------------------|-------------------|-------------------------|-------------------|
| 5-10 items | 3 | 15-30 | <2 min | >90% | <15% |
| 10-20 items | 4 | 40-80 | 3-5 min | >85% | <20% |
| 20-30 items | 5 | 100-150 | 5-7 min | >75% | <25% |
| 30-40 items | 6 | 180-240 | 7-10 min | >65% | <30% |
| 40+ items | 6 | 240+ | 10+ min | >60% | <35% |

**Interpretation:**

- **Above targets:** Current system works well
- **At targets:** Acceptable performance
- **Below targets:** Investigate specific issues

---

### Domain-Specific Expectations

Based on domain validation research (see DOMAIN_VALIDATION.md):

| Domain | Noise Level | Expected Skip Rate | Expected Completion Rate | Notes |
|--------|-------------|-------------------|------------------------|-------|
| **Movies** | 5% | <15% | >85% | High transitivity, strong consensus |
| **Games** | 10% | 15-25% | 75-85% | Genre conflicts acceptable |
| **Restaurants** | 15% | 20-30% | 70-80% | Context-dependent, higher skips OK |
| **Music** | 20% | 25-35% | 65-75% | Very subjective, expect struggle |

**Validation:**

- If movies show >20% skip rate → algorithm problem
- If music shows <30% skip rate → better than expected
- If any domain <60% completion → serious issue

---

## Analysis Workflow

### Step 1: Collect Data (2-4 weeks)

**Who:** Internal users, beta testers
**What:** Use HeadToHead with real tier lists
**How:**

1. Enable DEBUG builds (auto-export to /tmp)
2. Test across pool sizes (5, 10, 15, 20, 25, 30, 40 items)
3. Test across domains (movies, games, restaurants, music)
4. Encourage multiple sessions per user (measure re-run stability)

**Data to Collect:**

- Minimum 20 sessions per pool size bucket
- Minimum 10 sessions per domain
- Mix of completed and cancelled sessions

---

### Step 2: Analyze Metrics

**Export all JSON files:**

```bash
cp /tmp/headtohead_*.json ~/HeadToHeadSessionMetrics/
cd ~/HeadToHeadSessionMetrics
```

**Create analysis script:**

```python
# analyze_metrics.py
import json
import glob
from pathlib import Path
from statistics import mean, stdev

def load_metrics():
    files = glob.glob("headtohead_*.json")
    metrics = []
    for f in files:
        with open(f) as file:
            metrics.append(json.load(file))
    return metrics

def analyze_by_pool_size(metrics):
    buckets = {
        "5-10": [],
        "10-20": [],
        "20-30": [],
        "30-40": [],
        "40+": []
    }

    for m in metrics:
        size = m["poolSize"]
        if size < 10: buckets["5-10"].append(m)
        elif size < 20: buckets["10-20"].append(m)
        elif size < 30: buckets["20-30"].append(m)
        elif size < 40: buckets["30-40"].append(m)
        else: buckets["40+"].append(m)

    for bucket, sessions in buckets.items():
        if not sessions: continue

        completion_rates = [s["totalComparisons"] / s["plannedTotalComparisons"]
                           for s in sessions if s["plannedTotalComparisons"] > 0]
        skip_rates = [s["skipCount"] / (s["totalComparisons"] + s["skipCount"])
                     for s in sessions if s["totalComparisons"] + s["skipCount"] > 0]
        durations = [s.get("sessionDuration", 0) / 60 for s in sessions
                    if s.get("sessionDuration")]

        print(f"\n{bucket} items ({len(sessions)} sessions):")
        print(f"  Completion Rate: {mean(completion_rates):.1%} ± {stdev(completion_rates):.1%}")
        print(f"  Skip Rate: {mean(skip_rates):.1%} ± {stdev(skip_rates):.1%}")
        print(f"  Duration: {mean(durations):.1f} ± {stdev(durations):.1f} min")

# Run analysis
metrics = load_metrics()
print(f"Total sessions: {len(metrics)}")
print(f"Completed: {sum(1 for m in metrics if m['status'] == 'completed')}")
print(f"Cancelled: {sum(1 for m in metrics if m['status'] == 'cancelled')}")
analyze_by_pool_size(metrics)
```

---

### Step 3: Decision Tree

**If metrics look good:**

```text
Completion Rate >80%, Skip Rate <25%, Duration reasonable
↓
✅ Ship current system as-is
✅ Continue passive monitoring
✅ No optimization needed
```

**If high skip rate (>30%):**

```text
Skip Rate >30%, but Completion Rate OK
↓
⚠️ Pair selection may be suboptimal
→ Consider active-from-start warm-start (small change)
→ Run targeted simulation to validate
→ A/B test before full rollout
```

**If low completion rate (<60%):**

```text
Completion Rate <60%, high abandonment
↓
❌ Investigate root cause:
- Is duration too long? (reduce budget)
- Is pair selection bad? (high skips)
- Is UX confusing? (add progress indicators)
- Is domain too hard? (music, restaurants)
```

**If tier clustering (max fraction >50%):**

```text
Max Tier Fraction >50%, poor distribution
↓
❌ Algorithm issue (rare, not seen in simulation)
→ Check: Are items actually similar? (uniform distribution)
→ Check: Is noise too high? (>20%)
→ May need tier boundary adjustment
```

---

## Future Optimizations (Only If Justified by Data)

### Option A: Active-from-Start Warm-Start

**When:** High skip rate (>30%) detected
**Effort:** Low (1-2 days)
**Risk:** Low (same algorithm, different pair order)

**Change:**
Replace random fill in `initialComparisonQueueWarmStart` with uncertainty-driven sampling (same logic as refinement phase).

---

### Option B: Swiss-Style Seeding

**When:** Large pools (30+) show poor performance
**Effort:** Medium (3-5 days)
**Risk:** Medium (new initialization strategy)

**Change:**
For pools >25 items, use 3-round Swiss tournament instead of random warm-start.

---

### Option C: Explicit Anchor Items

**When:** Cold-start quality issues detected
**Effort:** High (1-2 weeks)
**Risk:** High (anchor selection, bias mitigation)

**Change:**
Select explicit anchor items (strong/mid/weak) and compare new items vs anchors first.

**Note:** Tier priors already provide anchor-like behavior, so this is low priority.

---

### Option D: Domain-Specific Hints

**When:** Music/restaurants show low completion
**Effort:** Low (UI changes only)
**Risk:** None (no algorithm changes)

**Change:**

- Add "Compare within genre first" toggle
- Add "Skip similar items" hint
- Add domain-specific progress messages

---

## Testing Checklist

Before considering telemetry complete, verify:

### Instrumentation

- [ ] `HeadToHeadSessionMetrics` struct created and compiles
- [ ] Post-session properties (`finalTierDistribution`, `maxTierFraction`, `emptyTierCount`, `domain`) are mutable (`var`)
- [ ] Session start logs sessionId and poolSize
- [ ] Comparisons increment quick/refinement counts correctly
- [ ] Skips increment skipCount and log events (if enabled)
- [ ] Session completion computes tier distribution
- [ ] Session cancellation marks status correctly
- [ ] Export works in DEBUG builds (JSON file in /tmp)
- [ ] Production builds log summary without file I/O

### Adaptive Budget Validation

- [ ] 5 items → targetComparisonsPerItem = 3
- [ ] 10 items → targetComparisonsPerItem = 3
- [ ] 15 items → targetComparisonsPerItem = 4
- [ ] 20 items → targetComparisonsPerItem = 4
- [ ] 25 items → targetComparisonsPerItem = 5
- [ ] 30 items → targetComparisonsPerItem = 5
- [ ] 40 items → targetComparisonsPerItem = 6

### Metrics Accuracy

- [ ] completionRate matches actual progress
- [ ] skipRate accurate
- [ ] sessionDuration reasonable (not 0.1s or 1000s)
- [ ] maxTierFraction computed correctly
- [ ] emptyTierCount accurate
- [ ] Metrics survive app backgrounding/foregrounding

### Edge Cases

- [ ] Session cancelled mid-comparison logs correctly
- [ ] App crash → next launch doesn't show stale metrics
- [ ] Multiple concurrent sessions (shouldn't happen, but handle gracefully)
- [ ] Very long sessions (100+ comparisons) don't run out of memory

---

## Implementation Timeline

### Phase 1: Core Telemetry (1-2 days)

1. Create `HeadToHeadSessionMetrics.swift` struct
2. Add `currentMetrics` property to `HeadToHeadState`
3. Add logging to 5 integration points
4. Implement export functionality
5. Test with DEBUG builds

### Phase 2: Production Testing (2-4 weeks)

1. Deploy DEBUG builds to internal users
2. Collect metrics across pool sizes and domains
3. Export and analyze JSON files
4. Identify any issues or patterns

### Phase 3: Decision & Optimization (1 week+)

1. Review metrics against success criteria
2. If good → ship production
3. If issues → targeted optimization
4. Re-test and validate

**Total Timeline:** 4-7 weeks from start to production decision

---

## Related Documentation

- **SIMULATION_FINDINGS.md** - Monte Carlo validation results (600+ runs)
- **HEADTOHEAD_OPTIMIZATION_SUMMARY.md** - Algorithm validation and recommendations
- **DOMAIN_VALIDATION.md** - Domain-specific analysis (movies, games, restaurants, music)
- **HeadToHead+Internals.swift** - Current algorithm implementation
- **AppState+HeadToHead.swift** - Session lifecycle management

---

## Questions & Answers

**Q: Why not implement telemetry now?**
A: Current system already validated by simulation. Telemetry should come before any optimization work, not immediately. Implement when ready to start production testing phase.

**Q: Can we skip telemetry and go straight to optimization?**
A: No. Without production data, you risk over-engineering solutions for non-existent problems. Telemetry is the cheapest form of validation.

**Q: How much data do we need?**
A: Minimum 20 sessions per pool size bucket (5-10, 10-20, 20-30, 30-40, 40+). More is better for statistical confidence.

**Q: What if metrics are borderline (e.g., 78% completion, target 80%)?**
A: Consider "good enough" and ship. Don't over-optimize. Users care more about UX polish than 2% statistical improvements.

**Q: Should we track user satisfaction?**
A: Yes, eventually. Post-session survey: "How confident are you in these results? (1-5)". But behavioral metrics (completion, re-run stability) are more objective.

**Q: What about privacy?**
A: Current design exports anonymous session data (no user IDs, no item names in metrics). Purely performance data. Still, add user opt-in for production exports if implementing file export.

---

## Contact

For questions about this specification, refer to the November 2025 HeadToHead optimization work and associated simulation results.

**Last Updated:** November 2025
**Next Review:** When ready to start production testing phase
