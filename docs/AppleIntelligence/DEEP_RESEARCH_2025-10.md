# Consolidated Deep Research (October 2025)

Unique-List Generation with Apple Intelligence Foundation Models (iOS/macOS 26+)

---

## Executive summary
- What works: Guided generation (@Generable) gives structural guarantees (valid JSON/typed Swift) with excellent parse reliability.
- What doesn’t: Guided decoding can’t enforce semantic constraints like “avoid these items” or “no duplicates.” Client-side uniqueness is non-negotiable.
- API reality: GenerationOptions exposes sampling (greedy/top-k/top-p), temperature, seed, and must set maximumResponseTokens on every call; there are no repetition/frequency/presence penalties.
- Context: The on-device model runs inside a strict 4,096-token context per LanguageModelSession. Overflow throws `.exceededContextWindowSize`; you recover by recreating the session.
- Architecture that passes: Generate → Dedup → Backfill, with hybrid backfill (start guided; switch to unguided text when duplication saturates), avoid-list chunking, strict token budgeting, circuit-breaker, and greedy last-mile.
- Escalation: Only when the on-device path stalls or diversity is starved, escalate to Private Cloud Compute (PCC)—document privacy guarantees and keep developer-visible guardrails.

---

## 1) Foundation Models: capabilities, limits, and precise APIs

### 1.1 Sessions, responses, and errors
- State & lifecycle. LanguageModelSession is the entry point; transcripted, stateful interactions accumulate toward the context limit. Use `prewarm(promptPrefix:)` to cut first-token latency. On overflow you’ll get `GenerationError.exceededContextWindowSize`. Recreate the session and retry with trimmed context.
- Instruments. Use the Foundation Models instrument in Xcode to read input/output token counts, prompt time, and total response time on real devices (simulator token counts aren’t reliable).

### 1.2 Guided generation: structure ≠ semantics
- Guarantee. With `@Generable`, the framework performs constrained decoding to emit values that conform to your Swift type/schema (valid JSON, typed fields). It does not guarantee uniqueness, novelty, or adherence to an avoid-list.
- Correct overloads (important).
  - For `@Generable` types: `respond(to:generating:includeSchemaInPrompt:options:)`.
  - For dynamic schemas: `respond(to:schema:includeSchemaInPrompt:options:)` (pass a `GenerationSchema`).
  Use the `generating:` form for typed `@Generable` outputs; use `schema:` only when assembling schemas at runtime.
- Schema prompt injection. `includeSchemaInPrompt` defaults to true and should remain enabled for the first call with a given type to maximize format reliability.

### 1.3 Generation controls actually available
- Sampling: `.greedy`, `.random(top:seed:)` (top-k), `.random(probabilityThreshold:seed:)` (top-p).
- Other knobs: `temperature`, `maximumResponseTokens`, `seed`.
- Not available: repetition/presence/frequency penalties (use client-side dedup + prompt tactics).

### 1.4 Context window & budgeting
- Budget. Treat 4,096 tokens as the hard envelope for everything the session processes (see TN3193). In practice, plan combined prompt+response budgeting and validate on device with the Foundation Models instrument. Overflow raises `.exceededContextWindowSize`.

---

## 2) Why duplication happens (and why the client must enforce uniqueness)
- Guided decoding masks invalid tokens by structure; avoid-lists are semantic text instructions with no hard constraint → duplicates rise as the avoid-list grows.
- Long-context effects (“lost in the middle”) and small-model repetition dynamics further increase repeats as runs progress.

Consequence: Enforce uniqueness on the client (normalization + set semantics). Use architecture to reduce duplication (prompting, sampling profiles), but never rely on the model to guarantee it.

---

## 3) Definitive architecture (Generate → Dedup → Backfill), with hybrid backfill

### 3.1 Pass-by-pass design

Pass 1 — Guided, over-generation
- Goal: Max unique items early with structural reliability.
- Call: `respond(to:… generating: ArrayWrapper.self, includeSchemaInPrompt:true, options: diverse)`; over-generate 1.5–1.6× N; normalize + set-dedup.

Backfill Loop — Hybrid switch
- Default attempt: guided backfill with updated avoid-list (chunked).
- Switch to unguided when either: dupRate ≥ 0.70 in a round or two consecutive “no-progress” rounds (empirical policy). Then use free-text `respond(to:options:)` that asks for a JSON array only and parse leniently (extract first `[...]`, then decode).
- Unguided parsing: tolerate trailing text, missing commas/brackets (sanitize then decode).
- Adaptive tokens: start `maxTokens ≈ max(160, 16×k)`; ×1.8 on parse failure; cap ≈ 512. (Policies are field-validated; not Apple-specified. Validate with your harness.)

Last-mile — Greedy
- When ≤ 2 items remain, use `.greedy` with tight `maximumResponseTokens` for deterministic, low-latency completion.

### 3.2 Avoid-list chunking & placement
- Chunk the avoid-list to fit budget; place it near the end of the prompt (recency helps adherence). Validate by profiling token counts with Instruments and catching overflow.

### 3.3 Circuit-breaker & retries
- Closed → Open → Half-open with short cool-down (e.g., 1–2 s). Trip on extreme dupRate (e.g., ≥ 0.85) or 3× no-progress. Probe once in half-open; fully close on success. (General CB pattern).
- Session hygiene: recreate session after context error or ≥ 2 consecutive failures; optionally `prewarm(promptPrefix:)` after recreation.

---

## 4) Token budgeting & session policy (hard requirements)
- Always set `maximumResponseTokens` on every call to bound latency and avoid accidental over-long generations.
- Plan combined budget: instructions + schema (first call) + avoid-list + expected response.
- Overflow handling: catch `.exceededContextWindowSize`, recreate the session, and continue with shorter context (or split backfill across micro-batches).

---

## 5) Sampling profiles on Apple silicon (on-device)

Profiles (defaults):
- `.diverse`: top-p 0.92 (or top-k ≈ 50 if top-p unavailable), temperature 0.8 → Pass 1.
- `.controlled`: top-k ≈ 40, temperature 0.7 → Backfill rounds.
- `.greedy`: temperature 0 → ≤ 2 items remaining.

Performance measurement: Use the Foundation Models instrument (IPS, p95 latency, token counts) on an A-series iPhone and M-series Mac to calibrate budgets and round counts.

---

## 6) Private Cloud Compute (PCC): decision rules & privacy

When to escalate (guardrails):
- Persistent stalls: Multiple circuit-breaker trips for a single request.
- Diversity starvation: Very low unique yield after several rounds despite parameter ramps.

Privacy & verification: PCC runs on custom Apple Silicon servers with an auditable software stack; requests are ephemeral, end-to-end encrypted, and stateless. Apple provides a Virtual Research Environment and publishes select PCC components (e.g., CloudAttestation, Thimble) for independent analysis.

Implementation note: Third-party app access/routing between on-device and PCC is platform-governed; design your escalation policy and telemetry now, then wire API hooks as Apple exposes them.

---

## 7) Small-model optimization playbook (context & expectations)
- Apple’s on-device model (~3B parameters) is heavily compressed (quantization, architectural memory savings) for ANE/GPU efficiency; expect strong short-form generation but limited raw diversity vs. server-class MoE. Use architecture to compensate.
- On Macs, ML workloads (e.g., MLX) can leverage GPU/unified memory for throughput; still profile with Foundation Models Instruments for end-to-end app behavior.

---

## 8) Deliverables (ready to hand to a coding agent)

### 8.1 Capability table (guided vs. unguided)

| Capability | Guided (@Generable) | Unguided (raw text) |
|---|---|---|
| JSON validity | High (schema-constrained decoding) | Variable; requires lenient parsing |
| Semantic uniqueness / avoid-list | Weak (instructions only) | Stronger adherence (fewer duplicates) |
| Token cost | Higher (schema included on first use) | Lower (no schema tokens) |
| Error modes | `.decodingFailure` rare; duplication at saturation | Parse failures; occasional off-topic strings |
| Best use | Pass 1, early backfill | Late backfill after saturation |

(Structural guarantees from guided gen; semantic uniqueness remains your job.)

### 8.2 Backfill policy (production)
1. Start guided backfill with avoid-list chunked to fit budget.
2. Switch to unguided when dupRate ≥ 0.70 or after two no-progress rounds.
3. Lenient parse + seed rotation + temperature ramp (≤ 0.9).
4. Greedy last-mile for ≤ 2 items.

(2)–(3) are empirical defaults—validate with your harness; they’re not Apple-documented.

### 8.3 Feature-flag test matrix (empirical)
- Default: DEBUG = enabled; Release = disabled.
- Forced enable / forced disable variants for CI to prove new vs. legacy paths.

### 8.4 Risk table (selected; empirical thresholds)
- Schema-valid duplicates (guided): handled by hybrid switch.
- Unguided parse failures: mitigate via lenient parsing + adaptive tokens.
- Circuit-breaker sensitivity: tune on telemetry; cap cool-downs.
- PCC over-escalation: conservative triggers; audit via telemetry.
- Context thrash: recency-biased avoid-list chunking; recreate sessions on overflow.

---

## 9) Implementation notes (Swift 6 / FoundationModels)

Use the correct guided overload for `@Generable`:

```swift
// Typed, guided generation (preferred for Pass 1)
let result = try await session.respond(
  to: Prompt(taskPrompt),
  generating: StringList.self,
  includeSchemaInPrompt: true,
  options: GenerationOptions(
    sampling: .random(probabilityThreshold: 0.92, seed: seed),
    temperature: 0.8,
    maximumResponseTokens: maxTok
  )
)
```

(Use `respond(to:schema:…)` only when you build a `GenerationSchema` dynamically.)

Unguided backfill sketch (lenient parse + adaptive tokens):

```swift
// 1) Compose concise prompt with avoid-list chunk at end; ask for JSON array ONLY
// 2) session.respond(to: Prompt(text), options: opts)   // NOTE: no `generating:`
// 3) Extract first [...] span; sanitize; JSON-decode [String]
// 4) Dedup via normalization; rotate seed or bump temp on high dupRate
```

Overflow recovery:

```swift
do {
  _ = try await session.respond(to: prompt, options: opts)
} catch let e as LanguageModelSession.GenerationError {
  if case .exceededContextWindowSize = e {
    session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
    // Trim avoid-list; reduce schema/prompt; retry
  }
}
```

---

## 10) Normalization & dedup (contract)
- Lowercase → diacritics → strip leading articles → drop (…) / […] → &→“and” → strip ™®© → collapse punctuation/whitespace → trim.
- Apply to every candidate; dedup on the normalized key; keep first occurrence.

---

## 11) Instrumentation & KPIs
- Attempt-level telemetry: attemptIndex, seed, samplingKind, temperature, sessionRecreated, itemsReturned, elapsedSec.
- Run-level: testId, query, targetN, pass index, OS version, attempts[].
- Primary KPI: pass@N ≥ 0.6 at N = 50 across a 5-seed ring.
- Secondary: dupRate (Pass 1 ≤ 25%), JSON-validity ≥ 95%, p95 latency in budget, ≤ 1 circuit-breaker per successful run.
- How to measure: Use the Foundation Models instrument for tokens/latency; write per-attempt JSONL to the sandbox temp directory (Catalyst).

---

## 12) Experiment plan (A/B/C/D)

Grid: N ∈ {15, 50, 150}; Seeds: 5; Profiles: `.diverse`, `.controlled`, `.greedy`; Devices: one A-series iPhone + one M-series Mac.

Treatments:
- A – Guided baseline: Pass 1 over-gen 1.6×N; guided backfill; record expected stall 44–46/50 on some seeds (dup telemetry).
- B – Hybrid switch: Switch at dupRate ≥ 0.70 or two no-progress; tolerant parse + adaptive tokens + optional session refresh.
- C – Temperature ramp: +0.05/round to ≤ 0.9 (track diversity vs. JSON failures).
- D – Greedy last-mile: ≤ 2 items → `.greedy` with small `maximumResponseTokens`.

Acceptance gating: feature-flag matrix (default/forced on/off); require ≥ 6/7 suites and T3/T4 ≥ 0.6 in forced-enable before merge.

---

## 13) PCC appendix—what’s verifiable today
- Security model: PCC uses hardened Apple-Silicon servers; devices only send to servers whose images are publicly logged for verification; processing is ephemeral; Apple personnel lack privileged data access.
- Research access: Apple provides a Virtual Research Environment and published select code (e.g., CloudAttestation, Thimble) for scrutiny—not the entire stack.

---

## 14) Quick handoff checklist (for an implementation agent)
1. Wire Pass 1 with `respond(… generating:)`, `includeSchemaInPrompt:true`, over-gen 1.5–1.6×N, defaults top-p 0.92, T 0.8 (or top-k ≈ 50 where top-p unavailable).
2. Implement hybrid backfill with the switch rule, lenient parsing, adaptive tokens, seed rotation, temp ramp ≤ 0.9.
3. Add circuit-breaker, session recreation on overflow/fail-streak, and prewarm on new sessions.
4. Budget tokens; always set `maximumResponseTokens`; chunk avoid-lists.
5. Instrument & log: per-attempt JSONL; profile on A-series and M-series with the Foundation Models instrument.

---

## Sources (authoritative)
- Framework & APIs: Foundation Models overview, GenerationOptions, LanguageModelSession (errors, prewarm), `@Generable`, guided generation, and tool-calling.
- Context window & overflow: Apple Technote TN3193 + `GenerationError.exceededContextWindowSize`.
- Performance tooling: Foundation Models instrument / profiling write-ups.
- Model characteristics (on-device vs. server): Apple Intelligence Foundation Language Models (technical report); MLX on Apple Silicon.
- PCC privacy & verification: Apple Security Blog: Private Cloud Compute; VRE docs; Apple’s published PCC components (GitHub).

---

## One-line doctrine

Guarantee uniqueness on the client. Use guided gen for structure, switch to unguided when duplicates surge, and steer with token budgets, circuit-breakers, and session hygiene—escalating to PCC only when the on-device path demonstrably can’t deliver.
