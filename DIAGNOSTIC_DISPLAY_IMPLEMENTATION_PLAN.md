# Diagnostic Display Implementation Plan

**Date:** 2025-10-25
**Based on:** Codex feedback regarding missing diagnostic display in acceptance tests

## Current State

Enhanced diagnostics are **captured** and **exported to JSONL**, but NOT **displayed** in acceptance test console output.

### What Works
- ✅ 8 diagnostic fields added to RunTelemetry struct
- ✅ Diagnostics tracked during uniqueList() execution
- ✅ Diagnostics exported via exportRunTelemetry()
- ✅ JSONL telemetry file contains all diagnostic data

### What's Missing
- ❌ Acceptance tests don't show per-seed diagnostics in console
- ❌ Early exceptions don't capture failure reasons
- ❌ Diagnostics stored as coordinator state (concurrency issue)

## Implementation Plan

### Phase 1: Expose Diagnostics from Coordinator

**File:** `AppleIntelligence+UniqueListGeneration.swift`

Add after `exportRunTelemetry()` method (line ~905):

```swift
/// Retrieve diagnostics from the last uniqueList() run
struct RunDiagnostics {
    let totalGenerated: Int?
    let dupCount: Int?
    let dupRate: Double?
    let backfillRounds: Int?
    let circuitBreakerTriggered: Bool?
    let passCount: Int?
    let failureReason: String?
    let topDuplicates: [String: Int]?
}

func getDiagnostics() -> RunDiagnostics {
    return RunDiagnostics(
        totalGenerated: lastRunTotalGenerated,
        dupCount: lastRunDupCount,
        dupRate: lastRunDupRate,
        backfillRounds: lastRunBackfillRounds,
        circuitBreakerTriggered: lastRunCircuitBreakerTriggered,
        passCount: lastRunPassCount,
        failureReason: lastRunFailureReason,
        topDuplicates: lastRunTopDuplicates
    )
}
```

### Phase 2: Update Acceptance Tests to Display Diagnostics

**File:** `AppleIntelligence+AcceptanceTests.swift`

Update `runAcrossSeeds()` function (lines 69-105):

```swift
private static func runAcrossSeeds(
    testId: String,
    query: String,
    targetN: Int,
    logger: @escaping (String) -> Void,
    makeCoordinator: () async throws -> UniqueListCoordinator
) async -> (passAtN: Double, medianIPS: Double, runs: [SeedRun]) {
    var runs: [SeedRun] = []

    for seed in SEED_RING {
        do {
            let coordinator = try await makeCoordinator()
            let t0 = Date()
            let items = (try? await coordinator.uniqueList(query: query, N: targetN, seed: seed)) ?? []
            let elapsed = Date().timeIntervalSince(t0)
            let ips = Double(items.count) / max(elapsed, 0.001)
            let ok = items.count >= targetN
            runs.append(SeedRun(seed: seed, ok: ok, ips: ips))

            // Capture diagnostics before export
            let diagnostics = coordinator.getDiagnostics()

            // Per-run telemetry export (append JSONL)
            coordinator.exportRunTelemetry(
                testId: testId,
                query: query,
                targetN: targetN
            )

            // Display diagnostics for failing seeds
            if !ok {
                logger("    ❌ Seed \(seed) FAILED: \(items.count)/\(targetN) items")
                if let reason = diagnostics.failureReason {
                    logger("       Reason: \(reason)")
                }
                if let dupRate = diagnostics.dupRate {
                    logger("       Duplicate rate: \(String(format: "%.1f%%", dupRate * 100))")
                }
                if let backfillRounds = diagnostics.backfillRounds {
                    logger("       Backfill rounds: \(backfillRounds)")
                }
                if let circuitBreaker = diagnostics.circuitBreakerTriggered, circuitBreaker {
                    logger("       Circuit breaker: triggered")
                }
            }
        } catch {
            runs.append(SeedRun(seed: seed, ok: false, ips: 0))
            logger("    ❌ Seed \(seed) EXCEPTION: \(error.localizedDescription)")
        }
    }

    let passAtN = Double(runs.filter { $0.ok }.count) / Double(SEED_RING.count)
    let medianIPS = median(runs.map { $0.ips })

    logger("🔎 \(testId): pass@N=\(String(format: "%.2f", passAtN))  per-seed=\(runs.map { $0.ok })  median ips=\(String(format: "%.2f", medianIPS))")

    return (passAtN, medianIPS, runs)
}
```

### Phase 3: Capture Failure Reasons in Exception Handlers

**File:** `AppleIntelligence+UniqueListGeneration.swift`

Update `uniqueList()` catch blocks to set failure reason before throwing:

```swift
// Around line 950-970 (initial generation catch block)
catch {
    logger("❌ Generation failed: \(error.localizedDescription)")

    // Set failure reason before rethrowing
    lastRunFailureReason = "Generation error: \(error.localizedDescription)"

    throw error
}

// Around line 990-1010 (guided backfill catch blocks)
catch {
    logger("⚠️ Guided backfill pass \(backfillRound) failed: \(error.localizedDescription)")

    // Set failure reason if not already set
    if lastRunFailureReason == nil {
        lastRunFailureReason = "Backfill error (pass \(backfillRound)): \(error.localizedDescription)"
    }

    // Continue with next attempt
}
```

## Expected Output After Implementation

### Console Output Example

```
[Test 4/8] Guided Backfill - verify guided fill mechanism across seed ring...
    ❌ Seed 42 FAILED: 46/50 items
       Reason: Circuit breaker: 2 consecutive rounds with no progress at 46/50
       Duplicate rate: 62.6%
       Backfill rounds: 3
       Circuit breaker: triggered
    ❌ Seed 1337 FAILED: 46/50 items
       Reason: Circuit breaker: 2 consecutive rounds with no progress at 46/50
       Duplicate rate: 62.6%
       Backfill rounds: 3
       Circuit breaker: triggered
    ✓ Seed 9999 PASSED: 50/50 items
    ❌ Seed 14830588230280405946 FAILED: 44/50 items
       Reason: Circuit breaker: 2 consecutive rounds with no progress at 44/50
       Duplicate rate: 74.4%
       Backfill rounds: 3
       Circuit breaker: triggered
    ❌ Seed 9072081274686410104 FAILED: 44/50 items
       Reason: Circuit breaker: 2 consecutive rounds with no progress at 44/50
       Duplicate rate: 74.4%
       Backfill rounds: 3
       Circuit breaker: triggered
🔎 T4_GuidedBackfill: pass@N=0.20  per-seed=[false, false, true, false, false]  median ips=2.15
  ⚠️ Guided backfill unreliable: only 1/5 seeds passed
```

## Future Enhancement: Function-Scoped Diagnostics

### Problem with Current Approach
Diagnostics are stored as coordinator instance variables (`lastRun*`), which means:
- Concurrent calls would trample each other's diagnostics
- Nested calls would lose outer diagnostic context
- Not thread-safe even with MainActor protection

### Solution: Pass Diagnostics as Parameter
Instead of storing diagnostics in the coordinator, return them from `uniqueList()`:

```swift
func uniqueList(query: String, N: Int, seed: UInt64? = nil) async throws -> (items: [String], diagnostics: RunDiagnostics)
```

This would require updating all call sites, so it's deferred to a future refactoring.

## Testing Strategy

1. Build with enhanced getDiagnostics() method
2. Run acceptance tests - verify console shows per-seed diagnostics
3. Intentionally break a test - verify exception path captures failure reason
4. Compare telemetry JSONL with console output - ensure consistency

## Success Criteria

✅ Console output shows detailed failure reasons for each failing seed
✅ Circuit breaker triggers are immediately visible
✅ Duplicate rates and backfill rounds shown inline
✅ Exception cases capture and display failure reasons
✅ No loss of existing JSONL telemetry functionality

## Rollout

1. Implement Phase 1 (getDiagnostics method)
2. Implement Phase 2 (acceptance test display)
3. Test and verify output
4. Implement Phase 3 (exception handling)
5. Final validation and commit
