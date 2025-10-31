# T4_GuidedBackfill Diagnostic Findings

**Date:** 2025-10-25
**Test:** T4_GuidedBackfill (50-item unique list generation with guided backfill)
**Result:** FAILED - 1/5 seeds passed (20% pass rate, target: 60%)

## Enhanced Diagnostic Implementation

Successfully implemented 8 new diagnostic fields in RunTelemetry:

- `totalGenerated`: Total items generated across all passes
- `dupCount`: Number of duplicate items detected
- `dupRate`: Duplicate rate (dupCount / totalGenerated)
- `backfillRounds`: Number of backfill rounds attempted
- `circuitBreakerTriggered`: Whether circuit breaker stopped generation early
- `passCount`: Total number of LLM passes made
- `failureReason`: Human-readable failure explanation
- `topDuplicates`: Top 5 most frequently duplicated items with counts

All fields are optional for backward compatibility with existing telemetry.

## Key Findings

### 1. Circuit Breaker Triggering (Primary Failure Mode)

**Frequency:** 16/31 test runs (52%) hit the circuit breaker

**Pattern:**

- Generation consistently stalls at 44-46 items out of 50 target
- Circuit breaker triggers after 2 consecutive rounds with no progress
- Typical failure message: `"Circuit breaker: 2 consecutive rounds with no progress at 46/50"`

**Example Cases:**

```text
Seed 42:    Circuit breaker at 46/50 (dupRate: 62.6%)
Seed 1337:  Circuit breaker at 46/50 (dupRate: 62.6%)
Seed 9999:  Circuit breaker at 44/50 (dupRate: 74.4%)
```

### 2. High Duplicate Rate

**Average:** 67.8% duplicates across all failing runs
**Range:** 22.2% - 77.3%

**Impact:**

- High duplicate rate exhausts the LLM's ability to generate novel items
- Each backfill round yields fewer and fewer unique items
- System gets stuck in a loop generating the same items repeatedly

**Top Duplicate Patterns:** (requires checking `topDuplicates` field for specific items)

### 3. Limited Backfill Attempts

**Typical Pattern:**

- Only 3 backfill rounds attempted before failure
- Total of 4 passes (1 initial + 3 backfill) before hitting max passes limit
- Circuit breaker often triggers before max passes reached

**Observation:**

Backfill is not getting enough attempts to overcome the duplicate problem
before either:

1. Circuit breaker stops generation (2 consecutive rounds with no progress)
2. Max passes limit is reached (currently 4 passes)

### 4. Incomplete Generation (Secondary Failure Mode)

**Frequency:** 15/31 test runs (48%) completed max passes but still incomplete

**Pattern:**

- Runs that don't hit circuit breaker still fail to reach 50 items
- Typical failure message: `"Incomplete: 34/50 items after 4 passes"` or `"Incomplete: 35/50 items after 4 passes"`
- Similar high duplicate rates (~70%)

**Example Cases:**

```text
Seed 1337:  Incomplete at 34/50 (dupRate: 70.9%, 4 passes)
Seed 123456: Incomplete at 35/50 (dupRate: 77.3%, 4 passes)
```

## Root Cause Analysis

The enhanced diagnostics reveal a **duplicate saturation problem**:

1. **Initial passes** generate items with some duplicates (20-30% duplicate rate)
2. **Backfill attempts** struggle to find new items, with duplicate rate climbing to 60-75%
3. **Circuit breaker** correctly identifies when the system is stuck (2 rounds with no progress)
4. **Max passes limit** (4 passes) is reached before 50 unique items are generated

The guided backfill system is functioning as designed, but the LLM is unable
to generate sufficient unique items within the current constraints.

## Discrepancies Noted

### itemsReturned vs Actual Count

The `itemsReturned` field in telemetry represents raw output from individual LLM
passes (before deduplication), not the final unique count. This explains why some
telemetry entries show:

- `itemsReturned: 68` or `itemsReturned: 54` (raw pass output)
- While `failureReason` reports `"35/50 items"` (actual unique count in `ordered` array)

This is expected behavior - `itemsReturned` reflects per-pass metrics, while
diagnostic fields (`failureReason`, etc.) reflect the final state after all
deduplication and backfill.

## Recommendations

Based on these findings:

### Short-term Fixes

1. **Increase max passes limit** from 4 to 6-8 to allow more backfill attempts
2. **Adjust circuit breaker threshold** from 2 to 3 consecutive no-progress rounds
3. **Implement backoff/retry with seed variation** to break duplicate loops

### Medium-term Improvements

1. **Dynamic duplicate detection** - analyze `topDuplicates` to identify when LLM is stuck on specific items
2. **Explicit avoidance prompting** - inject "avoid these items: ..." into backfill prompts
3. **Temperature ramping** - increase temperature on subsequent backfill rounds

### Long-term Enhancements

1. **Hybrid backfill strategy** - switch to unguided backfill when duplicate rate exceeds 70%
2. **Multi-model ensemble** - use different models for backfill to increase diversity
3. **Semantic clustering analysis** - identify when duplicate items are semantically equivalent but differently worded

## Testing Verification

✅ Enhanced diagnostics successfully capture:

- Circuit breaker trigger points
- Duplicate rates at failure
- Backfill round counts
- Top duplicate items
- Detailed failure reasons

❌ T4_GuidedBackfill test still fails:

- Current: 1/5 seeds pass (20%)
- Target: 3/5 seeds pass (60%)
- Gap: 2 additional passing seeds needed

## Next Steps

1. Implement one or more short-term fixes
2. Re-run acceptance tests to measure impact
3. Iterate on approach based on new diagnostic data
4. Document which seeds respond to which interventions
