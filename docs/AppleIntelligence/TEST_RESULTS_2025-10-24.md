# Acceptance Test Results - 2025-10-24

## Summary

**Result:** 6/7 tests passed (85.7%)
**Failed Test:** T3_Backfill (pass@N=0.00)

## Fixes Applied

### 1. Removed Candidate-Batch Backfill ✅

- **Location:** `AppleIntelligence+UniqueListGeneration.swift:673-758`
- **Removed:** 85 lines of candidate-batch backfill logic with seed rotation
- **Reason:** 88.7% duplication rate (ChatGPT's recommendation failed)

### 2. Fixed Test Report Export Paths ✅

- **Location:** `TiercadeApp.swift:120-129`
- **Changed:** Hardcoded `/tmp/` → `NSTemporaryDirectory()`
- **Reason:** Native macOS sandboxing prevents writing to `/tmp/`
- **Result:** Reports now successfully created in sandbox temp directory

### 3. Verified Normalization ✅

- Recursive article trimming works correctly
- "The A-Team" → "team" (removes both "the" and "a")

## Test Results

| Test | Status | pass@N | Seeds | Median IPS |
|------|--------|--------|-------|------------|
| T1_Structure | ✅ PASS | 1.00 | 5/5 | 1.51 |
| T2_Uniqueness | ✅ PASS | 0.60 | 3/5 | 1.66 |
| **T3_Backfill** | ❌ **FAIL** | **0.00** | **0/5** | 0.48 |
| T4_Overflow | ✅ PASS | 1.00 | - | - |
| T5_Reproducibility | ✅ PASS | 1.00 | - | - |
| T6_Normalization | ✅ PASS | 1.00 | - | - |
| T7_TokenBudgeting | ✅ PASS | 1.00 | - | - |

## Critical Finding: Negation Backfill Also Fails

After removing candidate-batch backfill, **negation backfill exhibits the same failure pattern**.

### Duplication Rates (Negation Backfill with Avoid-List)

| Seed | Items Generated | Duplicates Filtered | Dup Rate | Final Result |
|------|----------------|---------------------|----------|--------------|
| 42 | 131 | 109 | **83.2%** | 22/25 |
| 1337 | 187 | 152 | **81.3%** | 35/50 |
| 9999 | 212 | 176 | **83.0%** | 36/50 |
| 123456 | 214 | 185 | **86.4%** | 29/50 |
| 987654 | 299 | 259 | **86.6%** | 40/50 |

Average duplication rate: 84.1%

### Evidence: Model Ignores Avoid-List

Example from seed 987654 (programming languages):

**Pass 2-4 all generated the same 5 items:**

```text
[Dedup] Filtered: Ada → ada
[Dedup] Filtered: Lua → lua
[Dedup] Filtered: Lisp → lisp
[Dedup] Filtered: Perl → perl
[Dedup] Filtered: Nim → nim
```

Despite the avoid-list containing 40 items including
`["ada", "lua", "lisp", "perl", "nim"]`, the model
**repeatedly generates these exact same items** across multiple passes.

### Example from seed 9999 (programming languages)

**Pass 2-4 all generated:**

```text
[Dedup] Filtered: Rust → rust  (x4 per pass)
```

The model generated "Rust" **4 times consecutively** in each backfill pass,
even though "rust" was in the avoid-list.

## Root Cause Analysis

### Both Strategies Fail Identically

| Strategy | Avoid-List | Duplication Rate | Outcome |
|----------|-----------|------------------|---------|
| Candidate-Batch | ❌ NO | 88.7% | FAILED |
| Negation Backfill | ✅ YES | 84.1% | FAILED |

**Conclusion:** The avoid-list constraint is **not being enforced** by the model.

### Why This Happens

Apple's `@Generable` guided generation framework:

- ✅ **Enforces JSON schema structure** (validates shape, types, required fields)
- ❌ **Does NOT enforce semantic value constraints** (ignores "avoid these values" prompts)

When we tell the model:

```swift
let promptFill = """
Add 20 NEW items for: programming languages.
Do NOT include any with norm_keys in:
["ada", "lua", "lisp", "perl", "nim", /* ...40 items... */]
"""
```

The guided generation sees:

- ✅ "Return JSON matching UniqueListResponse schema" → **ENFORCED**
- ❌ "Do NOT include norm_keys in: [...]" → **IGNORED**

The model generates high-probability items (Ada, Lua, Rust, etc.) because
guided generation's constraint system **only validates structural
compliance**, not content semantics.

## Implications

### What Works

- **Small lists (N=10-15):** Single-pass generation with 1.6x over-generation succeeds
- **T1_Structure:** JSON decoding perfect (5/5 seeds, pass@N=1.00)
- **T2_Uniqueness:** 60% of seeds achieve full uniqueness in first pass
- **Normalization:** Edge cases handled correctly

### What Fails

- **Large lists (N=25-50):** Backfill required, both strategies fail
- **Multi-pass generation:** Model repeats high-probability items regardless of avoid-list
- **T3_Backfill:** 0% success rate across all 5 seeds

## Next Steps

### Options to Explore

1. **Remove `includeSchemaInPrompt: true`**
   - Hypothesis: Schema inclusion might be interfering with avoid-list processing
   - Try pure prompt-based guidance without schema in prompt

2. **Switch to Unguided Generation**
   - Remove `@Generable` macro entirely
   - Use pure text generation with manual JSON parsing
   - May lose structure validation but gain semantic constraint adherence

3. **Hybrid Approach: Guided Initial + Unguided Backfill**
   - Use `@Generable` for first pass (structure validation)
   - Switch to unguided generation for backfill passes (semantic constraints)

4. **Accept Framework Limitation**
   - Document that guided generation doesn't support avoid-lists
   - Adjust expectations: accept lower completion rates or smaller target sizes
   - File feedback with Apple (FB ID for FoundationModels team)

## Artifacts

- **Test Report:** `tiercade_acceptance_test_report.json` (2.1 KB)
- **Telemetry:** `unique_list_runs.jsonl` (58 lines)
- **Full Log:** `~/Library/Containers/eworthing.Tiercade/Data/tmp/test_stdout.log` (94 KB)
- **This Summary:** `TEST_RESULTS_2025-10-24.md`

## Files Modified

1. **AppleIntelligence+UniqueListGeneration.swift**
   - Removed candidate-batch backfill (lines 673-758)
   - Removed seed rotation helpers (lines 606-613)
   - Simplified to negation-only strategy

2. **TiercadeApp.swift**
   - Fixed report export paths (lines 120-129)
   - Now uses `NSTemporaryDirectory()` for native macOS compatibility
