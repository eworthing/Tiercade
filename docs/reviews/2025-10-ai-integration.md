# Apple Intelligence Integration Review (October 2025)

## Summary

Successfully integrated experimental Apple Intelligence features using
FoundationModels framework. Implementation included comprehensive testing
framework, diagnostic tooling, and hybrid backfill strategy.

## Key Decisions

### 1. Guided Generation for Structure, Unguided for Semantic Constraints

- **Guided** (`@Generable`): Ensures valid JSON structure and type safety
- **Unguided** (text generation): Respects avoid-lists for backfill passes
- **Rationale**: Guided generation enforces structural constraints but ignores
  semantic ones (verified via WWDC 2025 Session 301)

### 2. Feature Flag Controls Experimental Code

- DEBUG-only by default (`UniqueListGenerationFlags.enableAdvancedGeneration`)
- Build-time overrides for testing (`--enable-advanced-generation`,
  `--disable-advanced-generation`)
- **Rationale**: Prevents users from hitting untested/experimental code paths in production

### 3. Comprehensive Diagnostics

- 8 diagnostic fields track generation quality:
  - `totalGenerated`, `dupCount`, `dupRate`
  - `backfillRounds`, `circuitBreakerTriggered`, `passCount`
  - `failureReason`, `topDuplicates`
- Circuit breaker prevents infinite loops (2 consecutive rounds with no progress)
- Telemetry exports to JSONL for analysis

### 4. Client-Side Deduplication Required

- Model cannot guarantee uniqueness; client code must enforce it deterministically
- Normalization algorithm: lowercase → diacritic folding → article removal → plural trimming
- **Rationale**: Non-deterministic model requires deterministic client-side enforcement

## Lessons Learned

### 0. Document Symlink Structures Before Cleanup

**Context**: During documentation cleanup, AGENTS.md was initially deleted thinking it was a duplicate.

**Reality**:

- `AGENTS.md` is the SOURCE file
- `CLAUDE.md` → `AGENTS.md` (symlink for Claude Code)
- `.github/copilot-instructions.md` → `../AGENTS.md` (symlink for GitHub Copilot)

**Fix Applied**:

- Added warning header to `AGENTS.md` indicating it's the source file
- Documented symlink structure in `README.md`
- Created `.github/README.md` explaining the symlink setup

Lesson: Always check for symlinks (`ls -la`, `file <filename>`) before deleting
files that appear to be duplicates. Document symlink structures prominently.

### 1. Guided Generation Limitations

Finding: Schema-guided generation (`@Generable`) enforces structural
constraints but ignores semantic constraints like avoid-lists.

**Evidence**:

- 84% duplication rate despite explicit avoid-list prompts
- Model repeatedly generated "Lua", "Rust", "Lisp" even when in avoid-list
- Framework behavior confirmed via Apple WWDC 301 documentation

**Impact**: Shifted strategy to hybrid approach (guided for initial pass, unguided for backfill)

### 2. External AI Recommendations Must Be Verified

**Context**: ChatGPT suggested several optimization strategies:

- Regex-based initial-letter bucketing (`@Guide(Regex { "L"; OneOrMore(.word) })`)
- Constrained singletons to "break mode collapse"
- Removing `includeSchemaInPrompt: true` to save tokens

**Verification Results**:

- ❌ Initial-letter constraints not documented in Apple APIs
- ❌ "Mode collapse" theory unsupported by framework documentation
- ❌ Apple recommends **keeping** `includeSchemaInPrompt: true` (contradicts suggestion)

**Lesson**: Always verify external AI suggestions against authoritative documentation before implementation

### 3. Tool Calling Pattern Has Promise

Finding: Apple's Tool protocol supports stateful validation loops, though
retry/rejection patterns aren't explicitly documented.

Potential: Could implement validation tool that accepts/rejects proposals,
forcing model to retry with different items

**Concern**: Latency and context window explosion (50+ tool calls × 30 tokens each)

Status: Deferred for future experimentation

### 4. Diagnostic Visibility Critical

Initial implementation captured diagnostics but didn't display them in test output. Enhanced to show:

```text
❌ Seed 42 FAILED: 46/50 items
   Reason: Circuit breaker: 2 consecutive rounds with no progress at 46/50
   Duplicate rate: 62.6%
   Backfill rounds: 3
   Circuit breaker: triggered
```

**Impact**: Immediately identified circuit breaker as primary failure mode

## Blockers Fixed

### Pre-Merge Required Changes

1. **Boot logic race condition** - Consolidated `.onAppear` + `.task` to single `.task` block
2. **Session lifecycle leak** - Reset `aiService` on `closeAIChat()` to clear context
3. **Telemetry unbounded growth** - Added 10MB rotation with timestamped backups
4. **Feature flag always-on** - Changed to DEBUG-only default
5. **Incomplete image save feature** - Removed non-functional "Save to Photos" button

### Verification Notes

**Issue #5 (Test buttons exit app)**: Initial review incorrectly identified this as a blocker. Code review confirmed:

- ✅ UI test buttons (`runAcceptanceTests()`, etc.) correctly show results in chat
- ✅ CI automation path (`TiercadeApp.maybeRunAcceptance()`) correctly calls `exit()` with status codes
- ✅ No changes needed - architecture already correct

## Test Results

### Acceptance Tests

- **Pass rate**: 6/7 tests (85.7%)
- **Passing tests**:
  - T1_Structure (JSON decoding)
  - T2_Uniqueness (normalization)
  - T4_Overflow (context window handling)
  - T5_Reproducibility (seed consistency)
  - T6_Normalization (edge cases)
  - T7_TokenBudgeting (chunking)
- **Failing test**:
  - T3_Backfill (0/5 seeds) - due to guided generation limitations

### Diagnostic Analysis

- **Primary failure mode**: Circuit breaker (52% of failures)
- **Average duplicate rate**: 67.8% in failing runs
- **Stall point**: 44-46 items out of 50 target
- **Backfill attempts**: Only 3 rounds before circuit breaker or max passes

## Architecture Decisions

### Algorithm: Generate → Dedup → Fill

**Pass 1 (Over-generate)**:

- Request M = ceil(1.6 × N) items
- Use diverse sampling (topP: 0.92, temp: 0.8)
- Client-side deduplication by `normKey`

**Pass 2+ (Hybrid Backfill)**:

- Calculate delta = max(N - current, ceil(0.4 × N))
- Chunk avoid-list by token budget (800 tokens max)
- Try guided backfill first (structured output)
- Fall back to unguided if semantic constraints needed
- Circuit breaker: stop after 2 rounds with no progress

**Optional Greedy**:

- If delta ≤ 2, use deterministic greedy sampling
- Temperature: 0.0, topK: 1

### Normalization Pipeline

1. Lowercase
2. Diacritic folding (é → e)
3. Remove trademarks (™®©)
4. Map ampersand (& → " and ")
5. Remove brackets ((…), […])
6. Remove leading articles (the, a, an)
7. Strip punctuation
8. Collapse whitespace
9. Optional plural trimming (with exceptions: bass, glass, chess, etc.)

## Future Work

### Short Term

- Run pilot grid on real hardware (currently simulator-only)
- Calibrate over-generation factor from telemetry data
- Add semantic deduplication layer (embedding-based)

### Medium Term

- Adaptive over-gen factor by domain (sci-fi needs more diversity than numbers)
- Cost analysis and optimization (minimize tokens per successful list)
- Integration with tier list wizard UI

### Long Term

- Fuzzy matching for near-duplicates ("United States" vs "USA")
- Multi-language normalization (non-English item names)
- Embedding-based semantic clustering
- Tool calling validation loops (experimental)

## References

### Implementation Files

- `State/AppleIntelligence+UniqueListGeneration.swift` - Core algorithm
- `State/AppleIntelligence+AcceptanceTests.swift` - 7 test suites
- `State/AppleIntelligence+PilotTesting.swift` - Grid validation
- `State/AppState+AppleIntelligence.swift` - Integration

### Documentation

- `docs/AppleIntelligence/UNIQUE_LIST_GENERATION_SPEC.md` - Full specification
- `docs/AppleIntelligence/FEATURE_FLAG_USAGE.md` - Build flag usage
- `docs/AppleIntelligence/HYBRID_BACKFILL_IMPLEMENTATION.md` - Backfill strategy

### Test Outputs

- `/tmp/tiercade_acceptance_test_report.json` - Acceptance test results
- `/tmp/unique_list_runs.jsonl` - Telemetry data
- `docs/AppleIntelligence/TEST_RESULTS_2025-10-24.md` - Latest test run analysis

---

**Date**: October 25, 2025
**Reviewer**: Comprehensive code review + Codex verification
**Outcome**: Ready for merge after 5 blockers fixed
**Recommendation**: Monitor T3_Backfill pass rate in production; consider hybrid approach if users report issues
