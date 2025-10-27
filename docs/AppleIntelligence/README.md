# Apple Intelligence Experimental Feature

**Status**: Experimental / Proof of Concept
**Platforms**: iOS 26+, iPadOS 26+, macOS 26+ (native), visionOS 26+
**Framework**: FoundationModels

## Overview

Experimental integration of on-device Apple Intelligence for generating unique tier list items using schema-guided generation.

## Documentation

- **[Unique List Generation Spec](UNIQUE_LIST_GENERATION_SPEC.md)** - Complete specification and algorithm
- **[Feature Flag Usage](FEATURE_FLAG_USAGE.md)** - How to enable/disable advanced generation
- **[Hybrid Backfill Implementation](HYBRID_BACKFILL_IMPLEMENTATION.md)** - Current backfill strategy
- **[Test Results (2025-10-24)](TEST_RESULTS_2025-10-24.md)** - Latest acceptance test results
- **[Diagnostic Findings](T4_GUIDED_BACKFILL_DIAGNOSTIC_FINDINGS.md)** - T4 test analysis

## Known Issues & Limitations

### Retired Experiments

- **[Candidate-batch backfill](candidate_batch_analysis.md)** (88.7% duplication) -
  Abandoned approach that generated items without avoid-lists. Model repeatedly
  produced the same high-probability items despite client-side deduplication.

### Framework Limitations

Based on testing against Apple's FoundationModels framework and verification against WWDC 2025 Session 301:

- **Guided generation enforces structure, not semantics** - `@Generable` validates JSON schema but ignores avoid-list constraints
- **Semantic duplicates not detected** - "USA" vs "United States" are treated as different
- **High duplicate rates in backfill** - 60-75% duplication when requesting items similar to existing ones
- **ChatGPT proposals lacked documentation** - Regex bucketing and initial-letter constraints are not supported APIs

### Current Behavior

- Circuit breaker triggers at 44-46 items for N=50 targets (prevents infinite loops)
- Acceptance test pass rate: 6/7 tests (85.7%)
- T3_Backfill fails due to guided generation's inability to respect avoid-lists

## Feature Flag

Controlled via `UniqueListGenerationFlags.enableAdvancedGeneration`:

- **DEBUG builds**: Enabled by default
- **Release builds**: Disabled by default
- **Override**: Use `--enable-advanced-generation` or `--disable-advanced-generation`
  build flags

See [FEATURE_FLAG_USAGE.md](FEATURE_FLAG_USAGE.md) for details.

## Testing

Run acceptance tests:

1. Build native macOS: `./build_install_launch.sh macos`
2. Open AI Chat (sparkles button)
3. Click green checkmark for acceptance tests
4. Results in `/tmp/tiercade_acceptance_test_report.json`

**Expected**: 6/7 tests pass (T3_Backfill known to fail)

## Architecture

**Algorithm**: Generate → Dedup → Backfill

1. **Pass 1**: Over-generate (M = ceil(1.6 × N)) with diverse sampling
2. **Client Dedup**: Normalize and filter by `normKey` (first appearance wins)
3. **Pass 2+**: Hybrid backfill (guided then unguided) with avoid-list, max 3 passes
4. **Optional**: Greedy fallback if delta ≤ 2

See [UNIQUE_LIST_GENERATION_SPEC.md](UNIQUE_LIST_GENERATION_SPEC.md) for full details.

## Future Work

- Semantic deduplication layer using embeddings
- Adaptive over-generation factor by domain
- Tool calling for validation loops (experimental)
- Multi-model ensemble for diversity
