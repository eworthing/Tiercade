import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - UniqueListCoordinator Backfill Methods

@available(iOS 26.0, macOS 26.0, *)
extension UniqueListCoordinator {
    func executePass1(
        query: String,
        targetCount: Int,
        seed: UInt64?,
        state: inout GenerationState
    ) async throws {
        logger("🎯 [Pass 1] Target: \(targetCount) unique items")

        let (overGenCount, maxTok1) = calculatePass1Budget(query: query, targetCount: targetCount)
        let overGenFormatted = String(format: "%.1f", Defaults.pass1OverGen)
        logger("  Requesting \(overGenCount) items (over-gen: \(overGenFormatted)x, budget: \(maxTok1) tokens)")

        let prompt1 = buildPass1Prompt(query: query, overGenCount: overGenCount)
        let items1 = try await fm.generate(
            FMClient.GenerateParameters(
                prompt: prompt1,
                profile: .topP(0.92),
                initialSeed: seed,
                temperature: Defaults.tempDiverse,
                maxTokens: maxTok1,
                maxRetries: 5
            ),
            telemetry: &state.localTelemetry
        )

        state.absorb(items1, logger: logger)
        state.passCount = 1

        logger("  Result: \(state.ordered.count)/\(targetCount) unique, \(state.duplicatesFound) duplicates filtered")
    }

    func calculatePass1Budget(query: String, targetCount: Int) -> (overGenCount: Int, maxTok: Int) {
        let budget = 3500
        let prompt1Base = """
        Return ONLY a JSON object matching the schema.
        Task: \(query). Produce
        """
        let promptTok = (prompt1Base.count + 20) / 4
        let respBudget = max(0, budget - promptTok)
        let avgTPI = 7
        let mByBudget = respBudget / avgTPI
        let overGenCount = min(Int(ceil(Double(targetCount) * Defaults.pass1OverGen)), mByBudget)
        let maxTok1 = Int(ceil(7.0 * Double(overGenCount)))
        return (overGenCount, maxTok1)
    }

    func buildPass1Prompt(query: String, overGenCount: Int) -> String {
        return """
        Return ONLY a JSON object matching the schema.
        Task: \(query). Produce \(overGenCount) distinct items.
        """
    }

    func finalizeSuccess(state: GenerationState, startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        logger("✅ Success in \(state.passCount) pass (\(String(format: "%.2f", elapsed))s)")
    }

    func executeBackfill(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        if useGuidedBackfill {
            try await executeGuidedBackfill(query: query, targetCount: targetCount, state: &state)
        } else {
            try await executeUnguidedBackfill(query: query, targetCount: targetCount, state: &state)
        }
    }

    // MARK: - Guided Backfill

    func executeGuidedBackfill(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        var backfillRound = 0
        var consecutiveNoProgress = 0

        while state.ordered.count < targetCount && backfillRound < Defaults.maxPasses {
            backfillRound += 1
            state.backfillRoundsTotal += 1
            state.passCount += 1

            let before = state.ordered.count
            try await executeGuidedBackfillRound(
                query: query,
                targetCount: targetCount,
                backfillRound: backfillRound,
                state: &state
            )

            handleCircuitBreaker(
                before: before,
                current: state.ordered.count,
                consecutiveNoProgress: &consecutiveNoProgress,
                circuitBreakerTriggered: &state.circuitBreakerTriggered
            )

            if state.circuitBreakerTriggered { break }

            try await executeGreedyLastMileIfNeeded(
                query: query,
                targetCount: targetCount,
                state: &state,
                isGuided: true
            )
        }
    }

    func executeGuidedBackfillRound(
        query: String,
        targetCount: Int,
        backfillRound: Int,
        state: inout GenerationState
    ) async throws {
        let deltaNeed = targetCount - state.ordered.count
        let delta = calculateGuidedBackfillDelta(deltaNeed: deltaNeed, targetCount: targetCount)
        let maxTok = max(1024, delta * 20)

        let avoid = Array(state.seen)
        logger(
            "🔄 [Pass \(state.passCount)] Guided Backfill: need \(deltaNeed), " +
            "requesting \(delta), avoiding \(avoid.count) items"
        )

        let (avoidSample, coverageNote, offenderNote) = buildGuidedAvoidList(
            avoid: avoid,
            dupFrequency: state.dupFrequency,
            backfillRound: backfillRound
        )

        let promptFill = buildGuidedBackfillPrompt(
            query: query,
            delta: delta,
            avoidSample: avoidSample,
            coverageNote: coverageNote,
            offenderNote: offenderNote
        )

        let before = state.ordered.count

        do {
            let itemsFill = try await fm.generate(
                FMClient.GenerateParameters(
                    prompt: promptFill,
                    profile: .topP(0.92),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: Defaults.tempDiverse,
                    maxTokens: maxTok,
                    maxRetries: 5
                ),
                telemetry: &state.localTelemetry
            )
            state.absorb(itemsFill, logger: logger)
        } catch {
            logger("⚠️ Guided backfill error: \(error)")
            captureFailureReason("Guided backfill error: \(error.localizedDescription)")
        }

        if state.ordered.count == before {
            try await retryGuidedBackfill(
                query: query,
                targetCount: targetCount,
                deltaNeed: deltaNeed,
                avoidSample: avoidSample,
                state: &state
            )
        }

        logger("  Result: \(state.ordered.count)/\(targetCount) unique (filtered \(state.duplicatesFound) duplicates)")
    }

    func calculateGuidedBackfillDelta(deltaNeed: Int, targetCount: Int) -> Int {
        let deltaA = Int(ceil(Double(deltaNeed) * 1.5))
        let deltaB = Int(ceil(Defaults.minBackfillFrac * Double(targetCount)))
        return max(deltaA, deltaB)
    }

    func buildGuidedAvoidList(
        avoid: [String],
        dupFrequency: [String: Int],
        backfillRound: Int
    ) -> (avoidSample: String, coverageNote: String, offenderNote: String) {
        let sampleSize = 40
        let offset = (backfillRound - 1) * 20
        let startIdx = offset % max(1, avoid.count)
        let endIdx = min(startIdx + sampleSize, avoid.count)

        var avoidSampleKeys: [String] = []
        if endIdx <= avoid.count {
            avoidSampleKeys = Array(avoid[startIdx..<endIdx])
        } else {
            avoidSampleKeys = Array(avoid[startIdx..<avoid.count])
            let remaining = sampleSize - avoidSampleKeys.count
            avoidSampleKeys += Array(avoid.prefix(remaining))
        }

        let topOffenders = dupFrequency
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\"\($0.key)\" (filtered \($0.value)x)" }
            .joined(separator: ", ")

        let avoidSample = avoidSampleKeys.map { "\"\($0)\"" }.joined(separator: ", ")
        let coverageNote = avoid.count > sampleSize
            ? "\n  Showing \(avoidSampleKeys.count) of \(avoid.count) forbidden items " +
              "(rotating sample, pass \(backfillRound))"
            : ""
        let offenderNote = !topOffenders.isEmpty ?
            "\n  Most repeated: [\(topOffenders)]" : ""

        return (avoidSample, coverageNote, offenderNote)
    }

    func buildGuidedBackfillPrompt(
        query: String,
        delta: Int,
        avoidSample: String,
        coverageNote: String,
        offenderNote: String
    ) -> String {
        return """
        Return ONLY a JSON object matching the schema.
        Task: \(query). Produce \(delta) distinct items.

        CRITICAL: Do NOT include items with these normalized keys:
        [\(avoidSample)]\(coverageNote)\(offenderNote)

        Generate NEW items that are NOT in the forbidden list above.
        """
    }

    func retryGuidedBackfill(
        query: String,
        targetCount: Int,
        deltaNeed: Int,
        avoidSample: String,
        state: inout GenerationState
    ) async throws {
        do {
            let retryDelta = min(deltaNeed * 2, Int(ceil(Double(targetCount) * 0.5)))
            logger("  ⟳ Retry: requesting \(retryDelta) items with higher temperature")

            let retryOffenders = state.dupFrequency
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { "\"\($0.key)\" (\($0.value)x)" }
                .joined(separator: ", ")

            let promptRetry = """
            Return ONLY a JSON object matching the schema.
            Task: \(query). Produce \(retryDelta) distinct items.

            CRITICAL: Avoid these items (most frequently repeated):
            [\(retryOffenders)]

            Also avoid: [\(avoidSample)]
            """

            let itemsRetry = try await fm.generate(
                FMClient.GenerateParameters(
                    prompt: promptRetry,
                    profile: .topK(50),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: 0.9,
                    maxTokens: max(1536, retryDelta * 25),
                    maxRetries: 5
                ),
                telemetry: &state.localTelemetry
            )
            state.absorb(itemsRetry, logger: logger)
        } catch {
            logger("⚠️ Adaptive retry failed: \(error)")
            captureFailureReason("Adaptive retry failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Unguided Backfill

    func executeUnguidedBackfill(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        var backfillRound = 0
        var consecutiveNoProgress = 0

        while state.ordered.count < targetCount && backfillRound < Defaults.maxPasses {
            backfillRound += 1
            state.backfillRoundsTotal += 1
            state.passCount += 1

            let before = state.ordered.count
            try await executeUnguidedBackfillRound(
                query: query,
                targetCount: targetCount,
                state: &state
            )

            handleCircuitBreaker(
                before: before,
                current: state.ordered.count,
                consecutiveNoProgress: &consecutiveNoProgress,
                circuitBreakerTriggered: &state.circuitBreakerTriggered
            )

            if state.circuitBreakerTriggered { break }

            try await executeGreedyLastMileIfNeeded(
                query: query,
                targetCount: targetCount,
                state: &state,
                isGuided: false
            )
        }
    }

    func executeUnguidedBackfillRound(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        let deltaNeed = targetCount - state.ordered.count
        let (delta, maxTok, deltaByBudget) = calculateUnguidedBackfillParams(
            deltaNeed: deltaNeed,
            targetCount: targetCount,
            query: query
        )

        logger("🔄 [Pass \(state.passCount)] Unguided Backfill: need \(deltaNeed), requesting \(delta)")

        let avoid = Array(state.seen)
        let avoidJSON = avoid.map { "\"\($0)\"" }.joined(separator: ",")
        let promptFill = buildUnguidedBackfillPrompt(query: query, delta: delta, avoidJSON: avoidJSON)

        let before = state.ordered.count

        do {
            let itemsFill = try await fm.generateTextArray(
                FMClient.GenerateTextArrayParameters(
                    prompt: promptFill,
                    profile: .topK(40),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: 0.6,
                    maxTokens: maxTok,
                    maxRetries: 3
                ),
                telemetry: &state.localTelemetry
            )
            state.absorb(itemsFill, logger: logger)
        } catch {
            logger("⚠️ Unguided backfill error: \(error)")
            captureFailureReason("Unguided backfill error: \(error.localizedDescription)")
        }

        if state.ordered.count == before {
            try await retryUnguidedBackfill(
                query: query,
                targetCount: targetCount,
                deltaByBudget: deltaByBudget,
                avoidJSON: avoidJSON,
                state: &state
            )
        }

        logger("  Result: \(state.ordered.count)/\(targetCount) unique")
    }

    func calculateUnguidedBackfillParams(
        deltaNeed: Int,
        targetCount: Int,
        query: String
    ) -> (delta: Int, maxTok: Int, deltaByBudget: Int) {
        let budget = 3500
        let backfillAvgTPI = 20
        let promptFillBase = "Generate NEW items for: \(query). Do NOT include any with norm_keys in:"
        let baseTok = (promptFillBase.count + 50) / 4
        let respBudget = max(0, budget - baseTok - 200)
        let deltaByBudget = respBudget / backfillAvgTPI
        let deltaWithDupBuffer = Int(ceil(Double(deltaNeed) * 4.0))
        let deltaMin = Int(ceil(Defaults.minBackfillFrac * Double(targetCount)))
        let delta = min(max(deltaWithDupBuffer, deltaMin), deltaByBudget)
        let maxTok = max(1024, delta * backfillAvgTPI * 2)
        return (delta, maxTok, deltaByBudget)
    }

    func buildUnguidedBackfillPrompt(query: String, delta: Int, avoidJSON: String) -> String {
        return """
        Generate EXACTLY \(delta) NEW unique items for: \(query).
        Do NOT include any with norm_keys in:
        [\(avoidJSON)]

        Return ONLY a JSON array with \(delta) string items.
        Format: ["item1", "item2", "item3", ...]
        Include all \(delta) items in your response.
        """
    }

    func retryUnguidedBackfill(
        query: String,
        targetCount: Int,
        deltaByBudget: Int,
        avoidJSON: String,
        state: inout GenerationState
    ) async throws {
        do {
            let retryCount = min((targetCount - state.ordered.count) * 5, deltaByBudget)
            let promptRetry = """
            Generate EXACTLY \(retryCount) NEW unique items for: \(query).
            Do NOT include any with norm_keys in: [\(avoidJSON)]

            Return ONLY a JSON array with \(retryCount) string items.
            Format: ["item1", "item2", "item3", ...]
            """
            let itemsRetry = try await fm.generateTextArray(
                FMClient.GenerateTextArrayParameters(
                    prompt: promptRetry,
                    profile: .topK(40),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: 0.55,
                    maxTokens: max(1536, retryCount * 30),
                    maxRetries: 3
                ),
                telemetry: &state.localTelemetry
            )
            state.absorb(itemsRetry, logger: logger)
        } catch {
            logger("⚠️ Adaptive retry also failed: \(error)")
            captureFailureReason("Adaptive retry also failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Shared Backfill Helpers

    func handleCircuitBreaker(
        before: Int,
        current: Int,
        consecutiveNoProgress: inout Int,
        circuitBreakerTriggered: inout Bool
    ) {
        if current == before {
            consecutiveNoProgress += 1
            if consecutiveNoProgress >= 2 {
                logger("⚠️ Circuit breaker: 2 consecutive rounds with no progress. Exiting backfill early.")
                circuitBreakerTriggered = true
            }
        } else {
            consecutiveNoProgress = 0
        }
    }

    func executeGreedyLastMileIfNeeded(
        query: String,
        targetCount: Int,
        state: inout GenerationState,
        isGuided: Bool
    ) async throws {
        guard (1...2).contains(targetCount - state.ordered.count) else { return }

        do {
            let remaining = targetCount - state.ordered.count
            logger("  🎯 Greedy last-mile: requesting \(remaining) item(s)")

            if isGuided {
                let greedyPrompt = """
                Return ONLY a JSON object matching the schema.
                Task: \(query). Produce EXACTLY \(remaining) distinct item\(remaining > 1 ? "s" : "").
                """

                let greedyItems = try await fm.generate(
                    FMClient.GenerateParameters(
                        prompt: greedyPrompt,
                        profile: .greedy,
                        initialSeed: nil,
                        temperature: 0.0,
                        maxTokens: 512,
                        maxRetries: 5
                    ),
                    telemetry: &state.localTelemetry
                )
                state.absorb(greedyItems, logger: logger)
            } else {
                let greedyPrompt = """
                Generate EXACTLY \(remaining) NEW unique item\(remaining > 1 ? "s" : "") for: \(query).

                Return ONLY a JSON array with \(remaining) string item\(remaining > 1 ? "s" : "").
                Format: \(remaining == 1 ? "[\"item\"]" : "[\"item1\", \"item2\"]")
                """
                let greedyItems = try await fm.generateTextArray(
                    FMClient.GenerateTextArrayParameters(
                        prompt: greedyPrompt,
                        profile: .greedy,
                        initialSeed: nil,
                        temperature: 0.0,
                        maxTokens: 512,
                        maxRetries: 3
                    ),
                    telemetry: &state.localTelemetry
                )
                state.absorb(greedyItems, logger: logger)
            }
        } catch {
            logger("⚠️ Greedy last-mile failed: \(error)")
            captureFailureReason("Greedy last-mile failed: \(error.localizedDescription)")
        }
    }

    func captureFailureReason(_ reason: String) {
        if lastRunFailureReason == nil {
            lastRunFailureReason = reason
        }
    }
}
#endif
