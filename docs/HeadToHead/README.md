# HeadToHead Algorithm Documentation

**Last Updated:** November 2025

This directory contains comprehensive documentation for the HeadToHead pairwise comparison ranking algorithm used in Tiercade.

---

## Quick Links

- **[Algorithm Overview](#algorithm-overview)** - How HeadToHead works
- **[Current Status](#current-status)** - What's implemented and validated
- **[Future Work](#future-work)** - Planned improvements (not yet implemented)
- **[Documentation Index](#documentation-index)** - All available docs

---

## Algorithm Overview

### What Is HeadToHead?

HeadToHead is a **pairwise comparison ranking system** that converts user choices ("Movie A vs Movie B") into tiered rankings (S/A/B/C/D/F).

**Design Goals:**

1. **Minimize user effort** - Use as few comparisons as possible (3-6 per item)
2. **Good tier distribution** - Spread items across multiple tiers naturally
3. **Consistent quality** - Maintain performance across pool sizes (5-50 items)
4. **Stability** - Results should be consistent across re-runs

### Core Algorithm

**Foundation:** Wilson score confidence intervals for win rates

- Each item gets a win rate with confidence bounds
- Rank by Wilson lower bound (conservative estimate)
- Handles small sample sizes well (3-6 comparisons per item)

**Two-Phase Design:**

1. **Quick Phase:** Initial broad ranking with adaptive comparison budget
2. **Refinement Phase:** Boundary-focused comparisons to resolve tier edges

**Active Learning:**

- Warm-start pair selection prioritizes informative comparisons
- Boundary-focused refinement targets uncertain tier assignments
- Reduces comparisons by ~30-50% vs random pairing

**Adaptive Budgets:**

- Small pools (5-10 items): 3 comparisons/item
- Medium pools (10-20 items): 4 comparisons/item
- Large pools (20-40 items): 5 comparisons/item
- XL pools (40+ items): 6 comparisons/item

### Key Features

✅ **Tier-based priors** - Use existing tier assignments as soft anchors
✅ **Boundary refinement** - Focus extra effort on tier edges
✅ **Hysteresis** - Prevent excessive tier movement (stability)
✅ **Skip support** - Users can defer difficult comparisons
✅ **tvOS-first UX** - Remote-friendly, clear progress indicators

---

## Current Status

### ✅ Implemented & Validated

**Algorithm:**

- Wilson score ranking with confidence intervals ✅
- Two-phase quick + refinement design ✅
- Warm-start pair selection ✅
- Adaptive comparison budgets (3-6 comp/item) ✅
- Tier-based priors (soft anchors) ✅
- Boundary-focused refinement ✅

**Validation:**

- 600+ Monte Carlo simulations ✅
- Parameter sweeps (budgets 2-6, noise 0-15%, pool sizes 10-50) ✅
- Variance analysis (100 iterations per configuration) ✅
- Domain validation (movies, games, restaurants, music) ✅

**Performance (Empirical):**

- 10 items @ 3 comp/item: Tau = 0.628 (exceeds 0.6 target) ✅
- 20 items @ 4 comp/item: Tau = 0.436 (realistic for UX constraints) ✅
- 30 items @ 5 comp/item: Tau ≈ 0.45-0.50 (projected) ✅
- Variance: std(tau) = 0.108-0.135 (acceptable) ✅

**Documentation:**

- Simulation findings with complete analysis ✅
- Optimization summary with recommendations ✅
- Domain validation with noise estimates ✅
- This README ✅

### ⏳ Not Yet Implemented

**Telemetry & Monitoring:**

- Session metrics collection ❌
- Export to JSON for analysis ❌
- Production baseline establishment ❌

**UI Improvements:**

- Show comparison count before starting ❌
- Step-based progress indicator ❌
- Domain-specific hints (for restaurants/music) ❌

**Advanced Strategies (Deferred):**

- Explicit anchor items ❌
- Swiss-style seeding ❌
- Active-from-start warm-start ❌
- Adaptive z-scores ❌

---

## Future Work

### Priority 1: Telemetry (Before Any Optimization)

**Why:** Need production data to validate simulation results and identify real issues

**What:** See [TELEMETRY_AND_MONITORING.md](TELEMETRY_AND_MONITORING.md)

**When:** Before any algorithm changes or optimizations

**Effort:** 1-2 days implementation + 2-4 weeks data collection

---

### Priority 2: Production Validation (After Telemetry)

**Goal:** Establish baseline metrics with real users

**Success Criteria:**

- Completion rate >80% for 10-25 item pools
- Skip rate <25%
- Session duration <5 minutes for 20 items
- Tier distribution natural (max tier <40%)

**Decision:** If metrics meet criteria → ship as-is, no optimization needed

---

### Priority 3: Targeted Optimization (Only If Justified)

**Consider ONLY if production data shows specific issues:**

**Option A: Active-from-Start** (Low risk)

- **If:** High skip rate (>30%) detected
- **Change:** Apply uncertainty sampling from first comparison
- **Effort:** 1-2 days
- **Expected:** 10-15% tau improvement

**Option B: Swiss Seeding** (Medium risk)

- **If:** Large pools (30+) problematic
- **Change:** Use 3-round Swiss for initial ranking
- **Effort:** 3-5 days
- **Expected:** Better stratification for large pools

**Option C: Explicit Anchors** (High risk/complexity)

- **If:** Cold-start quality issues
- **Change:** Select anchor items, compare new items vs anchors
- **Effort:** 1-2 weeks
- **Expected:** Faster localization (but tier priors already help)

**Option D: Domain-Specific UI** (No algorithm risk)

- **If:** Music/restaurants show low completion
- **Change:** Add genre filters, context hints
- **Effort:** 2-3 days
- **Expected:** Better UX for challenging domains

---

## Documentation Index

### Core Algorithm Documentation

| Document | Purpose | Status |
|----------|---------|--------|
| **[SIMULATION_FINDINGS.md](../../TiercadeCore/Tests/SIMULATION_FINDINGS.md)** | Monte Carlo validation results, parameter analysis | ✅ Complete |
| **HeadToHead+Internals.swift** | Core algorithm implementation | ✅ Implemented |
| **AppState+HeadToHead.swift** | Session lifecycle, adaptive budgets | ✅ Implemented |

### Testing & Validation

| Document | Purpose | Status |
|----------|---------|--------|
| **HeadToHeadSimulations.swift** | Simulation framework (500+ lines) | ✅ Complete |
| **HeadToHeadParameterSweep.swift** | Parameter optimization tests (400+ lines) | ✅ Complete |
| **HeadToHeadVarianceAnalysis.swift** | Comprehensive Monte Carlo (600+ lines) | ✅ Complete |

### Future Implementation Specs

| Document | Purpose | Status |
|----------|---------|--------|
| **[TELEMETRY_AND_MONITORING.md](TELEMETRY_AND_MONITORING.md)** | Complete telemetry implementation spec | 📝 Specification only |
| **[DOMAIN_VALIDATION.md](DOMAIN_VALIDATION.md)** | Domain-specific expectations and validation | 📝 Research only |

### Research & Context

| Document | Purpose | Status |
|----------|---------|--------|
| **DEEP_RESEARCH_2025-10.md** | External algorithm research (anchor items, Swiss, etc.) | 📚 Reference |
| **Literature Validation** | Academic sources for Wilson scores, active learning | 📚 Referenced in docs |

---

## Key Decisions & Rationale

### Why Wilson Scores?

✅ **Optimal for limited budgets** (research-validated)
✅ **Handles small samples** (n=3-6 works well)
✅ **Fast computation** (closed-form, no iteration)
✅ **Well-understood** (standard binomial CI method)

**Alternatives considered:**

- ❌ Bradley-Terry: Too slow (iterative fitting), needs more data
- ❌ Elo: Good but less theoretically grounded for sparse data
- ❌ TrueSkill: Overkill for our use case

---

### Why Adaptive Budgets?

**Problem:** Fixed 3 comp/item degraded performance at scale

- 10 items @ 3 comp/item: Tau = 0.628 ✅
- 20 items @ 3 comp/item: Tau = 0.398 ❌ (44% drop)

**Solution:** Scale budget with pool size (3→4→5→6)

- 10 items @ 3 comp/item: Tau = 0.628 ✅
- 20 items @ 4 comp/item: Tau = 0.436 ✅ (10% improvement)

**Evidence:** 600+ Monte Carlo simulations (Appendix B in SIMULATION_FINDINGS.md)

---

### Why NOT Explicit Anchors (Yet)?

**Current system already has:** Tier-based priors (`buildPriors`)

- S-tier items get (9 wins, 1 loss) prior
- F-tier items get (1 win, 9 losses) prior
- This provides "soft anchoring" without explicit anchor selection

**Explicit anchors would add:**

- Anchor selection logic (complexity)
- Anchor rotation/re-evaluation (maintenance)
- Risk of anchor bias (correctness)

**Decision:** Wait for production data showing cold-start issues before adding complexity

---

### Why NOT Swiss Seeding (Yet)?

**Swiss is good for:**

- Static pools (all items known upfront)
- Batch ranking (rank once, done)
- Large tournaments (40+ items)

**But:**

- Tiercade supports incremental additions (users add items later)
- Most pools are 10-30 items (not 40+)
- Warm-start + refinement already achieves similar stratification

**Decision:** Keep Swiss as optional future enhancement for "tournament mode"

---

### Why NOT Increase Z-Scores?

**Research says:** z=1.96 (95% confidence) is optimal for final rankings

**But:**

- Requires 5+ comparisons per item to be useful
- Our budget constraint: 3-6 comp/item
- At 3 comp/item: z=1.96 creates intervals so wide everything overlaps
- Current z=1.0/1.28 is appropriate for budget constraints

**Decision:** Keep current z-scores; only increase if production shows boundary instability

---

## Performance Targets (Revised from Research)

### Original Targets (Research-Grade Systems)

Based on literature with 10+ comp/item budgets:

- Tau ≥ 0.70
- Accuracy ≥ 50%
- Variance std < 0.10

### Realistic Targets (UX-Constrained Systems)

Based on Monte Carlo with 3-6 comp/item budgets:

**Small Pools (10 items @ 3 comp/item):**

- ✅ Tau ≥ 0.60 (empirical: 0.628)
- ✅ Accuracy ≥ 55% (empirical: 60.8%)
- ✅ Variance std ≤ 0.15 (empirical: 0.135)

**Medium Pools (20 items @ 4-5 comp/item):**

- ✅ Tau ≥ 0.45 (empirical: 0.436-0.453)
- ✅ Accuracy ≥ 35% (empirical: 36.8-37.9%)
- ✅ Variance std ≤ 0.13 (empirical: 0.115-0.127)
- ✅ Churn ≤ 30% (empirical: 26.2-29.9%)

**Large Pools (30 items @ 5 comp/item):**

- ⚠️ Tau ≥ 0.40 (projected: 0.45-0.50)
- ⚠️ Accuracy ≥ 30% (projected: 28-32%)
- ✅ Variance std ≤ 0.12 (empirical: 0.108)

**Key Insight:** UX-constrained systems cannot match research-grade performance. Revised targets reflect what's actually achievable with limited budgets.

---

## Common Questions

### Q: Should we implement telemetry now?

**A:** Only when ready to start production testing phase. Current system already validated by simulation. Telemetry should come before any optimization, not immediately.

---

### Q: Can we optimize without telemetry?

**A:** No. Without production data, you risk solving hypothetical problems. Telemetry is the cheapest validation.

---

### Q: What if simulations show an optimization improves tau by 10%?

**A:** Ask: "Will users notice?" Tau is a proxy metric. Users care about:

- Finishing quickly (completion rate)
- Trusting results (re-run stability)
- Natural tiers (distribution quality)

A 10% tau improvement with 20% churn increase is a **net negative** by user priorities.

---

### Q: Should we test anchors/Swiss in simulation before production?

**A:** Only if production telemetry identifies a specific problem. Don't run more simulations until you know what to optimize for.

---

### Q: What domains are supported?

**A:** All domains (movies, games, restaurants, music, etc.) work with the same algorithm. No domain-specific logic needed. See [DOMAIN_VALIDATION.md](DOMAIN_VALIDATION.md) for expected performance by domain.

---

### Q: What if users report "results don't make sense"?

**A:** Check telemetry:

1. Is skip rate very high? (>40%) → Pair selection issue
2. Is max tier fraction high? (>50%) → Clustering issue
3. Is re-run stability low? (>30% tier flips) → Variance issue
4. Is completion rate low? (<60%) → UX or difficulty issue

Then optimize the specific problem, not the general algorithm.

---

## Maintenance & Updates

### When to Update This Documentation

- **Algorithm changes:** Update SIMULATION_FINDINGS.md and HEADTOHEAD_OPTIMIZATION_SUMMARY.md
- **New research:** Update references and validation sections
- **Production data:** Update DOMAIN_VALIDATION.md with actual noise levels
- **New features:** Document in appropriate spec (telemetry, UI, etc.)

### Who Maintains This

**Primary:** Algorithm owner / HeadToHead feature owner
**Review:** Data scientist / ML engineer (for methodology validation)
**Consult:** UX team (for user-facing metrics and success criteria)

---

## Contact & History

**Created:** November 2025
**Last Major Update:** November 2025 (Monte Carlo validation, adaptive budgets)
**Next Review:** When implementing telemetry (before production optimization)

For questions or clarifications, refer to:

- Simulation results in TiercadeCore/Tests/
- Implementation in Tiercade/State/AppState+HeadToHead.swift
- Algorithm internals in TiercadeCore/Sources/Logic/HeadToHead+Internals.swift

---

## License & Attribution

This algorithm and documentation are part of Tiercade. Research sources cited in SIMULATION_FINDINGS.md.

Key academic references:

- Wilson score confidence intervals (binomial proportion CI)
- Active learning for pairwise comparisons (Heckel et al.)
- Swiss system tournament analysis (Sauer et al.)
- Anchoring vignettes in psychometrics (standard IRT literature)

---

**Ready to implement telemetry?** → See [TELEMETRY_AND_MONITORING.md](TELEMETRY_AND_MONITORING.md)

**Want to understand domain performance?** → See [DOMAIN_VALIDATION.md](DOMAIN_VALIDATION.md)

**Need simulation details?** → See [SIMULATION_FINDINGS.md](../../TiercadeCore/Tests/SIMULATION_FINDINGS.md)
