import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// swiftlint:disable file_length function_body_length type_body_length cyclomatic_complexity
// Prototype test framework - comprehensive test orchestration justifies complexity

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

    // MARK: Internal

    // MARK: - Config Loading

    /// Load system prompts from SystemPrompts.json
    static func loadSystemPrompts() throws -> SystemPromptsLibrary {
        guard
            let url = Bundle.main.url(
                forResource: "SystemPrompts", withExtension: "json", subdirectory: "TestConfigs",
            )
        else {
            throw TestingError.configurationNotFound("SystemPrompts.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load test queries from TestQueries.json
    static func loadTestQueries() throws -> TestQueriesLibrary {
        guard
            let url = Bundle.main.url(
                forResource: "TestQueries", withExtension: "json", subdirectory: "TestConfigs",
            )
        else {
            throw TestingError.configurationNotFound("TestQueries.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load decoding configs from DecodingConfigs.json
    static func loadDecodingConfigs() throws -> DecodingConfigsLibrary {
        guard
            let url = Bundle.main.url(
                forResource: "DecodingConfigs", withExtension: "json", subdirectory: "TestConfigs",
            )
        else {
            throw TestingError.configurationNotFound("DecodingConfigs.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    /// Load test suites from TestSuites.json
    static func loadTestSuites() throws -> TestSuitesLibrary {
        guard
            let url = Bundle.main.url(
                forResource: "TestSuites", withExtension: "json", subdirectory: "TestConfigs",
            )
        else {
            throw TestingError.configurationNotFound("TestSuites.json in TestConfigs/")
        }
        return try loadJSON(from: url)
    }

    // MARK: - Suite Execution

    /// Run a predefined test suite
    static func runSuite(
        suiteId: String,
        onProgress: @escaping @MainActor (String) -> Void,
    ) async throws
    -> TestReport {
        await MainActor.run { onProgress("📦 Loading test suite '\(suiteId)'...") }

        // 🔍 DEBUG: Log suite loading
        debugLog("╔═══════════════════════════════════════════════════════════════")
        debugLog("║ UNIFIED PROMPT TESTER - TEST SUITE EXECUTION")
        debugLog("╠═══════════════════════════════════════════════════════════════")
        debugLog("║ Suite ID: \(suiteId)")
        debugLog("║ Start Time: \(Date())")
        debugLog("╚═══════════════════════════════════════════════════════════════")
        debugLog("")

        // Load all configurations
        let suitesLib = try loadTestSuites()
        guard let suite = suitesLib.suites.first(where: { $0.id == suiteId }) else {
            throw TestingError.configurationNotFound("Test suite '\(suiteId)' not found")
        }

        try ConfigValidator.validate(suite)

        let promptsLib = try loadSystemPrompts()
        let queriesLib = try loadTestQueries()
        let decodersLib = try loadDecodingConfigs()

        await MainActor.run { onProgress("✅ Loaded configurations") }
        await MainActor.run { onProgress("📝 Suite: \(suite.name)") }
        await MainActor.run { onProgress("📋 Description: \(suite.description)") }

        // 🔍 DEBUG: Log loaded config counts
        debugLog("📚 LOADED CONFIGURATION LIBRARIES:")
        debugLog("  System Prompts: \(promptsLib.prompts.count) available")
        debugLog("  Test Queries: \(queriesLib.queries.count) available")
        debugLog("  Decoding Configs: \(decodersLib.configs.count) available")
        debugLog("")

        // Resolve IDs to actual configs (handle wildcards)
        let prompts = try resolvePrompts(ids: suite.config.promptIds, library: promptsLib)
        let queries = try resolveQueries(ids: suite.config.queryIds, library: queriesLib)
        let decoders = try resolveDecoders(ids: suite.config.decoderIds, library: decodersLib)

        // 🔍 DEBUG: Log resolved configurations
        debugLog("🎯 SUITE CONFIGURATION:")
        debugLog("  Name: \(suite.name)")
        debugLog("  Description: \(suite.description)")
        debugLog("  Timeout: \(suite.config.timeoutSeconds ?? 60)s")
        debugLog("  Max Tokens Override: \(suite.config.maxTokensOverride.map { String($0) } ?? "auto")")
        debugLog("")
        debugLog("🎲 SELECTED PROMPTS (\(prompts.count)):")
        for prompt in prompts {
            debugLog("  • [\(prompt.id)] \(prompt.name) (\(prompt.category))")
        }
        debugLog("")
        debugLog("❓ SELECTED QUERIES (\(queries.count)):")
        for query in queries {
            debugLog("  • [\(query.id)] target=\(query.targetCount ?? 40), domain=\(query.domain)")
            debugLog("    Query: \(query.query)")
        }
        debugLog("")
        debugLog("⚙️ SELECTED DECODERS (\(decoders.count)):")
        for decoder in decoders {
            debugLog("  • [\(decoder.id)] \(decoder.name)")
            debugLog("    Mode: \(decoder.sampling.mode), Temp: \(decoder.temperature)")
        }
        debugLog("")
        debugLog("🎲 SEEDS: \(suite.config.seeds)")
        debugLog("🧬 GUIDED MODES: \(suite.config.guidedModes)")
        debugLog("")

        // swiftlint:disable:next line_length - Progress message should remain readable as single line
        await MainActor
            .run {
                onProgress(
                    "🎯 Test matrix: \(prompts.count) prompts × \(queries.count) queries × \(decoders.count) decoders × \(suite.config.seeds.count) seeds × \(suite.config.guidedModes.count) modes",
                )
            }

        // Build test runs
        let testRuns = buildTestRuns(
            prompts: prompts,
            queries: queries,
            decoders: decoders,
            seeds: suite.config.seeds,
            guidedModes: suite.config.guidedModes,
        )

        await MainActor.run { onProgress("🚀 Starting \(testRuns.count) test runs...") }

        // Execute tests
        let results = await executeTestRuns(
            testRuns,
            suite: suite,
            timeoutSeconds: suite.config.timeoutSeconds ?? 60,
            maxTokensOverride: suite.config.maxTokensOverride,
            onProgress: onProgress,
        )

        // Aggregate results
        let report = try aggregateResults(
            suite: suite,
            results: results,
            prompts: prompts,
        )

        return report
    }

    // MARK: Private

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

    /// Generic JSON loading
    private static func loadJSON<T: Decodable>(from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Test Run Building

    private static func buildTestRuns(
        prompts: [SystemPromptConfig],
        queries: [TestQueryConfig],
        decoders: [DecodingConfigDef],
        seeds: [UInt64],
        guidedModes: [Bool],
    )
    -> [TestRun] {
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
                                useGuidedSchema: guided,
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
        onProgress: @escaping @MainActor (String) -> Void,
    ) async
    -> [SingleTestResult] {
        var results: [SingleTestResult] = []
        let startTime = Date()

        for (index, run) in runs.enumerated() {
            // Yield to allow UI updates before each test run
            await Task.yield()

            await MainActor.run {
                onProgress("[\(index + 1)/\(runs.count)] Testing '\(run.prompt.name)' on '\(run.query.id)'...")
            }

            let context = TestRunContext(run: run, maxTokensOverride: maxTokensOverride)

            do {
                // Show that we're starting the test execution
                await MainActor.run { onProgress("⏳ Creating session and executing...") }

                let result = try await executeTestRun(run, context: context, timeoutSeconds: timeoutSeconds)
                results.append(result)

                let status = result.isSuccess ? "✅" : "❌"
                let dupPct = String(format: "%.1f", result.dupRate * 100)
                await MainActor.run {
                    onProgress("\(status) \(result.uniqueItems)/\(run.effectiveTarget) unique (\(dupPct)% dup)")
                }
            } catch {
                await MainActor.run { onProgress("❌ Error: \(error.localizedDescription)") }

                // Create error result
                let errorResult = createErrorResult(run: run, context: context, error: error)
                results.append(errorResult)
            }

            // Show periodic progress summary for long-running suites
            if (index + 1) % 10 == 0 || (index + 1) == runs.count {
                let percentage = (index + 1) * 100 / runs.count
                let successCount = results.count(where: { $0.isSuccess })
                let successRate = successCount * 100 / max(1, results.count)
                let elapsed = Date().timeIntervalSince(startTime)
                let elapsedStr = String(format: "%.1f", elapsed)
                await MainActor.run {
                    let progress = "📊 Progress: \(index + 1)/\(runs.count) (\(percentage)%)"
                    onProgress("\(progress) - Success: \(successRate)% - Elapsed: \(elapsedStr)s")
                }
            }

            // Save checkpoint every 50 runs for crash recovery
            if (index + 1) % 50 == 0 {
                saveCheckpoint(suite: suite, results: results, completed: index + 1, total: runs.count)
                await MainActor.run { onProgress("💾 Checkpoint saved (\(index + 1)/\(runs.count) tests)") }
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
        timeoutSeconds: Int,
    ) async throws
    -> SingleTestResult {
        let startTime = Date()

        // Render prompt with substitutions
        let template = PromptTemplate(raw: run.prompt.text)
        let substitutions: [PromptTemplate.Variable: String] = [
            .query: run.query.query,
            .targetCount: String(run.effectiveTarget),
            .domain: run.query.domain,
        ]
        let renderedPrompt = template.render(substitutions: substitutions)

        // 🔍 DEBUG: Log prompt rendering details
        debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        debugLog("🧪 TEST RUN #\(run.runNumber) - PROMPT RENDERING")
        debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        debugLog("Prompt ID: \(run.prompt.id)")
        debugLog("Prompt Name: \(run.prompt.name)")
        debugLog("Query ID: \(run.query.id)")
        debugLog("Query Text: \(run.query.query)")
        debugLog("")
        debugLog("📋 TEMPLATE VARIABLES:")
        for (variable, value) in substitutions {
            debugLog("  \(variable.rawValue) → \"\(value)\"")
        }
        debugLog("")
        debugLog("📝 RAW TEMPLATE (\(run.prompt.text.count) chars):")
        debugLog(run.prompt.text)
        debugLog("")
        debugLog("✨ RENDERED PROMPT (\(renderedPrompt.count) chars):")
        debugLog(renderedPrompt)
        debugLog("")

        // Create session
        let instructions = Instructions(renderedPrompt)
        let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)

        let opts = run.decoder.toGenerationOptions(seed: run.seed, maxTokens: context.maxTokens)

        // 🔍 DEBUG: Log generation parameters
        debugLog("⚙️ GENERATION PARAMETERS:")
        debugLog("  Decoder: \(run.decoder.id) (\(run.decoder.name))")
        debugLog("  Sampling Mode: \(run.decoder.sampling.mode)")
        if let k = run.decoder.sampling.k {
            debugLog("  Top-K: \(k)")
        }
        if let threshold = run.decoder.sampling.threshold {
            debugLog("  Top-P Threshold: \(threshold)")
        }
        debugLog("  Temperature: \(run.decoder.temperature)")
        debugLog("  Seed: \(run.seed)")
        debugLog("  Max Tokens: \(context.maxTokens)")
        debugLog("  Guided Schema: \(run.useGuidedSchema)")
        debugLog("  Target Count: \(run.effectiveTarget)")
        debugLog("  Timeout: \(timeoutSeconds)s")
        debugLog("")

        // Execute generation with timeout - use guided generation if requested
        debugLog("🚀 EXECUTING GENERATION...")
        let responseContent: String
        do {
            if run.useGuidedSchema {
                // Guided generation: constrained sampling with @Generable type
                debugLog("  Mode: Guided (using StringList @Generable)")
                let items = try await withTimeout(seconds: timeoutSeconds) {
                    let response = try await session.respond(
                        to: Prompt(run.query.query),
                        generating: StringList.self,
                        includeSchemaInPrompt: true,
                        options: opts,
                    )
                    return response.content.items
                }
                // Convert StringList to JSON string for consistent analysis
                let encoder = JSONEncoder()
                let data = try encoder.encode(items)
                responseContent = String(data: data, encoding: .utf8) ?? "[]"
                debugLog("  ✅ Guided generation complete: \(items.count) items")
            } else {
                // Unguided generation: free-form response
                debugLog("  Mode: Unguided (free-form response)")
                responseContent = try await withTimeout(seconds: timeoutSeconds) {
                    try await session.respond(to: Prompt(run.query.query), options: opts).content
                }
                debugLog("  ✅ Unguided generation complete: \(responseContent.count) chars")
            }
        } catch {
            // Verbose error logging for LanguageModel failures
            debugLog("🔴 LanguageModel Error: \(error)")
            debugLog("🔴   Prompt: \(run.prompt.id)")
            debugLog("🔴   Query: \(run.query.id)")
            debugLog("🔴   Decoder: \(run.decoder.id)")
            debugLog("🔴   Guided: \(run.useGuidedSchema)")
            debugLog("🔴   Error type: \(type(of: error))")
            debugLog("🔴   Error description: \(error.localizedDescription)")
            debugLog("")

            print("🔴 LanguageModel Error: \(error)")
            print("🔴   Prompt: \(run.prompt.id)")
            print("🔴   Query: \(run.query.id)")
            print("🔴   Decoder: \(run.decoder.id)")
            print("🔴   Guided: \(run.useGuidedSchema)")
            print("🔴   Error type: \(type(of: error))")
            throw error
        }

        let duration = Date().timeIntervalSince(startTime)

        // 🔍 DEBUG: Log response details
        debugLog("📥 RAW RESPONSE (\(responseContent.count) chars):")
        debugLog(responseContent)
        debugLog("")
        debugLog("⏱️ Generation Duration: \(String(format: "%.2f", duration))s")
        debugLog("")

        // Analyze response
        let analysis = analyzeResponse(responseContent, targetCount: run.effectiveTarget)

        // 🔍 DEBUG: Log analysis results
        debugLog("📊 ANALYSIS RESULTS:")
        debugLog("  Parsed Items: \(analysis.parsedItems.count)")
        debugLog("  Total Items: \(analysis.totalItems)")
        debugLog("  Unique Items: \(analysis.uniqueItems)")
        debugLog("  Duplicates: \(analysis.duplicateCount)")
        debugLog("  Dup Rate: \(String(format: "%.1f%%", analysis.dupRate * 100))")
        debugLog("  Pass@N: \(analysis.passAtN ? "✅ PASS" : "❌ FAIL")")
        debugLog("  Surplus: \(analysis.surplusAtN)")
        debugLog("  Insufficient: \(analysis.insufficient ? "⚠️ YES" : "✅ NO")")
        debugLog("  Format Error: \(analysis.formatError ? "❌ YES" : "✅ NO")")
        debugLog("  JSON Parsed: \(analysis.wasJsonParsed ? "✅ YES" : "❌ NO")")
        debugLog("")
        if !analysis.parsedItems.isEmpty {
            debugLog("🔍 PARSED ITEMS (\(analysis.parsedItems.count)):")
            for (index, item) in analysis.parsedItems.enumerated() {
                debugLog("  \(index + 1). \(item)")
            }
            debugLog("")
        }
        if !analysis.normalizedItems.isEmpty {
            debugLog("🔍 NORMALIZED (UNIQUE) ITEMS (\(analysis.normalizedItems.count)):")
            for (index, item) in analysis.normalizedItems.enumerated() {
                debugLog("  \(index + 1). \(item)")
            }
            debugLog("")
        }
        debugLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        debugLog("")

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
            finishReason: "stop", // Default until Apple exposes this in the API
            wasTruncated: false, // Cannot detect without finishReason
            maxTokensUsed: context.maxTokens,
            duration: duration,
            timePerUnique: analysis.uniqueItems > 0 ? duration / Double(analysis.uniqueItems) : duration,
        )
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
        // Strip markdown code blocks (```json ... ```)
        var cleanedResponse = response

        // Remove markdown code fence with optional language specifier
        let markdownPattern = #"^```(?:json)?\s*\n?(.*?)\n?```$"#
        let regexOpts: NSRegularExpression.Options = [.dotMatchesLineSeparators]
        if
            let regex = try? NSRegularExpression(pattern: markdownPattern, options: regexOpts),
            let match = regex.firstMatch(
                in: response, options: [],
                range: NSRange(response.startIndex..., in: response),
            ),
            let contentRange = Range(match.range(at: 1), in: response)
        {
            cleanedResponse = String(response[contentRange])
        }

        // Also try simpler pattern for cases like ```json on first line
        if cleanedResponse.hasPrefix("```") {
            let lines = cleanedResponse.components(separatedBy: .newlines)
            if lines.count > 2 {
                // Skip first and last line
                cleanedResponse = lines.dropFirst().dropLast().joined(separator: "\n")
            }
        }

        let trimmed = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return nil
        }

        // Try parsing as bare array first: ["item1", "item2", ...]
        if let items = try? JSONDecoder().decode([String].self, from: data) {
            return items
        }

        // Try parsing as envelope format: {"items": ["item1", "item2", ...]}
        if
            let envelope = try? JSONDecoder().decode([String: [String]].self, from: data),
            let items = envelope["items"]
        {
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
        let normalized = items.map(\.normKey)

        // Count unique
        let uniqueSet = Set(normalized)
        let uniqueItems = uniqueSet.count
        let duplicateCount = items.count - uniqueItems
        let dupRate = !items.isEmpty ? Double(duplicateCount) / Double(items.count) : 0.0

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
            wasJsonParsed: wasJsonParsed,
        )
    }

    // MARK: - Result Aggregation

    private static func aggregateResults(
        suite: TestSuiteConfig,
        results: [SingleTestResult],
        prompts: [SystemPromptConfig],
    ) throws
    -> TestReport {
        var aggregates: [AggregateTestResult] = []

        for prompt in prompts {
            let promptResults = results.filter { $0.promptId == prompt.id }
            guard !promptResults.isEmpty else {
                continue
            }

            let aggregate = aggregatePromptResults(prompt: prompt, results: promptResults)
            aggregates.append(aggregate)
        }

        let rankings = computeRankings(aggregates: aggregates)

        let successfulRuns = results.count(where: { $0.isSuccess })
        let totalDuration = results.map(\.duration).reduce(0, +)

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
            rankings: rankings,
        )
    }

    private static func aggregatePromptResults(
        prompt: SystemPromptConfig,
        results: [SingleTestResult],
    )
    -> AggregateTestResult {
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
            worstRun: worstRun,
        )
    }

    private static func computeOverallStats(results: [SingleTestResult]) -> AggregateTestResult.OverallStats {
        let passAtNRate = Double(results.count(where: { $0.passAtN })) / Double(max(1, results.count))
        let uniqueItems = results.map { Double($0.uniqueItems) }
        let dupRates = results.map(\.dupRate)
        let timesPerUnique = results.map(\.timePerUnique)
        let qualityScores = results.map(\.qualityScore)

        return AggregateTestResult.OverallStats(
            passAtNRate: passAtNRate,
            meanUniqueItems: mean(uniqueItems),
            stdevUniqueItems: stdev(uniqueItems),
            meanDupRate: mean(dupRates),
            stdevDupRate: stdev(dupRates),
            meanTimePerUnique: mean(timesPerUnique),
            stdevTimePerUnique: stdev(timesPerUnique),
            jsonStrictRate: Double(results.count(where: { $0.jsonStrict })) / Double(max(1, results.count)),
            truncationRate: Double(results.count(where: { $0.wasTruncated })) / Double(max(1, results.count)),
            insufficientRate: Double(results.count(where: { $0.insufficient })) / Double(max(1, results.count)),
            formatErrorRate: Double(results.count(where: { $0.formatError })) / Double(max(1, results.count)),
            meanQualityScore: mean(qualityScores),
            seedVariance: variance(uniqueItems),
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
        let passAtNRate = Double(results.count(where: { $0.passAtN })) / Double(max(1, results.count))
        let uniqueItems = results.map { Double($0.uniqueItems) }
        let dupRates = results.map(\.dupRate)
        let timesPerUnique = results.map(\.timePerUnique)

        return AggregateTestResult.BucketStats(
            count: results.count,
            passAtNRate: passAtNRate,
            meanUniqueItems: mean(uniqueItems),
            meanDupRate: mean(dupRates),
            stdevDupRate: stdev(dupRates),
            meanTimePerUnique: mean(timesPerUnique),
            jsonStrictRate: Double(results.count(where: { $0.jsonStrict })) / Double(max(1, results.count)),
        )
    }

    // MARK: - Rankings

    private static func computeRankings(aggregates: [AggregateTestResult]) -> TestReport.Rankings {
        let byPassRate = rankBy(
            aggregates: aggregates, metric: "passAtN", getter: { $0.overallStats.passAtNRate },
        )
        let byQuality = rankBy(
            aggregates: aggregates, metric: "quality", getter: { $0.overallStats.meanQualityScore },
        )
        let bySpeed = rankBy(
            aggregates: aggregates, metric: "speed",
            getter: { 1.0 / max(0.001, $0.overallStats.meanTimePerUnique) },
        )
        let byConsistency = rankBy(
            aggregates: aggregates, metric: "consistency",
            getter: { 1.0 / max(0.001, $0.overallStats.seedVariance) },
        )

        return TestReport.Rankings(
            byPassRate: byPassRate,
            byQuality: byQuality,
            bySpeed: bySpeed,
            byConsistency: byConsistency,
        )
    }

    private static func rankBy(
        aggregates: [AggregateTestResult],
        metric: String,
        getter: (AggregateTestResult) -> Double,
    )
    -> [TestReport.Rankings.RankedPrompt] {
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
                    metric: metric,
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
        guard completed > 0 else {
            return nil
        }
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
        total: Int,
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
            "successCount": results.count(where: { $0.isSuccess }),
            "failureCount": results.count(where: { !$0.isSuccess }),
            "meanDupRate": results.isEmpty ? 0.0 : results.map(\.dupRate).reduce(0, +) / Double(results.count),
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
            timePerUnique: 0,
        )
    }

    private static func getEnvironmentInfo() -> TestReport.EnvironmentInfo {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return TestReport.EnvironmentInfo(
            osVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            osVersionString: ProcessInfo.processInfo.operatingSystemVersionString,
            hasTopP: true, // iOS 26+ always has topP
            device: nil,
            buildDate: ISO8601DateFormatter().string(from: Date()),
        )
    }

    // MARK: - Math Utilities

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0.0
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else {
            return 0.0
        }
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
        operation: @Sendable @escaping () async throws -> T,
    ) async throws
    -> T {
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

    // MARK: - Debug Logging

    /// Enhanced debug logging that writes to both console and file
    private static func debugLog(_ message: String) {
        // Write to console
        print("🔍 \(message)")

        // Write to debug file
        let logPath = NSTemporaryDirectory().appending("tiercade_prompt_test_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                // Append to existing file
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: URL(fileURLWithPath: logPath), options: .atomic)
            }
        }
    }
}
// swiftlint:enable function_body_length type_body_length cyclomatic_complexity
#endif
