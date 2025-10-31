import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - UniqueListCoordinator Backfill Methods

@available(iOS 26.0, macOS 26.0, *)
extension UniqueListCoordinator {
    internal func executePass1(
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
        var rawItems1 = try await fm.generate(
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

        // Pre-normalization, pre-dedup log: exact model items before placeholder filtering
        logger("📥 Raw (Pass 1) model items (pre-placeholder, pre-dedup):\n• " + rawItems1.joined(separator: "\n• "))

        let placeholdersRemoved1 = rawItems1.count - filterPlaceholders(rawItems1).count
        var items1 = filterPlaceholders(rawItems1)
        logger("📝 Pass 1 (post-placeholder) returned \(items1.count) items:\n• " + items1.joined(separator: "\n• "))

        let beforeUniqueP1 = state.ordered.count
        state.absorb(items1, logger: logger)
        state.passCount = 1
        let keptP1 = state.ordered.count - beforeUniqueP1
        let droppedDupP1 = max(0, items1.count - keptP1)
        logger("📊 Summary (Pass 1): kept=\(keptP1), droppedDuplicates=\(droppedDupP1), placeholders=\(placeholdersRemoved1)")
        logger("  Result: \(state.ordered.count)/\(targetCount) unique, \(state.duplicatesFound) duplicates filtered")
    }

    internal func calculatePass1Budget(query: String, targetCount: Int) -> (overGenCount: Int, maxTok: Int) {
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

    internal func buildPass1Prompt(query: String, overGenCount: Int) -> String {
        switch promptStyle {
        case .strict:
            return """
            Return ONLY a JSON object matching the schema.
            Task: \(query). Produce \(overGenCount) distinct items.
            """
        case .minimal:
            return """
            Return a JSON object matching the schema.
            Task: \(query). Provide about \(overGenCount) varied, concrete items.
            Avoid placeholders. No commentary.
            """
        }
    }

    internal func finalizeSuccess(state: GenerationState, startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        logger("✅ Success in \(state.passCount) pass (\(String(format: "%.2f", elapsed))s)")
        // Store diagnostics on success as well, so dupRate etc. are available
        storeDiagnostics(state: state, targetCount: state.targetCount, success: true)
    }

    internal func executeBackfill(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        if useGuidedBackfill {
            if hybridSwitchEnabled {
                try await executeHybridBackfill(query: query, targetCount: targetCount, state: &state)
            } else {
                try await executeGuidedBackfill(query: query, targetCount: targetCount, state: &state)
            }
        } else {
            try await executeUnguidedBackfill(query: query, targetCount: targetCount, state: &state)
        }
    }

    // MARK: - Hybrid Backfill (DEBUG heuristic)

    internal func executeHybridBackfill(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        var backfillRound = 0
        var consecutiveNoProgress = 0
        var switchedToUnguided = false
        var attemptedBudgetBump = false
        var unguidedRounds = 0

        while state.ordered.count < targetCount && backfillRound < Defaults.maxPasses {
            backfillRound += 1
            state.passCount += 1

            let beforeUnique = state.ordered.count
            let beforeDup = state.duplicatesFound
            let beforeGen = state.totalGeneratedCount

            if !switchedToUnguided {
                try await executeGuidedBackfillRound(
                    query: query,
                    targetCount: targetCount,
                    backfillRound: backfillRound,
                    state: &state
                )

                // Progress + dup-rate for this round
                let afterUnique = state.ordered.count
                let dupDelta = state.duplicatesFound - beforeDup
                let genDelta = max(0, state.totalGeneratedCount - beforeGen)
                let roundDupRate = genDelta > 0 ? Double(dupDelta) / Double(genDelta) : 0.0

                // Circuit breaker-like check
                handleCircuitBreaker(
                    before: beforeUnique,
                    current: afterUnique,
                    consecutiveNoProgress: &consecutiveNoProgress,
                    circuitBreakerTriggered: &state.circuitBreakerTriggered
                )
                if state.circuitBreakerTriggered { break }

                // Hybrid decision with budget bump before switching
                if roundDupRate >= hybridDupThreshold || consecutiveNoProgress >= 2 {
                    if !attemptedBudgetBump {
                        attemptedBudgetBump = true
                        let deltaNeed = targetCount - state.ordered.count
                        let delta = calculateGuidedBackfillDelta(deltaNeed: deltaNeed, targetCount: targetCount)
                        let baseMaxTok = max(1024, delta * 20)
                        let boosted = min(4096, Int(Double(baseMaxTok) * 1.8))
                        logger("⬆️  [Hybrid] Budget bump before switch: maxTokens \(baseMaxTok) → \(boosted)")
                        try await executeGuidedBackfillRoundWithOverride(
                            query: query,
                            targetCount: targetCount,
                            backfillRound: backfillRound,
                            state: &state,
                            maxTokOverride: boosted
                        )
                        // After bump, do not immediately switch; allow loop to reassess
                    } else {
                        logger("🔀 [Hybrid] Switching to unguided backfill (dupRate=\(String(format: "%.2f", roundDupRate)), noProgress=\(consecutiveNoProgress))")
                        switchedToUnguided = true
                    }
                }

                // Greedy last-mile (guided)
                try await executeGreedyLastMileIfNeeded(
                    query: query,
                    targetCount: targetCount,
                    state: &state,
                    isGuided: true
                )
            } else {
                // Unguided round (bounded)
                try await executeUnguidedBackfillRound(
                    query: query,
                    targetCount: targetCount,
                    state: &state
                )
                unguidedRounds += 1
                if unguidedRounds >= 2 {
                    logger("⏹️  [Hybrid] Unguided rounds limit reached (2)")
                    break
                }

                let afterUnique = state.ordered.count
                handleCircuitBreaker(
                    before: beforeUnique,
                    current: afterUnique,
                    consecutiveNoProgress: &consecutiveNoProgress,
                    circuitBreakerTriggered: &state.circuitBreakerTriggered
                )
                if state.circuitBreakerTriggered { break }

                // Greedy last-mile (unguided)
                try await executeGreedyLastMileIfNeeded(
                    query: query,
                    targetCount: targetCount,
                    state: &state,
                    isGuided: false
                )
            }
        }
    }

    // MARK: - Guided Backfill

    internal func executeGuidedBackfill(
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
            if guidedBudgetBumpFirst && backfillRound == 1 {
                // Proactively use a larger token budget for the first guided backfill round
                let deltaNeed = targetCount - state.ordered.count
                let delta = calculateGuidedBackfillDelta(deltaNeed: deltaNeed, targetCount: targetCount)
                let baseMaxTok = max(1024, delta * 20)
                let boosted = min(4096, Int(Double(baseMaxTok) * 1.8))
                logger("⬆️  [Guided] First-round budget bump: maxTokens \(baseMaxTok) → \(boosted)")
                try await executeGuidedBackfillRoundWithOverride(
                    query: query,
                    targetCount: targetCount,
                    backfillRound: backfillRound,
                    state: &state,
                    maxTokOverride: boosted
                )
            } else {
                try await executeGuidedBackfillRound(
                    query: query,
                    targetCount: targetCount,
                    backfillRound: backfillRound,
                    state: &state
                )
            }

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

    internal func executeGuidedBackfillRound(
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

        let avoidComponents = buildGuidedAvoidList(
            avoid: avoid,
            dupFrequency: state.dupFrequency,
            backfillRound: backfillRound
        )

        let promptFill = buildGuidedBackfillPrompt(
            query: query,
            delta: delta,
            avoidSample: avoidComponents.avoidSample,
            coverageNote: avoidComponents.coverageNote,
            offenderNote: avoidComponents.offenderNote
        )

        let before = state.ordered.count

        do {
            var rawItemsFill = try await fm.generate(
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
            // Pre-normalization, pre-dedup
            logger("📥 Raw (Guided backfill pass \(state.passCount)) model items (pre-placeholder):\n• " + rawItemsFill.joined(separator: "\n• "))
            let placeholdersRemoved = rawItemsFill.count - filterPlaceholders(rawItemsFill).count
            var itemsFill = filterPlaceholders(rawItemsFill)
            logger("📝 Guided backfill (pass \(state.passCount)) returned \(itemsFill.count) items:\n• " + itemsFill.joined(separator: "\n• "))
            let kept = state.ordered.count
            state.absorb(itemsFill, logger: logger)
            let keptDelta = state.ordered.count - kept
            let droppedDup = max(0, itemsFill.count - keptDelta)
            logger("📊 Summary (Guided pass \(state.passCount)): kept=\(keptDelta), droppedDuplicates=\(droppedDup), placeholders=\(placeholdersRemoved)")
        } catch {
            logger("⚠️ Guided backfill error: \(error)")
            captureFailureReason("Guided backfill error: \(error.localizedDescription)")
        }

        if state.ordered.count == before {
            try await retryGuidedBackfill(
                query: query,
                targetCount: targetCount,
                deltaNeed: deltaNeed,
                avoidSample: avoidComponents.avoidSample,
                state: &state
            )
        }

        logger("  Result: \(state.ordered.count)/\(targetCount) unique (filtered \(state.duplicatesFound) duplicates)")
    }

    // Guided backfill with a maxTokens override used by hybrid budget bump
    internal func executeGuidedBackfillRoundWithOverride(
        query: String,
        targetCount: Int,
        backfillRound: Int,
        state: inout GenerationState,
        maxTokOverride: Int
    ) async throws {
        let deltaNeed = targetCount - state.ordered.count
        let delta = calculateGuidedBackfillDelta(deltaNeed: deltaNeed, targetCount: targetCount)
        let avoid = Array(state.seen)

        let avoidComponents = buildGuidedAvoidList(
            avoid: avoid,
            dupFrequency: state.dupFrequency,
            backfillRound: backfillRound
        )

        let promptFill = buildGuidedBackfillPrompt(
            query: query,
            delta: delta,
            avoidSample: avoidComponents.avoidSample,
            coverageNote: avoidComponents.coverageNote,
            offenderNote: avoidComponents.offenderNote
        )

        let before = state.ordered.count
        do {
            let itemsFill = try await fm.generate(
                FMClient.GenerateParameters(
                    prompt: promptFill,
                    profile: .topP(0.92),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: Defaults.tempDiverse,
                    maxTokens: maxTokOverride,
                    maxRetries: 5
                ),
                telemetry: &state.localTelemetry
            )
            state.absorb(itemsFill, logger: logger)
        } catch {
            logger("⚠️ Guided backfill error (override): \(error)")
            captureFailureReason("Guided backfill error (override): \(error.localizedDescription)")
        }

        if state.ordered.count == before {
            try await retryGuidedBackfill(
                query: query,
                targetCount: targetCount,
                deltaNeed: deltaNeed,
                avoidSample: avoidComponents.avoidSample,
                state: &state
            )
        }
    }

    internal func calculateGuidedBackfillDelta(deltaNeed: Int, targetCount: Int) -> Int {
        let deltaA = Int(ceil(Double(deltaNeed) * 1.5))
        let deltaB = Int(ceil(Defaults.minBackfillFrac * Double(targetCount)))
        return max(deltaA, deltaB)
    }

    private struct GuidedAvoidListComponents: Sendable {
        let avoidSample: String
        let coverageNote: String
        let offenderNote: String
    }

    private func buildGuidedAvoidList(
        avoid: [String],
        dupFrequency: [String: Int],
        backfillRound: Int
    ) -> GuidedAvoidListComponents {
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

        return GuidedAvoidListComponents(
            avoidSample: avoidSample,
            coverageNote: coverageNote,
            offenderNote: offenderNote
        )
    }

    internal func buildGuidedBackfillPrompt(
        query: String,
        delta: Int,
        avoidSample: String,
        coverageNote: String,
        offenderNote: String
    ) -> String {
        switch promptStyle {
        case .strict:
            return """
            Return ONLY a JSON object matching the schema.
            Task: \(query). Produce \(delta) distinct items.

            CRITICAL: Do NOT include items with these normalized keys:
            [\(avoidSample)]\(coverageNote)\(offenderNote)

            Generate NEW items that are NOT in the forbidden list above.
            """
        case .minimal:
            return """
            Return a JSON object matching the schema.
            Task: \(query). Provide \(delta) new, concrete items with good variety.
            Exclude items whose normalized keys appear in this sample: [\(avoidSample)]\(coverageNote)\(offenderNote)
            Avoid placeholders. No commentary.
            """
        }
    }

    internal func retryGuidedBackfill(
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

            var rawItemsRetry = try await fm.generate(
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
            logger("📥 Raw (Guided retry pass \(state.passCount)) model items (pre-placeholder):\n• " + rawItemsRetry.joined(separator: "\n• "))
            let placeholdersRemovedRetry = rawItemsRetry.count - filterPlaceholders(rawItemsRetry).count
            var itemsRetry = filterPlaceholders(rawItemsRetry)
            logger("📝 Guided retry (pass \(state.passCount)) returned \(itemsRetry.count) items:\n• " + itemsRetry.joined(separator: "\n• "))
            let kept = state.ordered.count
            state.absorb(itemsRetry, logger: logger)
            let keptDelta = state.ordered.count - kept
            let droppedDup = max(0, itemsRetry.count - keptDelta)
            logger("📊 Summary (Guided retry pass \(state.passCount)): kept=\(keptDelta), droppedDuplicates=\(droppedDup), placeholders=\(placeholdersRemovedRetry)")
        } catch {
            logger("⚠️ Adaptive retry failed: \(error)")
            captureFailureReason("Adaptive retry failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Unguided Backfill

    internal func executeUnguidedBackfill(
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

    internal func executeUnguidedBackfillRound(
        query: String,
        targetCount: Int,
        state: inout GenerationState
    ) async throws {
        let deltaNeed = targetCount - state.ordered.count
        let params = calculateUnguidedBackfillParams(
            deltaNeed: deltaNeed,
            targetCount: targetCount,
            query: query
        )

        logger("🔄 [Pass \(state.passCount)] Unguided Backfill: need \(deltaNeed), requesting \(params.delta)")

        let avoid = Array(state.seen)
        let avoidJSON = avoid.map { "\"\($0)\"" }.joined(separator: ",")
        let promptFill = buildUnguidedBackfillPrompt(query: query, delta: params.delta, avoidJSON: avoidJSON)

        let before = state.ordered.count

        do {
            var rawItemsFill = try await fm.generateTextArray(
                FMClient.GenerateTextArrayParameters(
                    prompt: promptFill,
                    profile: .topK(40),
                    initialSeed: UInt64.random(in: 0...UInt64.max),
                    temperature: 0.6,
                    maxTokens: params.maxTok,
                    maxRetries: 3
                ),
                telemetry: &state.localTelemetry
            )
            logger("📥 Raw (Unguided backfill pass \(state.passCount)) model items (pre-placeholder):\n• " + rawItemsFill.joined(separator: "\n• "))
            let placeholdersRemoved = rawItemsFill.count - filterPlaceholders(rawItemsFill).count
            var itemsFill = filterPlaceholders(rawItemsFill)
            logger("📝 Unguided backfill (pass \(state.passCount)) returned \(itemsFill.count) items:\n• " + itemsFill.joined(separator: "\n• "))
            let kept = state.ordered.count
            state.absorb(itemsFill, logger: logger)
            let keptDelta = state.ordered.count - kept
            let droppedDup = max(0, itemsFill.count - keptDelta)
            logger("📊 Summary (Unguided pass \(state.passCount)): kept=\(keptDelta), droppedDuplicates=\(droppedDup), placeholders=\(placeholdersRemoved)")
        } catch {
            logger("⚠️ Unguided backfill error: \(error)")
            captureFailureReason("Unguided backfill error: \(error.localizedDescription)")
        }

        if state.ordered.count == before {
            try await retryUnguidedBackfill(
                query: query,
                targetCount: targetCount,
                deltaByBudget: params.deltaByBudget,
                avoidJSON: avoidJSON,
                state: &state
            )
        }

        logger("  Result: \(state.ordered.count)/\(targetCount) unique")
    }

    private struct UnguidedBackfillParams: Sendable {
        let delta: Int
        let maxTok: Int
        let deltaByBudget: Int
    }

    private func calculateUnguidedBackfillParams(
        deltaNeed: Int,
        targetCount: Int,
        query: String
    ) -> UnguidedBackfillParams {
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
        return UnguidedBackfillParams(delta: delta, maxTok: maxTok, deltaByBudget: deltaByBudget)
    }

    internal func buildUnguidedBackfillPrompt(query: String, delta: Int, avoidJSON: String) -> String {
        switch promptStyle {
        case .strict:
            return """
            Generate EXACTLY \(delta) NEW unique items for: \(query).
            Do NOT include any with norm_keys in:
            [\(avoidJSON)]

            Return ONLY a JSON array with \(delta) string items.
            Format: ["item1", "item2", "item3", ...]
            Include all \(delta) items in your response.
            """
        case .minimal:
            return """
            Generate \(delta) new, concrete items for: \(query).
            Exclude any whose normalized keys appear in:
            [\(avoidJSON)]

            Return only a JSON array of strings.
            """
        }
    }

    internal func retryUnguidedBackfill(
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
            var rawItemsRetry = try await fm.generateTextArray(
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
            logger("📥 Raw (Unguided retry pass \(state.passCount)) model items (pre-placeholder):\n• " + rawItemsRetry.joined(separator: "\n• "))
            let placeholdersRemovedRetry = rawItemsRetry.count - filterPlaceholders(rawItemsRetry).count
            var itemsRetry = filterPlaceholders(rawItemsRetry)
            logger("📝 Unguided retry returned \(itemsRetry.count) items:\n• " + itemsRetry.joined(separator: "\n• "))
            let kept = state.ordered.count
            state.absorb(itemsRetry, logger: logger)
            let keptDelta = state.ordered.count - kept
            let droppedDup = max(0, itemsRetry.count - keptDelta)
            logger("📊 Summary (Unguided retry pass \(state.passCount)): kept=\(keptDelta), droppedDuplicates=\(droppedDup), placeholders=\(placeholdersRemovedRetry)")
        } catch {
            logger("⚠️ Adaptive retry also failed: \(error)")
            captureFailureReason("Adaptive retry also failed: \(error.localizedDescription)")
        }
    }

    // Domain-agnostic placeholder filter: remove obvious enumerated placeholders
    internal func filterPlaceholders(_ items: [String]) -> [String] {
        // Detect groups like "<prefix> A..J" or "<prefix> 1..10" that repeat with only suffix difference
        struct Key: Hashable { let prefix: String; let kind: String }
        var groups: [Key: [Int]] = [:] // store suffix ranks to estimate breadth
        let letterRegex = try? NSRegularExpression(pattern: #"^(.{2,}?)\s([A-Z])$"#)
        let digitRegex = try? NSRegularExpression(pattern: #"^(.{2,}?)\s([0-9]{1,2})$"#)

        func match(_ re: NSRegularExpression?, _ s: String) -> (String, Int)? {
            guard let re else { return nil }
            let ns = s as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let m = re.firstMatch(in: s, range: range) else { return nil }
            guard m.numberOfRanges >= 3 else { return nil }
            let pfx = ns.substring(with: m.range(at: 1))
            let suf = ns.substring(with: m.range(at: 2))
            if re == letterRegex {
                if let ch = suf.unicodeScalars.first, ch.value >= 65, ch.value <= 90 { // A..Z
                    // Rank A=1..Z=26
                    return (pfx, Int(ch.value - 64))
                }
            } else {
                if let val = Int(suf) { return (pfx, val) }
            }
            return nil
        }

        for s in items {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let (p, r) = match(letterRegex, t) {
                let key = Key(prefix: p, kind: "letter")
                groups[key, default: []].append(r)
            } else if let (p, r) = match(digitRegex, t) {
                let key = Key(prefix: p, kind: "digit")
                groups[key, default: []].append(r)
            }
        }

        // Identify placeholder groups with breadth ≥5 distinct suffixes
        var bad: Set<String> = []
        for (k, vals) in groups {
            let distinct = Set(vals)
            if distinct.count >= 5 {
                bad.insert(k.prefix + "|" + k.kind)
            }
        }

        if bad.isEmpty { return items }

        return items.filter { s in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let (p, _) = match(letterRegex, t), bad.contains(p + "|letter") { return false }
            if let (p, _) = match(digitRegex, t), bad.contains(p + "|digit") { return false }
            return true
        }
    }

    // MARK: - Shared Backfill Helpers

    internal func handleCircuitBreaker(
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

    internal func executeGreedyLastMileIfNeeded(
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

    internal func captureFailureReason(_ reason: String) {
        if lastRunFailureReason == nil {
            lastRunFailureReason = reason
        }
    }
}
#endif
