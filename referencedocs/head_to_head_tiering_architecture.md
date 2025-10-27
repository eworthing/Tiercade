# Head-to-Head Tiering Architecture

<!-- markdownlint-disable MD013 -->

This document captures the architecture, evolution, and design rationale of Tiercade's head-to-head (H2H) ranking system. It is intended to help future maintainers and LLM copilots understand how the algorithm works, why the current guardrails exist, and what constraints guided the latest iterations.

## High-Level Goals

1. **Accuracy with low effort** – approximate a careful manual tier ranking using as few comparisons as practical.
2. **Authenticity** – results should match user expectations. Undefeated players should land with other undefeateds, and clear bottom performers should cluster together.
3. **Stability** – refinement should only override the quick-pass quantile cuts when the evidence is strong; when the data swings wildly we fall back to the safe baseline.

## Architectural Overview

### Code layout

- `Tiercade/State/AppState+HeadToHead.swift` drives the UI-facing state machine: queue management, match recording, and transitions between quick and refinement phases.
- `TiercadeCore/Sources/TiercadeCore/Logic/HeadToHead.swift` houses the deterministic logic. Everything described below lives here unless otherwise noted.

### Stage 0 – Pool construction

When the user starts H2H (`AppState.startH2H`):

1. Build the pool from the active tier list:
   - Include all items from the special "unranked" tier and every **unlocked** named tier (locked tiers remain untouched during H2H).
   - Locked tiers still contribute priors (see below) but their members are excluded from the voting pool.
2. Compute a per-item target via `quickPhaseTargetComparisons`:
   - Pools ≥ 10 members: target 3 comparisons per item.
   - Pools 6–9 members: target 3 comparisons.
   - Pools ≤ 5 members: target 2 comparisons (cannot exceed `poolCount - 1`).
3. Warm-start the queue (`initialComparisonQueueWarmStart`) so early comparisons
   focus on likely boundaries. The warm-start uses current tier positions and
   priors to propose high-information pairs first.

### Stage 1 – Quick phase

During the quick pass the user works through the warmed queue:

- `voteH2H` records the winner, increments `h2hCompletedComparisons`, and runs `HeadToHeadLogic.vote` to update Wilson statistics.
- Deferred/ skipped pairs (`h2hDeferredPairs`) are recycled automatically once the queue empties.
- After the queue drains we run `HeadToHeadLogic.quickTierPass`:

 1. Partition the pool by comparisons. Items with fewer than
    `Tun.minimumComparisonsPerItem` (currently 2) are treated as undersampled
    and assigned to "unranked" in the provisional result.
 2. Construct priors per item (quick pass only). For each tier index *i*
     (0-based) we compute a prior mean `priorMeanForTier(tierName, i,
     totalTierCount)`. We convert that mean into a Beta distribution with
     strength 6 (equivalent to six virtual matches):
     - `alpha = mean * strength`
     - `beta  = (1 - mean) * strength`
     - These priors feed into Wilson scores in quick pass, letting previously higher-tier members start with a mild advantage.
 3. Compute Wilson lower/upper bounds using z = `Tun.zQuick` (1.0) and the
     priors above. `orderedItems` sorts descending by lower bound, then by
     comparisons, wins, and finally a lowercase name key for deterministic
     order.
 4. Apply quantile cuts via `quantileCuts(count, tierCount)`. For tier count *k* we compute `round(i * n / k)` (nearest integer) for `i = 1...(k-1)` and deduplicate the cut list to keep them strictly increasing. Example: `n=12`, `k=6` → `[2,4,6,8,10]`.
 5. Assign items to tiers using these cuts and sort members within each tier by Wilson lower bound (`sortTierMembers`).
 6. If no refinement pairs are requested (`H2HArtifacts.suggestedPairs` empty), we finalize immediately; otherwise we transition to refinement.

### Stage 2 – Refinement

When suggested refinement pairs exist, `finishH2H` reruns with
`HeadToHeadLogic.finalizeTiers`:

1. Recompute metrics with z = `Tun.zStd` (1.28). If the average comparisons per item is < 3, we temporarily fall back to z = 1.0 (`zRefineEarly`) to keep early intervals wide.
2. `refinementPairs` builds targeted comparisons:
   - Always enqueue the top boundary comparisons via `topBoundaryComparisons` (pairs `(rank2, rank3)` and optionally `(rank1, rank3)` when Wilson lower bounds are within `Tun.epsTieTop = 0.012`).
   - Always enqueue the bottom boundary comparisons via `bottomBoundaryComparisons` (pairs `(rankN-1, rankN)` plus `(rankN-2, rankN)` when Wilson upper bounds are within `Tun.epsTieBottom = 0.010` or both ≤ `Tun.ubBottomCeil = 0.20`).
   - Enqueued pairs are deduplicated via a symmetric pair key.
   - Remaining frontier comparisons are scored using:
     - `delta = max(0, LB(u) - UB(l)) + overlapEps`, where `LB/UB` are Wilson bounds of adjacent items `u` and `l`.
     - `conf = min(c_u, c_l) + Tun.confBonusBeta * max(c_u, c_l)` where `c` is the total comparisons for each item.
     - `score = delta * log1p(max(conf, 0))`
     - `overlapEps` is 0 until warm-up requirements are met, then becomes `Tun.softOverlapEps = 0.010` to treat slight overlaps as weak evidence.
   - `minWilsonRangeForSplit = 0.015` prevents filler from slicing almost-flat segments.
3. Once the extra comparisons finish, we call back into `finalizeTiers` to compute the final placements.

### Stage 3 – Final placement

The final tier assignment uses the refined metrics and the same `orderedItems` sort mentioned above. We then:

1. Compute provisional cuts:
   - `quantCuts` uses the same rounded positions as the quick pass.
   - `primaryCuts` comes from `dropCuts`, which sorts by gap score (`delta`, `conf` as above).
   - `mergeCutsPreferRefined` fills missing gaps while retaining them in ascending order.
2. Elastic top cut:
   - `topBoundaryComparisons` ensures fresh data exists.
   - If the first items share identical lower bounds within `epsTieTop`, we slide the first cut so the entire tied block remains together.
3. Elastic bottom cut:
   - `bottomClusterStart` walks upward from the final item looking for a block (max width `Tun.maxBottomTieWidth = 4`) whose Wilson upper bounds are tied (`<= epsTieBottom`) or clearly weak (`<= ubBottomCeil`), and whose members have adequate data (implicit because we already forced the comparisons).
   - If a cluster exists and does not cross the previous cut, the last cut is replaced with the cluster start, ensuring obvious bottom performers land together.
4. Churn/hysteresis guard:
   - `churnFraction` measures the share of items whose tiers would change if we adopted the refined cuts instead of the quantile ones.
   - We only accept the refined cuts when:

- Total decisions (match outcomes) ≥ `artifacts.warmUpComparisons` (computed as
  `max(ceil(1.5 * ordered.count), 2 * tierCount)`).
- `churn` ≤ `Tun.hysteresisMaxChurnSoft = 0.12`, or ≤ `Tun.hysteresisMaxChurnHard * ramp`, where
  `Tun.hysteresisMaxChurnHard = 0.25`, `Tun.hysteresisRampBoost = 0.50`, and
  `ramp = min(1, decisions / warmUpComparisons * Tun.hysteresisRampBoost)`.
  - If churn exceeds this gating (e.g., 0.58 in the logs), or decisions are below warm-up, we fall back to the quantile cuts.

1. The final tiers are sorted by Wilson lower bound and saved. Undersampled
   members (comparisons below `minimumComparisonsPerItem`) remain in
   "unranked".

### Tie-breaking order

`orderedItems` uses a stable comparator to keep results deterministic:

1. Wilson lower bound (descending)
2. Total comparisons (descending)
3. Total wins (descending)
4. `nameKey` (case-insensitive name) ascending
5. `id` ascending

Direct head-to-head outcomes are not used as a secondary tie break (comparisons are typically insufficient); the forced top/bottom probes give us the data we need to differentiate tied clusters.

### Quantile example

For 12 rankable items and 6 tiers, `quantileCuts` yields `[2, 4, 6, 8, 10]`:

```text
index:    0  1 | 2  3 | 4  5 | 6  7 | 8  9 | 10 11
cut #:        1    2    3     4     5
```

These cuts are the baseline. Refinement only shifts boundaries when gap scores and churn checks allow it.

## Tunables summary

| Constant | Value | Notes |
|----------|-------|-------|
| `minimumComparisonsPerItem` | 2 | Items below this threshold are undersampled. |
| `frontierWidth` | 2 | Span above/below a cut when proposing frontier pairs. |
| `zQuick` | 1.0 | Wilson z-score during the quick pass. |
| `zStd` | 1.28 | Wilson z for refinement (falls back to 1.0 when average comparisons < 3). |
| `softOverlapEps` | 0.010 | Allows small positive gaps once warm-up completes. |
| `confBonusBeta` | 0.10 | Weighted bonus for gap scoring when one neighbor has many comparisons. |
| `maxSuggestedPairs` | 6 | Minimum size for the refinement queue (often increased by elastic probes). |
| `hysteresisMaxChurnSoft` | 0.12 | Accept refined cuts when churn <= 12%. |
| `hysteresisMaxChurnHard` | 0.25 | Hard cap after warm-up; ramped by comparisons. |
| `minWilsonRangeForSplit` | 0.015 | Guard against filler splitting flat segments. |
| `epsTieTop` | 0.012 | Treat Wilson lower bounds within this delta as tied at the top. |
| `epsTieBottom` | 0.010 | Treat Wilson upper bounds within this delta as tied at the bottom. |
| `maxBottomTieWidth` | 4 | Max members pulled into the elastic bottom cluster. |
| `ubBottomCeil` | 0.20 | Items with UB below 20% are considered clearly weak. |

(There is no explicit `maxTopTieWidth`; because we only slide the first cut when the tied cluster is contiguous and the quick pass already gives each tier two members, we have not needed a cap. If future data shows large top clusters, a similar tunable can be added.)

## Edge cases & determinism

- **Locked tiers** – Their members are excluded from the pool but still contribute priors. They remain untouched through the session.
- **Pool smaller than tier count** – Quantile cuts deduplicate automatically; empty tiers remain empty.
- **All players tied** – Without gap scores, `mergeCutsPreferRefined` falls back to the quantile structure; elastic cuts only run when tied clusters are continuous and do not cross previous boundaries.
- **Undersampled items** – Items with comparisons < `minimumComparisonsPerItem` stay in "unranked" after quick pass and refinement.
- **Determinism** – Wilson computations use double precision and deterministic rounding; the comparator always uses the same tie-break chain, so repeated runs with identical data yield the same order.

## Key Iterations (Oct 2025)

1. Added `[Tiering]` logs and per-player metrics to expose Wilson gaps and churn decisions.
2. Enforced top boundary probes and elastic top tiers so undefeated players aren’t split from their peers.
3. Raised `minWilsonRangeForSplit` to restrict filler splits to meaningful segments.
4. Added bottom boundary probes and elastic bottom tiers to cluster weak performers.
5. Increased quick-phase comparisons for pools ≥ 10 so intervals tighten faster.

## Interpreting Logs

- `[AppState] startH2H` – Reports pool size, quick target, and initial queue length.
- `[AppState] nextH2HPair` / `voteH2H` – Show the order of comparisons; the first pairs in refinement will be the forced top/bottom probes.
- `[Tiering] finalize …` – Lists per-item wins, comparisons, Wilson lower/upper bounds, and `zRefine` in use.
- `[Tiering] quantCuts=… refinedCuts=…` – Reveals how elastic cuts shifted from the baseline.
- `[Tiering] churn=… useRefined=…` – Indicates whether refined cuts were accepted or quantiles were used.

## Future-proofing

- Avoid layering additional sticky state unless logs reveal oscillation around the existing hysteresis thresholds.
- For new game modes with larger pools or unbalanced data, revisit `epsTieTop`, `epsTieBottom`, `ubBottomCeil`, and `frontierWidth`.
- Surface "provisional" badges in the UI using the metrics already logged to help users interpret low-confidence tiers.

## References

- `TiercadeCore/Sources/TiercadeCore/Logic/HeadToHead.swift`
- `Tiercade/State/AppState+HeadToHead.swift`
- Debug runs captured in `/tmp/tiercade_debug.log`
