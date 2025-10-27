# Hybrid Backfill Implementation Plan

## Summary

Switch backfill from guided generation (which ignores avoid-list) to
**unguided text generation** (which should respect semantic constraints).

**Files to modify:** `Tiercade/State/AppleIntelligence+UniqueListGeneration.swift`

---

## Change 1: Add Unguided Text Array Method to FMClient

**Location:** Inside `FMClient` class, **before line 521** (before the closing brace)

**Add this new method:**

```swift
    /// Unguided generation that returns [String] by parsing JSON text array.
    /// Used for backfill where semantic constraints (avoid-list) must be respected.
    func generateTextArray(
        _ prompt: String,
        profile: DecoderProfile,
        initialSeed: UInt64?,
        temperature: Double?,
        maxTokens: Int?,
        maxRetries: Int = 3,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        let start = Date()
        var currentOptions = profile.options(seed: initialSeed, temp: temperature, maxTok: maxTokens)
        var lastError: Error?

        for attempt in 0..<maxRetries {
            let attemptStart = Date()
            var sessionRecreated = false

            // Record attempt telemetry
            telemetry.append(AttemptMetrics(
                attemptIndex: attempt,
                seed: initialSeed,
                sampling: "unguided:\(profile.description)",
                temperature: currentOptions.temperature,
                sessionRecreated: sessionRecreated
            ))

            do {
                let response = try await session.respond(
                    to: Prompt(prompt),
                    options: currentOptions
                )

                let attemptElapsed = Date().timeIntervalSince(attemptStart)

                if let arr = parseJSONArray(response.outputText) {
                    let totalElapsed = Date().timeIntervalSince(start)
                    logger("✓ Parsed \(arr.count) items from text in \(String(format: "%.2f", totalElapsed))s")
                    return arr
                }

                // Parse failure - treat as error
                throw NSError(domain: "UnguidedParse", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse JSON array from response"
                ])

            } catch {
                lastError = error

                // Adaptive boost on first failure
                if attempt == 0 {
                    let currentMax = currentOptions.maximumResponseTokens ?? 256
                    let boosted = min(512, Int(Double(currentMax) * 1.8))
                    if boosted > currentMax {
                        logger("🔁 Boosting maxTokens → \(boosted) for unguided parse retry")
                        currentOptions = profile.options(
                            seed: initialSeed,
                            temp: max(0.0, (temperature ?? 0.7) * 0.9),
                            maxTok: boosted
                        )
                        continue
                    }
                }

                // Session refresh on second failure
                if attempt == 1, let factory = sessionFactory {
                    do {
                        session = try await factory()
                        logger("♻️ Recreating session for unguided retry")
                    } catch {
                        logger("⚠️ Failed to create fresh session: \(error)")
                    }
                }
            }
        }

        throw lastError ?? NSError(domain: "Unguided", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "All unguided retries failed"
        ])
    }

    /// Tolerant JSON array parser - extracts first [...] and parses strings.
    /// Falls back to regex extraction of quoted strings.
    private func parseJSONArray(_ text: String) -> [String]? {
        // Find first [ and last ]
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"),
              start < end else {
            return nil
        }

        let slice = String(text[start...end])

        // Try standard JSON parsing first
        if let data = slice.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return json.compactMap { $0 as? String }
        }

        // Salvage: extract quoted strings with regex
        var extracted: [String] = []
        let pattern = #""([^"\\]|\\.)*""#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = slice as NSString
            let matches = regex.matches(in: slice, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let quoted = nsString.substring(with: match.range)
                let unquoted = quoted.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                extracted.append(unquoted)
            }
        }

        return extracted.isEmpty ? nil : extracted
    }
```

---

## Change 2: Replace Negation Backfill Loop

**Location:** Lines 664-727

**Replace the entire backfill section with this:**

```swift
        // UNGUIDED BACKFILL: Semantic constraints work in unguided mode
        var backfillRound = 0
        while ordered.count < N && backfillRound < Defaults.maxPasses {
            backfillRound += 1
            passCount += 1

            let deltaNeed = N - ordered.count

            // Token budgeting (same as before)
            let backfillAvgTPI = 16
            let promptFillBase = "Generate NEW items for: \(query). Do NOT include any with norm_keys in:"
            let baseTok = (promptFillBase.count + 50) / 4
            let respBudget = max(0, budget - baseTok - 200)
            let deltaByBudget = respBudget / backfillAvgTPI
            let delta = min(max(deltaNeed, Int(ceil(Defaults.minBackfillFrac * Double(N)))), deltaByBudget)
            let maxTok = max(160, delta * backfillAvgTPI)

            logger("🔄 [Pass \(passCount)] Unguided Backfill: need \(deltaNeed), requesting \(delta)")

            let avoid = Array(seen)
            let avoidJSON = avoid.map { "\"\($0)\"" }.joined(separator: ",")

            let promptFill = """
            Generate \(delta) NEW items for: \(query).
            Do NOT include any with norm_keys in:
            [\(avoidJSON)]
            Return as JSON array: ["item1", "item2", ...]
            """

            let before = ordered.count

            do {
                let itemsFill = try await fm.generateTextArray(
                    promptFill,
                    profile: .topK(40),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: 0.6,
                    maxTokens: maxTok,
                    telemetry: &localTelemetry
                )
                absorb(itemsFill)
            } catch {
                logger("⚠️ Unguided backfill error: \(error)")
            }

            // Adaptive retry if no progress
            if ordered.count == before {
                do {
                    let promptRetry = """
                    Generate \(min(delta * 2, N - ordered.count)) NEW items for: \(query).
                    Do NOT include any with norm_keys in: [\(avoidJSON)]
                    Return as JSON array: ["item1", "item2"]
                    """
                    let itemsRetry = try await fm.generateTextArray(
                        promptRetry,
                        profile: .topK(40),
                        initialSeed: UInt64.random(in: 0...UInt64.max),
                        temperature: 0.55,
                        maxTokens: min(maxTok * 18 / 10, 512),
                        telemetry: &localTelemetry
                    )
                    absorb(itemsRetry)
                } catch {
                    logger("⚠️ Adaptive retry also failed: \(error)")
                }
            }

            logger("  Result: \(ordered.count)/\(N) unique")

            // Greedy last-mile for final 1-2 items
            if (N - ordered.count) in 1...2 {
                do {
                    let greedyPrompt = """
                    Generate \(N - ordered.count) NEW items for: \(query).
                    Return as JSON array: ["item1"]
                    """
                    let greedyItems = try await fm.generateTextArray(
                        greedyPrompt,
                        profile: .greedy,
                        initialSeed: nil,
                        temperature: 0.0,
                        maxTokens: 200,
                        telemetry: &localTelemetry
                    )
                    absorb(greedyItems)
                } catch {
                    logger("⚠️ Greedy last-mile failed: \(error)")
                }
            }
        }
```

---

## Testing

1. Build and run native macOS tests:

```bash
   ./build_install_launch.sh macos
```

1. Monitor for:

   - Parse failure rate (should be low < 5%)
   - Duplication rate in backfill (hypothesis: < 20%, down from 84%)
   - T3_Backfill pass@N (target: ≥ 0.6, up from 0.00)

2. Check telemetry for "unguided:" sampling labels

---

## Expected Outcomes

**Hypothesis:** Unguided generation respects semantic "avoid" constraints.

**Before (Guided Backfill):**

- 84% duplication rate
- pass@N = 0.00 (0/5 seeds)
- Model repeats same items despite avoid-list

**After (Unguided Backfill):**

- < 20% duplication rate (target)
- pass@N ≥ 0.6 (3+/5 seeds)
- Avoid-list respected, diverse items generated

**Trade-offs:**

- ❌ Lose JSON structure guarantees (must handle parse errors)
- ✅ Gain semantic constraint adherence
- ✅ Keep all good patterns (token budgeting, adaptive retry, greedy last-mile)

---

## Rollback Plan

If unguided backfill fails (high parse error rate or still high duplication):

1. Revert changes
2. Try Option B: Tool calling validation loop
3. Or Option C: Accept limitation, reduce N to 25

---

## References

- Guided generation: <https://developer.apple.com/documentation/foundationmodels/using-guided-generation-to-produce-structured-outputs>
- Unguided respond: <https://developer.apple.com/documentation/foundationmodels/languagemodelsession/respond(to:options:)-3b2m9>
- Analysis docs: `CHATGPT_ANALYSIS.md`, `TOOL_CALLING_EVALUATION.md`
