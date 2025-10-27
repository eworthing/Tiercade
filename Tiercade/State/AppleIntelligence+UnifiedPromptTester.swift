import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Generable Types

/// Generable type for guided generation of string lists
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct StringList: Sendable {
    @Guide(description: "Array of unique items")
    var items: [String]
}

// MARK: - Unified Prompt Testing Framework

/// Unified testing framework for Apple Intelligence prompt evaluation
/// Consolidates SystemPromptTester and EnhancedPromptTester functionality
/// with config-driven architecture for easy extensibility
///
/// Note: This class is NOT @MainActor isolated. Heavy operations run on background tasks.
/// Progress callbacks are dispatched to @MainActor for UI updates.
@available(iOS 26.0, macOS 26.0, *)
final class UnifiedPromptTester {

    // MARK: - Config Loading

    /// Load system prompts from SystemPrompts.json
    static func loadSystemPrompts() throws -> SystemPromptsLibrary {
        guard let url = Bundle.main.url(forResource: "SystemPrompts", withExtension: "json", subdirectory: "TestConfigs") else {
            throw TestingError.configurationNotFound("SystemPrompts.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load test queries from TestQueries.json
    static func loadTestQueries() throws -> TestQueriesLibrary {
        guard let url = Bundle.main.url(forResource: "TestQueries", withExtension: "json", subdirectory: "TestConfigs") else {
            throw TestingError.configurationNotFound("TestQueries.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load decoding configs from DecodingConfigs.json
    static func loadDecodingConfigs() throws -> DecodingConfigsLibrary {
        guard let url = Bundle.main.url(forResource: "DecodingConfigs", withExtension: "json", subdirectory: "TestConfigs") else {
            throw TestingError.configurationNotFound("DecodingConfigs.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load test suites from TestSuites.json
    static func loadTestSuites() throws -> TestSuitesLibrary {
        guard let url = Bundle.main.url(forResource: "TestSuites", withExtension: "json", subdirectory: "TestConfigs") else {
            throw TestingError.configurationNotFound("TestSuites.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Generic JSON loading
    private static func loadJSON<T: Decodable>(from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Suite Execution

    /// Run a predefined test suite
    static func runSuite(
        suiteId: String,
        onProgress: @escaping @MainActor (String) -> Void
    ) async throws -> TestReport {
        await onProgress("📦 Loading test suite '\(suiteId)'...")

        // Load all configurations
        let suitesLib = try loadTestSuites()
        guard let suite = suitesLib.suites.first(where: { $0.id == suiteId }) else {
            throw TestingError.configurationNotFound("Test suite '\(suiteId)' not found")
        }

        try ConfigValidator.validate(suite)

        let promptsLib = try loadSystemPrompts()
        let queriesLib = try loadTestQueries()
        let decodersLib = try loadDecodingConfigs()

        await onProgress("✅ Loaded configurations")
        await onProgress("📝 Suite: \(suite.name)")
        await onProgress("📋 Description: \(suite.description)")

        // Resolve IDs to actual configs (handle wildcards)
        let prompts = try resolvePrompts(ids: suite.config.promptIds, library: promptsLib)
        let queries = try resolveQueries(ids: suite.config.queryIds, library: queriesLib)
        let decoders = try resolveDecoders(ids: suite.config.decoderIds, library: decodersLib)

        await onProgress("🎯 Test matrix: \(prompts.count) prompts × \(queries.count) queries × \(decoders.count) decoders × \(suite.config.seeds.count) seeds × \(suite.config.guidedModes.count) modes")

        // Build test runs
        let testRuns = buildTestRuns(
            prompts: prompts,
            queries: queries,
            decoders: decoders,
            seeds: suite.config.seeds,
            guidedModes: suite.config.guidedModes
        )

        await onProgress("🚀 Starting \(testRuns.count) test runs...")

        // Execute tests
        let results = await executeTestRuns(
            testRuns,
            suite: suite,
            timeoutSeconds: suite.config.timeoutSeconds ?? 60,
            maxTokensOverride: suite.config.maxTokensOverride,
            onProgress: onProgress
        )

        // Aggregate results
        let report = try aggregateResults(
            suite: suite,
            results: results,
            prompts: prompts
        )

        return report
    }

    // MARK: - Test Run Building

    private static func buildTestRuns(
        prompts: [SystemPromptConfig],
        queries: [TestQueryConfig],
        decoders: [DecodingConfigDef],
        seeds: [UInt64],
        guidedModes: [Bool]
    ) -> [TestRun] {
        var runs: [TestRun] = []
        var runNumber = 1

        for prompt in prompts {
            for query in queries {
                for decoder in decoders {
                    for seed in seeds {
                        for guided in guidedModes {
                            runs.append(TestRun(
                                id: UUID(),
                                runNumber: runNumber,
                                prompt: prompt,
                                query: query,
                                decoder: decoder,
                                seed: seed,
                                useGuidedSchema: guided
                            ))
                            runNumber += 1
                        }
                    }
                }
            }
        }

        return runs
    }

    // MARK: - Test Execution

    private static func executeTestRuns(
        _ runs: [TestRun],
        suite: TestSuiteConfig,
        timeoutSeconds: Int,
        maxTokensOverride: Int?,
        onProgress: @escaping @MainActor (String) -> Void
    ) async -> [SingleTestResult] {
        var results: [SingleTestResult] = []
        let startTime = Date()

        for (index, run) in runs.enumerated() {
            // Yield to allow UI updates before each test run
            await Task.yield()

            let progress = TestProgress(
                completedRuns: index,
                totalRuns: runs.count,
                currentRun: run,
                estimatedTimeRemaining: estimateTimeRemaining(
                    completed: index,
                    total: runs.count,
                    elapsed: Date().timeIntervalSince(startTime)
                )
            )

            await onProgress("[\(index + 1)/\(runs.count)] Testing '\(run.prompt.name)' on '\(run.query.id)'...")

            let context = TestRunContext(run: run, maxTokensOverride: maxTokensOverride)

            do {
                // Show that we're starting the test execution
                await onProgress("⏳ Creating session and executing...")

                let result = try await executeTestRun(run, context: context, timeoutSeconds: timeoutSeconds)
                results.append(result)

                let status = result.isSuccess ? "✅" : "❌"
                await onProgress("\(status) \(result.uniqueItems)/\(run.effectiveTarget) unique (\(String(format: "%.1f", result.dupRate * 100))% dup)")
            } catch {
                await onProgress("❌ Error: \(error.localizedDescription)")

                // Create error result
                let errorResult = createErrorResult(run: run, context: context, error: error)
                results.append(errorResult)
            }

            // Show periodic progress summary for long-running suites
            if (index + 1) % 10 == 0 || (index + 1) == runs.count {
                let percentage = (index + 1) * 100 / runs.count
                let successCount = results.filter { $0.isSuccess }.count
                let successRate = successCount * 100 / max(1, results.count)
                let elapsed = Date().timeIntervalSince(startTime)
                await onProgress("📊 Progress: \(index + 1)/\(runs.count) (\(percentage)%) - Success: \(successRate)% - Elapsed: \(String(format: "%.1f", elapsed))s")
            }

            // Save checkpoint every 50 runs for crash recovery
            if (index + 1) % 50 == 0 {
                saveCheckpoint(suite: suite, results: results, completed: index + 1, total: runs.count)
                await onProgress("💾 Checkpoint saved (\(index + 1)/\(runs.count) tests)")
            }

            // Yield again after test completion to allow UI to update
            await Task.yield()

            // Brief delay to avoid overwhelming the system
            try? await Task.sleep(for: .milliseconds(500))
        }

        return results
    }

    private static func executeTestRun(
        _ run: TestRun,
        context: TestRunContext,
        timeoutSeconds: Int
    ) async throws -> SingleTestResult {
        let startTime = Date()

        // Render prompt with substitutions
        let template = PromptTemplate(raw: run.prompt.text)
        let renderedPrompt = try template.render(substitutions: [
            .query: run.query.query,
            .targetCount: String(run.effectiveTarget),
            .domain: run.query.domain
        ])

        // Create session
        let instructions = Instructions(renderedPrompt)
        let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)

        let opts = run.decoder.toGenerationOptions(seed: run.seed, maxTokens: context.maxTokens)

        // Execute generation with timeout - use guided generation if requested
        let responseContent: String
        do {
            if run.useGuidedSchema {
                // Guided generation: constrained sampling with @Generable type
                let items = try await withTimeout(seconds: timeoutSeconds) {
                    let response = try await session.respond(
                        to: Prompt(run.query.query),
                        generating: StringList.self,
                        includeSchemaInPrompt: true,
                        options: opts
                    )
                    return response.content.items
                }
                // Convert StringList to JSON string for consistent analysis
                let encoder = JSONEncoder()
                let data = try encoder.encode(items)
                responseContent = String(data: data, encoding: .utf8) ?? "[]"
            } else {
                // Unguided generation: free-form response
                responseContent = try await withTimeout(seconds: timeoutSeconds) {
                    try await session.respond(to: Prompt(run.query.query), options: opts).content
                }
            }
        } catch {
            // Verbose error logging for LanguageModel failures
            print("🔴 LanguageModel Error: \(error)")
            print("🔴   Prompt: \(run.prompt.id)")
            print("🔴   Query: \(run.query.id)")
            print("🔴   Decoder: \(run.decoder.id)")
            print("🔴   Guided: \(run.useGuidedSchema)")
            print("🔴   Error type: \(type(of: error))")
            throw error
        }

        let duration = Date().timeIntervalSince(startTime)

        // Analyze response
        let analysis = analyzeResponse(responseContent, targetCount: run.effectiveTarget)

        // Note: finishReason tracking removed - FoundationModels API doesn't expose this yet
        // Will add back once Apple provides Response.finishReason property

        return SingleTestResult(
            id: UUID(),
            timestamp: Date(),
            promptId: run.prompt.id,
            promptName: run.prompt.name,
            queryId: run.query.id,
            queryText: run.query.query,
            targetCount: run.query.targetCount,
            domain: run.query.domain,
            nBucket: run.nBucket,
            decoderId: run.decoder.id,
            decoderName: run.decoder.name,
            seed: run.seed,
            guidedSchema: run.useGuidedSchema,
            response: responseContent,
            parsedItems: analysis.parsedItems,
            normalizedItems: analysis.normalizedItems,
            totalItems: analysis.totalItems,
            uniqueItems: analysis.uniqueItems,
            duplicateCount: analysis.duplicateCount,
            dupRate: analysis.dupRate,
            passAtN: analysis.passAtN,
            surplusAtN: analysis.surplusAtN,
            jsonStrict: analysis.wasJsonParsed,
            insufficient: analysis.insufficient,
            formatError: analysis.formatError,
            finishReason: "stop",  // Default until Apple exposes this in the API
            wasTruncated: false,   // Cannot detect without finishReason
            maxTokensUsed: context.maxTokens,
            duration: duration,
            timePerUnique: analysis.uniqueItems > 0 ? duration / Double(analysis.uniqueItems) : duration
        )
    }

    // MARK: - Response Analysis

    private struct ResponseAnalysis {
        let parsedItems: [String]
        let normalizedItems: [String]
        let totalItems: Int
        let uniqueItems: Int
        let duplicateCount: Int
        let dupRate: Double
        let passAtN: Bool
        let surplusAtN: Int
        let insufficient: Bool
        let formatError: Bool
        let wasJsonParsed: Bool
    }

    private static func analyzeResponse(_ response: String, targetCount: Int) -> ResponseAnalysis {
        // Try JSON parsing first
        if let items = tryParseJSON(response) {
            return analyzeItems(items, targetCount: targetCount, wasJsonParsed: true)
        }

        // Fallback: parse numbered list
        let items = parseNumberedList(response)
        return analyzeItems(items, targetCount: targetCount, wasJsonParsed: false)
    }

    private static func tryParseJSON(_ response: String) -> [String]? {
        guard let data = response.data(using: .utf8) else { return nil }

        // Try parsing as bare array first: ["item1", "item2", ...]
        if let items = try? JSONDecoder().decode([String].self, from: data) {
            return items
        }

        // Try parsing as envelope format: {"items": ["item1", "item2", ...]}
        if let envelope = try? JSONDecoder().decode([String: [String]].self, from: data),
           let items = envelope["items"] {
            return items
        }

        // Try common alternative keys
        if let envelope = try? JSONDecoder().decode([String: [String]].self, from: data) {
            // Try "list", "results", "data", "values" as alternative keys
            for key in ["list", "results", "data", "values"] {
                if let items = envelope[key] {
                    return items
                }
            }
        }

        return nil
    }

    private static func parseNumberedList(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        var items: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match patterns like "1. Item" or "1) Item"
            if let range = trimmed.range(of: #"^\d+[\.)]\s*"#, options: .regularExpression) {
                let content = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    items.append(content)
                }
            }
        }

        return items
    }

    private static func analyzeItems(_ items: [String], targetCount: Int, wasJsonParsed: Bool) -> ResponseAnalysis {
        // Normalize items
        let normalized = items.map { $0.normKey }

        // Count unique
        let uniqueSet = Set(normalized)
        let uniqueItems = uniqueSet.count
        let duplicateCount = items.count - uniqueItems
        let dupRate = items.count > 0 ? Double(duplicateCount) / Double(items.count) : 0.0

        let passAtN = uniqueItems >= targetCount
        let surplusAtN = max(0, uniqueItems - targetCount)
        let insufficient = uniqueItems < targetCount

        return ResponseAnalysis(
            parsedItems: items,
            normalizedItems: Array(uniqueSet),
            totalItems: items.count,
            uniqueItems: uniqueItems,
            duplicateCount: duplicateCount,
            dupRate: dupRate,
            passAtN: passAtN,
            surplusAtN: surplusAtN,
            insufficient: insufficient,
            formatError: items.isEmpty,
            wasJsonParsed: wasJsonParsed
        )
    }

    // MARK: - Result Aggregation

    private static func aggregateResults(
        suite: TestSuiteConfig,
        results: [SingleTestResult],
        prompts: [SystemPromptConfig]
    ) throws -> TestReport {
        var aggregates: [AggregateTestResult] = []

        for prompt in prompts {
            let promptResults = results.filter { $0.promptId == prompt.id }
            guard !promptResults.isEmpty else { continue }

            let aggregate = aggregatePromptResults(prompt: prompt, results: promptResults)
            aggregates.append(aggregate)
        }

        let rankings = computeRankings(aggregates: aggregates)

        let successfulRuns = results.filter { $0.isSuccess }.count
        let totalDuration = results.map { $0.duration }.reduce(0, +)

        return TestReport(
            id: UUID(),
            timestamp: Date(),
            suiteId: suite.id,
            suiteName: suite.name,
            suiteDescription: suite.description,
            totalRuns: results.count,
            successfulRuns: successfulRuns,
            failedRuns: results.count - successfulRuns,
            totalDuration: totalDuration,
            environment: getEnvironmentInfo(),
            aggregateResults: aggregates,
            allResults: results,
            rankings: rankings
        )
    }

    private static func aggregatePromptResults(
        prompt: SystemPromptConfig,
        results: [SingleTestResult]
    ) -> AggregateTestResult {
        let overallStats = computeOverallStats(results: results)
        let byNBucket = stratifyByNBucket(results: results)
        let byDomain = stratifyByDomain(results: results)
        let byDecoder = stratifyByDecoder(results: results)

        let bestRun = results.max(by: { $0.qualityScore < $1.qualityScore })
        let worstRun = results.min(by: { $0.qualityScore < $1.qualityScore })

        return AggregateTestResult(
            id: UUID(),
            timestamp: Date(),
            promptId: prompt.id,
            promptName: prompt.name,
            promptText: prompt.text,
            totalRuns: results.count,
            byNBucket: byNBucket,
            byDomain: byDomain,
            byDecoder: byDecoder,
            overallStats: overallStats,
            bestRun: bestRun,
            worstRun: worstRun
        )
    }

    private static func computeOverallStats(results: [SingleTestResult]) -> AggregateTestResult.OverallStats {
        let passAtNRate = Double(results.filter { $0.passAtN }.count) / Double(max(1, results.count))
        let uniqueItems = results.map { Double($0.uniqueItems) }
        let dupRates = results.map { $0.dupRate }
        let timesPerUnique = results.map { $0.timePerUnique }
        let qualityScores = results.map { $0.qualityScore }

        return AggregateTestResult.OverallStats(
            passAtNRate: passAtNRate,
            meanUniqueItems: mean(uniqueItems),
            stdevUniqueItems: stdev(uniqueItems),
            meanDupRate: mean(dupRates),
            stdevDupRate: stdev(dupRates),
            meanTimePerUnique: mean(timesPerUnique),
            stdevTimePerUnique: stdev(timesPerUnique),
            jsonStrictRate: Double(results.filter { $0.jsonStrict }.count) / Double(max(1, results.count)),
            truncationRate: Double(results.filter { $0.wasTruncated }.count) / Double(max(1, results.count)),
            insufficientRate: Double(results.filter { $0.insufficient }.count) / Double(max(1, results.count)),
            formatErrorRate: Double(results.filter { $0.formatError }.count) / Double(max(1, results.count)),
            meanQualityScore: mean(qualityScores),
            seedVariance: variance(uniqueItems)
        )
    }

    private static func stratifyByNBucket(results: [SingleTestResult]) -> [String: AggregateTestResult.BucketStats] {
        Dictionary(grouping: results, by: { $0.nBucket })
            .mapValues { computeBucketStats(results: $0) }
    }

    private static func stratifyByDomain(results: [SingleTestResult]) -> [String: AggregateTestResult.BucketStats] {
        Dictionary(grouping: results, by: { $0.domain })
            .mapValues { computeBucketStats(results: $0) }
    }

    private static func stratifyByDecoder(results: [SingleTestResult]) -> [String: AggregateTestResult.BucketStats] {
        Dictionary(grouping: results, by: { $0.decoderId })
            .mapValues { computeBucketStats(results: $0) }
    }

    private static func computeBucketStats(results: [SingleTestResult]) -> AggregateTestResult.BucketStats {
        let passAtNRate = Double(results.filter { $0.passAtN }.count) / Double(max(1, results.count))
        let uniqueItems = results.map { Double($0.uniqueItems) }
        let dupRates = results.map { $0.dupRate }
        let timesPerUnique = results.map { $0.timePerUnique }

        return AggregateTestResult.BucketStats(
            count: results.count,
            passAtNRate: passAtNRate,
            meanUniqueItems: mean(uniqueItems),
            meanDupRate: mean(dupRates),
            stdevDupRate: stdev(dupRates),
            meanTimePerUnique: mean(timesPerUnique),
            jsonStrictRate: Double(results.filter { $0.jsonStrict }.count) / Double(max(1, results.count))
        )
    }

    // MARK: - Rankings

    private static func computeRankings(aggregates: [AggregateTestResult]) -> TestReport.Rankings {
        let byPassRate = rankBy(aggregates: aggregates, metric: "passAtN", getter: { $0.overallStats.passAtNRate })
        let byQuality = rankBy(aggregates: aggregates, metric: "quality", getter: { $0.overallStats.meanQualityScore })
        let bySpeed = rankBy(aggregates: aggregates, metric: "speed", getter: { 1.0 / max(0.001, $0.overallStats.meanTimePerUnique) })
        let byConsistency = rankBy(aggregates: aggregates, metric: "consistency", getter: { 1.0 / max(0.001, $0.overallStats.seedVariance) })

        return TestReport.Rankings(
            byPassRate: byPassRate,
            byQuality: byQuality,
            bySpeed: bySpeed,
            byConsistency: byConsistency
        )
    }

    private static func rankBy(
        aggregates: [AggregateTestResult],
        metric: String,
        getter: (AggregateTestResult) -> Double
    ) -> [TestReport.Rankings.RankedPrompt] {
        aggregates
            .map { (aggregate: $0, score: getter($0)) }
            .sorted { $0.score > $1.score }
            .enumerated()
            .map { index, item in
                TestReport.Rankings.RankedPrompt(
                    rank: index + 1,
                    promptId: item.aggregate.promptId,
                    promptName: item.aggregate.promptName,
                    score: item.score,
                    metric: metric
                )
            }
    }

    // MARK: - Utilities

    private static func resolvePrompts(ids: [String], library: SystemPromptsLibrary) throws -> [SystemPromptConfig] {
        if ids == ["*"] {
            return library.prompts
        }
        return try ids.map { id in
            guard let prompt = library.prompts.first(where: { $0.id == id }) else {
                throw TestingError.configurationNotFound("Prompt '\(id)' not found")
            }
            try ConfigValidator.validate(prompt)
            return prompt
        }
    }

    private static func resolveQueries(ids: [String], library: TestQueriesLibrary) throws -> [TestQueryConfig] {
        if ids == ["*"] {
            return library.queries
        }
        return try ids.map { id in
            guard let query = library.queries.first(where: { $0.id == id }) else {
                throw TestingError.configurationNotFound("Query '\(id)' not found")
            }
            try ConfigValidator.validate(query)
            return query
        }
    }

    private static func resolveDecoders(ids: [String], library: DecodingConfigsLibrary) throws -> [DecodingConfigDef] {
        if ids == ["*"] {
            return library.configs
        }
        return try ids.map { id in
            guard let decoder = library.configs.first(where: { $0.id == id }) else {
                throw TestingError.configurationNotFound("Decoder '\(id)' not found")
            }
            try ConfigValidator.validate(decoder)
            return decoder
        }
    }

    private static func estimateTimeRemaining(completed: Int, total: Int, elapsed: TimeInterval) -> TimeInterval? {
        guard completed > 0 else { return nil }
        let avgTime = elapsed / Double(completed)
        let remaining = total - completed
        return avgTime * Double(remaining)
    }

    /// Save checkpoint of intermediate results (for crash recovery and progress monitoring)
    /// Note: Lightweight checkpoint - only stores high-level stats to avoid bloating sandbox writes
    private static func saveCheckpoint(
        suite: TestSuiteConfig,
        results: [SingleTestResult],
        completed: Int,
        total: Int
    ) {
        let checkpointPath = NSTemporaryDirectory()
            .appending("tiercade_test_checkpoint.json")

        // Lightweight checkpoint: only store high-level stats, not full results
        let checkpoint: [String: Any] = [
            "suiteId": suite.id,
            "suiteName": suite.name,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "completed": completed,
            "total": total,
            "successCount": results.filter { $0.isSuccess }.count,
            "failureCount": results.filter { !$0.isSuccess }.count,
            "meanDupRate": results.isEmpty ? 0.0 : results.map { $0.dupRate }.reduce(0, +) / Double(results.count)
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: checkpoint, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: checkpointPath))
        } catch {
            // Checkpoint failures shouldn't halt tests - just log
            print("⚠️ Failed to save checkpoint: \(error.localizedDescription)")
        }
    }

    private static func createErrorResult(run: TestRun, context: TestRunContext, error: Error) -> SingleTestResult {
        SingleTestResult(
            id: UUID(),
            timestamp: Date(),
            promptId: run.prompt.id,
            promptName: run.prompt.name,
            queryId: run.query.id,
            queryText: run.query.query,
            targetCount: run.query.targetCount,
            domain: run.query.domain,
            nBucket: run.nBucket,
            decoderId: run.decoder.id,
            decoderName: run.decoder.name,
            seed: run.seed,
            guidedSchema: run.useGuidedSchema,
            response: "ERROR: \(error.localizedDescription)",
            parsedItems: [],
            normalizedItems: [],
            totalItems: 0,
            uniqueItems: 0,
            duplicateCount: 0,
            dupRate: 1.0,
            passAtN: false,
            surplusAtN: -run.effectiveTarget,
            jsonStrict: false,
            insufficient: true,
            formatError: true,
            finishReason: "error",
            wasTruncated: false,
            maxTokensUsed: context.maxTokens,
            duration: 0,
            timePerUnique: 0
        )
    }

    private static func getEnvironmentInfo() -> TestReport.EnvironmentInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return TestReport.EnvironmentInfo(
            osVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            osVersionString: ProcessInfo.processInfo.operatingSystemVersionString,
            hasTopP: true,  // iOS 26+ always has topP
            device: nil,
            buildDate: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Math Utilities

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        let m = mean(values)
        let squaredDiffs = values.map { pow($0 - m, 2) }
        return mean(squaredDiffs)
    }

    private static func stdev(_ values: [Double]) -> Double {
        sqrt(variance(values))
    }

    // MARK: - Timeout Helper

    private nonisolated static func withTimeout<T: Sendable>(
        seconds: Int,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TestingError.timeout
            }

            guard let result = try await group.next() else {
                throw TestingError.timeout
            }

            group.cancelAll()
            return result
        }
    }
}
#endif
