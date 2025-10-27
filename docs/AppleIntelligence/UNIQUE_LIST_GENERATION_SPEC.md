# Unique List Generation Specification (POC)

**Status**: PROOF-OF-CONCEPT / EXPERIMENTAL
**Version**: 1.0
**Date**: 2025-10-24
**Platforms**: iOS 26.0+, macOS 26.0+

## Executive Summary

This document specifies a deterministic approach to generating N unique items
using Apple's on-device `FoundationModels` framework. The model cannot guarantee
non-repetition; **the client must enforce it**.

### Core Principle

> **Push uniqueness guarantees to deterministic client code, not to the non-deterministic model.**

### Architecture

```text
Generate (over-sized) → Deduplicate (client-side) → Backfill (if needed)
```text

## Ground Truth (Contractual Facts)

### What We Control

- `GenerationOptions.sampling`: `.greedy`, `.random(top:seed:)`, `.random(probabilityThreshold:seed:)`
- `GenerationOptions.temperature`: 0.0 to 2.0 (recommended: 0.7-0.9)
- `GenerationOptions.maximumResponseTokens`: Required, no defaults

### What We Don't Control

- ❌ No repetition/frequency/presence penalties in the API
- ❌ Context window size not a public contract (treat ~4k as guidance)
- ❌ No public model identifier (reproducibility limited to same OS version)

### What We Use

- ✅ Guided generation with `@Generable` macro for structured JSON
- ✅ Error handling for `LanguageModelSession.GenerationError.exceededContextWindowSize`
- ✅ Platform availability: iOS/iPadOS/macOS/visionOS 26+

## Algorithm: Generate → Dedup → Fill

### High-Level Flow

1. **Pass 1**: Over-generate (M = ceil(1.6 × N)) with diverse sampling
2. **Client Dedup**: Normalize and filter by `normKey` (first appearance wins)
3. **Pass 2+**: If count < N, backfill with avoid-list, max 3 passes
4. **Optional**: Greedy fallback if delta ≤ 2

### Pseudocode

```swift
func uniqueList(query: String, N: Int) async throws -> [String] {
    var unique: OrderedMap<normKey → original> = [:]

    // Pass 1: Over-generate
    let M1 = ceil(1.6 * N)
    let items1 = try await generate(query, count: M1, options: .diverse(seed, maxTok))
    for item in items1 {
        let key = item.normKey
        if !unique.contains(key) { unique[key] = item }
    }
    if unique.count >= N { return Array(unique.values.prefix(N)) }

    // Pass 2+: Backfill
    var passes = 0
    while unique.count < N && passes < 3 {
        let delta = max(N - unique.count, ceil(0.4 * N))
        let avoid = Array(unique.keys)
        for chunk in avoid.chunkedByTokenBudget(maxTokens: 800) {
            let items = try await generateFill(query, delta, avoidKeys: chunk, .controlled(seed, maxTok))
            for item in items {
                let key = item.normKey
                if !unique.contains(key) { unique[key] = item }
            }
            if unique.count >= N { break }
        }
        passes += 1
    }

    // Optional: Greedy for tiny deltas
    if unique.count < N && (N - unique.count) <= 2 {
        let need = N - unique.count
        let items = try await generate(query, count: need, options: .greedy)
        for item in items {
            let key = item.normKey
            if !unique.contains(key) { unique[key] = item }
        }
    }

    return Array(unique.values.prefix(N))
}
```text

## Normalization: `String.normKey`

Deterministic, cheap, language-agnostic transformation for deduplication:

### Steps (in order)

1. **Lowercase**
2. **Diacritic folding** (`folding(options: .diacriticInsensitive)`)
3. **Remove trademarks**: Strip ™ ® ©
4. **Map ampersand**: `&` → ` and `
5. **Remove bracketed content**: Delete `(...)` and `[...]`
6. **Remove leading articles**: Drop `the|a|an` (case-insensitive)
7. **Strip punctuation**: Replace with single space
8. **Collapse whitespace**: Trim and normalize
9. **Optional plural trimming**: Drop `es` or `s` from last word if > 4 chars (exceptions: bass, glass, chess, etc.)

### Implementation

```swift
extension String {
    var normKey: String {
        var s = lowercased().folding(options: .diacriticInsensitive, locale: .current)

        s = reMarks.replace(s, with: "")                    // ™®©
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = reBrackets.replace(s, with: "")                 // (...)  [...]
        s = reLeadArticles.replace(s, with: "")             // ^(the|a|an)\s+
        s = rePunct.replace(s, with: " ")                   // All punctuation
        s = reWs.replace(s, with: " ").trimmed()

        // Optional plural trim
        if UniqueListGenerationFlags.pluralTrimEnabled {
            var parts = s.split(separator: " ")
            if var last = parts.last, last.count > 4, !pluralExceptions.contains(last) {
                if last.hasSuffix("es") { last.removeLast(2) }
                else if last.hasSuffix("s") { last.removeLast() }
                parts[parts.count - 1] = last
            }
            s = parts.joined(separator: " ")
        }

        return s
    }
}
```text

### Examples

| Input | normKey |
|-------|---------|
| `"The Matrix"` | `"matrix"` |
| `"Star Trek™"` | `"star trek"` |
| `"Star Trek: The Next Generation"` | `"star trek next generation"` |
| `"Star Trek (2009)"` | `"star trek"` |
| `"Doctor Who & Torchwood"` | `"doctor who and torchwood"` |
| `"Pokémon"` | `"pokemon"` |
| `"Heroes"` | `"heroe"` (if plural trim enabled) |

## Decoder Configurations

### Profiles

```swift
extension GenerationOptions {
    static var greedy: Self {
        .init(sampling: .greedy, temperature: 0, maximumResponseTokens: 256)
    }

    static func diverse(seed: UInt64?, maxTok: Int) -> Self {
        if #available(iOS 26.0, macOS 26.0, *) {
            return topP(0.92, temp: 0.8, seed: seed, maxTok: maxTok)
        } else {
            return topK(50, temp: 0.8, seed: seed, maxTok: maxTok)
        }
    }

    static func controlled(seed: UInt64?, maxTok: Int) -> Self {
        topK(40, temp: 0.7, seed: seed, maxTok: maxTok)
    }
}
```text

### Recommendations

- **Pass 1 (over-gen)**: `.diverse` - Maximize variety
- **Pass 2+ (backfill)**: `.controlled` - Consistent quality
- **Greedy fallback**: `.greedy` - Deterministic last resort

## Token Budgeting

### Heuristics

- **Prompt tokens**: `ceil(prompt.count / 4)`
- **Response tokens**: `ceil(7 × M)` where M is requested items
- **Total budget**: ~3500 tokens (conservative)

### Avoid-List Chunking

When the avoid-list exceeds 800 tokens, split it:

```swift
extension Array where Element == String {
    func chunkedByTokenBudget(maxTokens: Int) -> [[String]] {
        var chunks: [[String]] = []
        var current: [String] = []
        var tally = 0

        for key in self {
            let t = (key.count + 3) / 4 + 2  // Estimate + quotes + comma
            if tally + t > maxTokens, !current.isEmpty {
                chunks.append(current)
                current = [key]
                tally = t
            } else {
                current.append(key)
                tally += t
            }
        }

        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
```

### Overflow Recovery

```swift
do {
    let items = try await fm.generate(prompt, options: options)
    return items
} catch let e as LanguageModelSession.GenerationError {
    if case .exceededContextWindowSize(let details) = e {
        // Option 1: Chunk avoid-list and retry
        // Option 2: Reduce M or maximumResponseTokens
        // Option 3: Start new session
    }
    throw e
}
```

## Guided Schema

```swift
@Generable
struct UniqueListResponse: Decodable {
    var items: [String]
}
```

### Usage

```swift
let response = try await session.respond(
    to: Prompt(prompt),
    generating: UniqueListResponse.self,
    includeSchemaInPrompt: true,
    options: options
)
return response.content.items
```

## Prompt Templates

### G0-Minimal (Pass 1)

```text
Return ONLY a JSON object matching the schema.
Task: {QUERY}. Produce {M} distinct items.
```

### G18-Fill (Pass 2+, with avoid-list)

```text
Return ONLY a JSON object matching the schema.
Add {DELTA} NEW items for: {QUERY}.
Do NOT include any with norm_keys in:
["{k1}","{k2}",...,"{km}"]
```

Place avoid-list JSON array **last** in prompt for optimal token usage.

## Telemetry

### Structures

```swift
struct RunEnv: Codable {
    let osVersionString: String
    let osVersion: String           // "26.0.0"
    let hasTopP: Bool               // iOS 26+ feature
    let deploymentTag: String?
}

struct RunMetrics: Codable {
    let passAtN: Bool               // Primary metric
    let uniqueAtN: Int
    let jsonStrictSuccess: Bool
    let itemsPerSecond: Double
    let dupRatePreDedup: Double
    let seed: UInt64?
    let decoderProfile: String
    let env: RunEnv
    let generationTimeSeconds: Double
    let totalPasses: Int
}
```

### Key Metrics

- **Primary**: `passAtN` - Did we get N unique items?
- **Secondary**: `dupRatePreDedup`, `itemsPerSecond`, `totalPasses`
- **Diagnostics**: `jsonStrictSuccess`, `generationTimeSeconds`

## Configuration Defaults

```swift
enum Defaults {
    static let maxPasses = 3                    // Backfill attempts
    static let pass1OverGen = 1.6               // Over-gen factor
    static let minBackfillFrac = 0.4            // Backfill delta floor
    static let tempDiverse = 0.8                // Diverse temp
    static let tempControlled = 0.7             // Controlled temp
    static let conservativeContextBudget = 3500 // Token limit
}
```

### Tuning Guidance

- **pass1OverGen**: Increase if dupRate consistently high (>30%)
- **minBackfillFrac**: Increase for better fill efficiency
- **maxPasses**: Reduce if latency is critical
- **temperatures**: Lower for more consistent, higher for creative

## Acceptance Tests

7 test suites validate the implementation:

1. **Structure**: JSON decodes cleanly
2. **Uniqueness**: All normKeys are unique
3. **Backfill**: Fill mechanism works when pass 1 insufficient
4. **Overflow**: Chunked avoid-lists handle large sets
5. **Reproducibility**: Fixed seeds produce stable results
6. **Normalization**: Edge cases handled correctly
7. **Token Budgeting**: Chunking preserves all items

### Running (Acceptance)

```bash
# Interactive (DEBUG mode)
1. Build: ./build_install_launch.sh catalyst
2. Open AI Chat (sparkles button)
3. Click green checkmark button
4. View results in chat + /tmp/tiercade_acceptance_test_report.json
```

**Expected**: 7/7 pass

## Pilot Testing

Validates across multi-dimensional grid:

- **Sizes**: N ∈ {15, 50, 150}
- **Seeds**: 5 fixed (42, 123, 456, 789, 999)
- **Domains**: 4 (scientists, languages, sci-fi, games)
- **Total runs**: 60

### Running (Pilot)

```bash
# Interactive (DEBUG mode)
1. Open AI Chat
2. Click cyan chart button
3. Wait 5-15 minutes
4. View results in /tmp/tiercade_pilot_test_report.{json,txt}
```

### Interpreting Results

- **Pass@N > 90%**: Excellent, production-ready for that config
- **Pass@N 70-90%**: Good, minor tuning may help
- **Pass@N < 70%**: Needs tuning or domain-specific handling

## Known Limitations

### Not Solved

- ❌ Semantic duplicates (e.g., "USA" vs "United States")
- ❌ Adaptive tuning based on domain characteristics
- ❌ Cost optimization (minimize tokens per successful list)
- ❌ Real-time feedback to user during generation

### By Design

- Client-side enforcement (model cannot guarantee uniqueness)
- Rough token estimation (conservative for safety)
- Fixed heuristics (not adaptive)

## Security & Robustness

### Mandatory

- ✅ Decode with strict `JSONDecoder`
- ✅ Validate all generated content before use
- ✅ Catch and handle `exceededContextWindowSize`
- ✅ Set `maximumResponseTokens` on every call

### Recommended

- Sanitize rendered text in UI
- Log all errors with context
- Monitor pass@N in production
- Alert on degraded performance

## Future Work

### Short Term

- [ ] Run pilot grid on real hardware
- [ ] Calibrate heuristics from data
- [ ] Add semantic deduplication layer

### Medium Term

- [ ] Adaptive over-gen factor by domain
- [ ] Cost analysis and optimization
- [ ] Integration with tier list wizard

### Long Term

- [ ] Fuzzy matching for near-duplicates
- [ ] Multi-language normalization
- [ ] Embedding-based semantic clustering

## References

### Implementation Files

- `AppleIntelligence+UniqueListGeneration.swift` - Core algorithm
- `AppleIntelligence+AcceptanceTests.swift` - 7 test suites
- `AppleIntelligence+PilotTesting.swift` - Grid validation
- `AppState+AppleIntelligence.swift` - Integration (POC flag)

### Documentation

- `PROMPT_TESTING_GUIDE.md` - User guide
- This file (`UNIQUE_LIST_GENERATION_SPEC.md`) - Full specification

### Output Files

- `/tmp/tiercade_acceptance_test_report.json` - Test results
- `/tmp/tiercade_pilot_test_report.{json,txt}` - Pilot results

---

## End of Specification
