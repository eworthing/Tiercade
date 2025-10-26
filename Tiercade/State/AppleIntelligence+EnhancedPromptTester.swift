// ============================================================================
// COMPREHENSIVE PROMPT TESTING FRAMEWORK - FINAL VERSION
// ============================================================================
// All improvements from ChatGPT feedback integrated:
// - Dynamic token budgets per query
// - Finish reason logging and truncation tracking
// - Fresh session per run (no shared state)
// - Enhanced metrics: surplus@N, jsonStrict%, timePerUnique, seed variance
// - Stratified reporting by N-bucket and domain
// - Pilot configuration (192 runs)
// - New prompts: G7-G11, F2-F3
// ============================================================================

import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

@MainActor
class EnhancedPromptTester {

    // MARK: - Configuration

    enum SamplingMode {
        case greedy
        case topP(Double)
        case topK(Int)
    }

    struct DecodingConfig {
        let name: String
        let sampling: SamplingMode
        let temperature: Double

        func generationOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
            switch sampling {
            case .greedy:
                return GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.0,
                    maximumResponseTokens: maxTokens
                )
            case .topP(let threshold):
                return GenerationOptions(
                    sampling: .random(probabilityThreshold: threshold, seed: seed),
                    temperature: temperature,
                    maximumResponseTokens: maxTokens
                )
            case .topK(let k):
                return GenerationOptions(
                    sampling: .random(top: k, seed: seed),
                    temperature: temperature,
                    maximumResponseTokens: maxTokens
                )
            }
        }
    }

    struct TestQuery {
        let query: String
        let target: Int?
        let domain: String
    }

    struct TestConfig {
        // PILOT CONFIGURATION: Reduced grid for speed validation
        let seeds: [UInt64] = [42, 1337]  // 2 seeds

        let testQueries: [TestQuery] = [
            TestQuery(query: "top 15 most popular fruits", target: 15, domain: "food"),  // Small
            TestQuery(query: "best places to live in the United States", target: 50, domain: "geography"),  // Medium
            TestQuery(query: "best video games released in 2020-2023", target: 150, domain: "media"),  // Large
            // Open (treat as 40)
            TestQuery(query: "What are the most popular candy bars?", target: nil, domain: "food")
        ]

        let decodingConfigs: [DecodingConfig] = [
            // PILOT: 3 decoders
            DecodingConfig(name: "Greedy", sampling: .greedy, temperature: 0.0),
            DecodingConfig(name: "TopK50-T0.8", sampling: .topK(50), temperature: 0.8),
            DecodingConfig(name: "TopP92-T0.8", sampling: .topP(0.92), temperature: 0.8)
        ]

        let guidedModes: [Bool] = [false, true]

        // PILOT: Test 4 prompts only (G0, G2, G3, G6)
        // Full grid: 4 prompts × 4 queries × 3 decoders × 2 seeds × 2 guided = 192 runs (~15 min)

        // Dynamic token budget
        func dynamicMaxTokens(targetCount: Int, overgenFactor: Double) -> Int {
            let tokensPerItem = 6
            let calculated = Int(ceil(Double(targetCount) * overgenFactor * Double(tokensPerItem) * 1.3))
            return min(3000, calculated)
        }

        func overgenFactor(for targetCount: Int) -> Double {
            if targetCount <= 50 { return 1.4 }
            if targetCount <= 150 { return 1.6 }
            return 2.0
        }

        func nBucket(for targetCount: Int?) -> String {
            guard let n = targetCount else { return "open" }
            if n <= 25 { return "small" }
            if n <= 50 { return "medium" }
            return "large"
        }
    }

    // MARK: - Results

    struct SingleRunResult: Sendable {
        let promptNumber: Int
        let promptName: String
        let runNumber: Int
        let seed: UInt64
        let query: String
        let targetCount: Int?
        let domain: String
        let nBucket: String
        let decodingName: String
        let guidedSchema: Bool
        let response: String
        let parsedItems: [String]
        let normalizedItems: [String]
        let totalItems: Int
        let uniqueItems: Int
        let duplicateCount: Int
        let dupRate: Double
        let passAtN: Bool
        let surplusAtN: Int  // max(0, unique - N)
        let jsonStrict: Bool  // Parsed as JSON array (not fallback)
        let insufficient: Bool
        let formatError: Bool
        let wasJsonParsed: Bool
        let finishReason: String?
        let wasTruncated: Bool
        let maxTokensUsed: Int
        let duration: TimeInterval
        let timePerUnique: Double  // duration / max(1, unique)
    }

    struct AggregateResult {
        let promptNumber: Int
        let promptName: String
        let promptText: String
        let totalRuns: Int
        let nBucket: String
        let domain: String

        // SORTED BY PRIORITY
        let passAtNRate: Double
        let meanUniqueItems: Double
        let jsonStrictRate: Double
        let meanTimePerUnique: Double
        let meanDupRate: Double
        let stdevDupRate: Double
        let meanSurplusAtN: Double
        let truncationRate: Double
        let seedVariance: Double  // stdev of unique@N across seeds
        let insufficientRate: Double
        let formatErrorRate: Double

        let bestRun: SingleRunResult?
        let worstRun: SingleRunResult?
        let allRuns: [SingleRunResult]
    }

    // MARK: - Guided Schema

    @Generable
    struct StringList: Codable {
        let items: [String]
    }

    // MARK: - Testing

    static func testPrompts(
        config: TestConfig = TestConfig(),
        onProgress: @MainActor @escaping (String) -> Void
    ) async -> [AggregateResult] {
        var aggregateResults: [AggregateResult] = []

        logTestHeader(config: config, onProgress: onProgress)

        let totalRuns = calculateTotalRuns(config: config)
        var completedTests = 0

        let pilotPrompts = selectPilotPrompts()

        for (promptIndex, (promptName, promptText)) in pilotPrompts {
            let promptNumber = promptIndex + 1
            onProgress("\n📝 Testing Prompt: \(promptName)")

            let runResults = await executePromptTestRuns(
                context: TestExecutionContext(
                    config: config,
                    promptNumber: promptNumber,
                    promptName: promptName,
                    promptText: promptText,
                    totalRuns: totalRuns
                ),
                completedTests: &completedTests,
                onProgress: onProgress
            )

            let aggregate = computeAggregate(
                config: config,
                promptNumber: promptNumber,
                promptName: promptName,
                promptText: promptText,
                runs: runResults
            )

            aggregateResults.append(aggregate)
            logAggregateResult(aggregate, promptName: promptName, onProgress: onProgress)
        }

        logTestCompletion(completedTests: completedTests, onProgress: onProgress)
        await saveAllResults(aggregateResults)

        return aggregateResults
    }

    private static func logTestHeader(
        config: TestConfig,
        onProgress: @MainActor @escaping (String) -> Void
    ) {
        clearLogFile()

        logToFile("🧪 ========================================")
        logToFile("🧪 PILOT TEST - FINAL FRAMEWORK")
        logToFile("🧪 ========================================")

        onProgress("🧪 ========================================")
        onProgress("🧪 PILOT TEST (pass@N primary, stratified reporting)")
        onProgress("🧪 ========================================")

        let totalRuns = calculateTotalRuns(config: config)
        onProgress("  • Prompts: 4 (G0, G2, G3, G6 - pilot subset)")
        onProgress("  • Queries: \(config.testQueries.count) (small/medium/large/open)")
        onProgress("  • Decoders: \(config.decodingConfigs.count) (Greedy, TopK, TopP)")
        onProgress("  • Seeds: \(config.seeds.count) (fixed)")
        onProgress("  • Guided: \(config.guidedModes.count) (plain + @Generable)")
        onProgress("  • Total runs: \(totalRuns)")
        onProgress("  • Dynamic maxTokens per query")
        onProgress("")

        logToFile("Total runs: \(totalRuns)")
        logToFile("Dynamic token budgets enabled")
        logToFile("Fresh session per run")
        logToFile("")
    }

    private static func calculateTotalRuns(config: TestConfig) -> Int {
        4 * config.testQueries.count * config.decodingConfigs.count *
        config.seeds.count * config.guidedModes.count
    }

    private static func selectPilotPrompts() -> [(Int, (name: String, text: String))] {
        [
            (0, enhancedPrompts[0]),
            (2, enhancedPrompts[2]),
            (3, enhancedPrompts[3]),
            (6, enhancedPrompts[6])
        ]
    }

    private static func executePromptTestRuns(
        context: TestExecutionContext,
        completedTests: inout Int,
        onProgress: @MainActor @escaping (String) -> Void
    ) async -> [SingleRunResult] {
        var runResults: [SingleRunResult] = []

        for testQuery in context.config.testQueries {
            let query = testQuery.query
            let target = testQuery.target
            let domain = testQuery.domain
            for decodingConfig in context.config.decodingConfigs {
                for seed in context.config.seeds {
                    for guided in context.config.guidedModes {
                        let result = await testSingleRun(SingleRunParameters(
                            config: context.config,
                            promptNumber: context.promptNumber,
                            promptName: context.promptName,
                            promptText: context.promptText,
                            runNumber: completedTests + 1,
                            query: query,
                            targetCount: target,
                            domain: domain,
                            decodingConfig: decodingConfig,
                            seed: seed,
                            useGuidedSchema: guided
                        ))

                        runResults.append(result)
                        completedTests += 1

                        if completedTests % 10 == 0 {
                            logProgressUpdate(
                                result: result,
                                completedTests: completedTests,
                                totalRuns: context.totalRuns,
                                domain: domain,
                                onProgress: onProgress
                            )
                        }
                    }
                }
            }
        }

        return runResults
    }

    private static func logProgressUpdate(
        result: SingleRunResult,
        completedTests: Int,
        totalRuns: Int,
        domain: String,
        onProgress: @MainActor @escaping (String) -> Void
    ) {
        let passIcon = result.passAtN ? "✅" : "❌"
        onProgress(
            "   [\(completedTests)/\(totalRuns)] \(passIcon) " +
            "\(result.nBucket)/\(domain), pass=\(result.passAtN), " +
            "u=\(result.uniqueItems), js=\(result.jsonStrict)"
        )
    }

    private static func logAggregateResult(
        _ aggregate: AggregateResult,
        promptName: String,
        onProgress: @MainActor @escaping (String) -> Void
    ) {
        onProgress(
            "   📊 pass@N=\(String(format: "%.0f", aggregate.passAtNRate * 100))%, " +
            "jsonS=\(String(format: "%.0f", aggregate.jsonStrictRate * 100))%, " +
            "tpu=\(String(format: "%.2f", aggregate.meanTimePerUnique))s"
        )

        logToFile(
            "Prompt \(promptName) aggregate: pass@N=\(aggregate.passAtNRate), " +
            "jsonStrict=\(aggregate.jsonStrictRate)"
        )
    }

    private static func logTestCompletion(
        completedTests: Int,
        onProgress: @MainActor @escaping (String) -> Void
    ) {
        onProgress("\n🎉 Pilot complete! \(completedTests) runs")
        logToFile("🎉 Pilot test complete")
    }

    private static func saveAllResults(_ aggregateResults: [AggregateResult]) async {
        await saveFinalResults(aggregateResults, to: "tiercade_pilot_results.json")
        await saveStratifiedReport(aggregateResults, to: "tiercade_pilot_report.txt")
        await saveRecommendations(aggregateResults, to: "tiercade_pilot_recommendations.txt")
    }

    struct SingleRunParameters {
        let config: TestConfig
        let promptNumber: Int
        let promptName: String
        let promptText: String
        let runNumber: Int
        let query: String
        let targetCount: Int?
        let domain: String
        let decodingConfig: DecodingConfig
        let seed: UInt64
        let useGuidedSchema: Bool
    }

    private static func testSingleRun(_ params: SingleRunParameters) async -> SingleRunResult {
        let startTime = Date()

        let effectiveTarget = params.targetCount ?? 40
        let nBucket = params.config.nBucket(for: params.targetCount)
        let overgenFactor = params.config.overgenFactor(for: effectiveTarget)
        let maxTokens = params.config.dynamicMaxTokens(targetCount: effectiveTarget, overgenFactor: overgenFactor)

        logRunStart(params: params, effectiveTarget: effectiveTarget, maxTokens: maxTokens)

        do {
            let response = try await executeLanguageModelRequest(
                params: params,
                maxTokens: maxTokens
            )

            let duration = Date().timeIntervalSince(startTime)
            let analysis = analyzeResponse(response.content, targetCount: effectiveTarget)

            let surplusAtN = max(0, analysis.uniqueItems - effectiveTarget)
            let timePerUnique = analysis.uniqueItems > 0 ? duration / Double(analysis.uniqueItems) : duration

            logRunSuccess(
                analysis: analysis, surplusAtN: surplusAtN, timePerUnique: timePerUnique,
                duration: duration, finishReason: response.finishReason
            )

            return buildSuccessResult(context: SuccessResultContext(
                params: params,
                nBucket: nBucket,
                responseContent: response.content,
                analysis: analysis,
                surplusAtN: surplusAtN,
                finishReason: response.finishReason,
                wasTruncated: response.wasTruncated,
                maxTokens: maxTokens,
                duration: duration,
                timePerUnique: timePerUnique
            ))
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logToFile("❌ ERROR: \(error.localizedDescription)")

            return buildErrorResult(context: ErrorResultContext(
                params: params,
                nBucket: nBucket,
                effectiveTarget: effectiveTarget,
                maxTokens: maxTokens,
                duration: duration,
                error: error
            ))
        }
    }

    private static func logRunStart(params: SingleRunParameters, effectiveTarget: Int, maxTokens: Int) {
        logToFile(
            "🔵 RUN #\(params.runNumber): prompt=\(params.promptName), query='\(params.query)', N=\(effectiveTarget), " +
            "domain=\(params.domain), decoder=\(params.decodingConfig.name), seed=\(params.seed), " +
            "guided=\(params.useGuidedSchema), maxTok=\(maxTokens)"
        )
    }

    private struct LanguageModelResponse: Sendable {
        let content: String
        let finishReason: String?
        let wasTruncated: Bool
    }

    private struct SuccessResultContext: Sendable {
        let params: SingleRunParameters
        let nBucket: String
        let responseContent: String
        let analysis: ResponseAnalysis
        let surplusAtN: Int
        let finishReason: String?
        let wasTruncated: Bool
        let maxTokens: Int
        let duration: TimeInterval
        let timePerUnique: Double
    }

    private struct ErrorResultContext: Sendable {
        let params: SingleRunParameters
        let nBucket: String
        let effectiveTarget: Int
        let maxTokens: Int
        let duration: TimeInterval
        let error: Error
    }

    private struct TestExecutionContext: Sendable {
        let config: TestConfig
        let promptNumber: Int
        let promptName: String
        let promptText: String
        let totalRuns: Int
    }

    private static func executeLanguageModelRequest(
        params: SingleRunParameters,
        maxTokens: Int
    ) async throws -> LanguageModelResponse {
        let finalPrompt = params.promptText.replacingOccurrences(of: "{QUERY}", with: params.query)
        let instructions = Instructions(finalPrompt)
        let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
        let opts = params.decodingConfig.generationOptions(seed: params.seed, maxTokens: maxTokens)

        if params.useGuidedSchema {
            let stringList: StringList = try await withTimeout(seconds: 60) {
                try await session.respond(
                    to: Prompt(params.query),
                    generating: StringList.self,
                    includeSchemaInPrompt: true,
                    options: opts
                ).content
            }
            let jsonData = try JSONEncoder().encode(stringList)
            let content = String(data: jsonData, encoding: .utf8) ?? ""
            return LanguageModelResponse(content: content, finishReason: "guided-schema", wasTruncated: false)
        } else {
            let content = try await withTimeout(seconds: 60) {
                try await session.respond(to: Prompt(params.query), options: opts).content
            }
            let charLimit = maxTokens * 4
            if content.count >= charLimit {
                return LanguageModelResponse(content: content, finishReason: "likely-truncated", wasTruncated: true)
            } else {
                return LanguageModelResponse(content: content, finishReason: "stop", wasTruncated: false)
            }
        }
    }

    private static func logRunSuccess(
        analysis: ResponseAnalysis,
        surplusAtN: Int,
        timePerUnique: Double,
        duration: TimeInterval,
        finishReason: String?
    ) {
        logToFile(
            "✅ SUCCESS: unique=\(analysis.uniqueItems), pass@N=\(analysis.passAtN), " +
            "jsonStrict=\(analysis.wasJsonParsed), " +
            "dup=\(String(format: "%.1f", analysis.dupRate * 100))%, surplus=\(surplusAtN), " +
            "tpu=\(String(format: "%.3f", timePerUnique))s, " +
            "dur=\(String(format: "%.2f", duration))s, finish=\(finishReason ?? "unknown")"
        )
    }

    private static func buildSuccessResult(context: SuccessResultContext) -> SingleRunResult {
        SingleRunResult(
            promptNumber: context.params.promptNumber,
            promptName: context.params.promptName,
            runNumber: context.params.runNumber,
            seed: context.params.seed,
            query: context.params.query,
            targetCount: context.params.targetCount,
            domain: context.params.domain,
            nBucket: context.nBucket,
            decodingName: context.params.decodingConfig.name,
            guidedSchema: context.params.useGuidedSchema,
            response: context.responseContent,
            parsedItems: context.analysis.parsedItems,
            normalizedItems: context.analysis.normalizedItems,
            totalItems: context.analysis.totalItems,
            uniqueItems: context.analysis.uniqueItems,
            duplicateCount: context.analysis.duplicateCount,
            dupRate: context.analysis.dupRate,
            passAtN: context.analysis.passAtN,
            surplusAtN: context.surplusAtN,
            jsonStrict: context.analysis.wasJsonParsed,
            insufficient: context.analysis.insufficient,
            formatError: context.analysis.formatError,
            wasJsonParsed: context.analysis.wasJsonParsed,
            finishReason: context.finishReason,
            wasTruncated: context.wasTruncated,
            maxTokensUsed: context.maxTokens,
            duration: context.duration,
            timePerUnique: context.timePerUnique
        )
    }

    private static func buildErrorResult(context: ErrorResultContext) -> SingleRunResult {
        SingleRunResult(
            promptNumber: context.params.promptNumber,
            promptName: context.params.promptName,
            runNumber: context.params.runNumber,
            seed: context.params.seed,
            query: context.params.query,
            targetCount: context.params.targetCount,
            domain: context.params.domain,
            nBucket: context.nBucket,
            decodingName: context.params.decodingConfig.name,
            guidedSchema: context.params.useGuidedSchema,
            response: "ERROR: \(context.error.localizedDescription)",
            parsedItems: [],
            normalizedItems: [],
            totalItems: 0,
            uniqueItems: 0,
            duplicateCount: 0,
            dupRate: 1.0,
            passAtN: false,
            surplusAtN: -(context.effectiveTarget),
            jsonStrict: false,
            insufficient: true,
            formatError: true,
            wasJsonParsed: false,
            finishReason: "error",
            wasTruncated: false,
            maxTokensUsed: context.maxTokens,
            duration: context.duration,
            timePerUnique: 0.0
        )
    }

    private static func computeAggregate(
        config: TestConfig,
        promptNumber: Int,
        promptName: String,
        promptText: String,
        runs: [SingleRunResult]
    ) -> AggregateResult {
        let domain = runs.first?.domain ?? "unknown"
        let nBucket = runs.first?.nBucket ?? "unknown"

        let metrics = calculateAggregateMetrics(runs: runs)
        let (bestRun, worstRun) = findBestAndWorstRuns(runs: runs)

        return AggregateResult(
            promptNumber: promptNumber,
            promptName: promptName,
            promptText: promptText,
            totalRuns: runs.count,
            nBucket: nBucket,
            domain: domain,
            passAtNRate: metrics.passAtNRate,
            meanUniqueItems: metrics.meanUniqueItems,
            jsonStrictRate: metrics.jsonStrictRate,
            meanTimePerUnique: metrics.meanTimePerUnique,
            meanDupRate: metrics.meanDupRate,
            stdevDupRate: metrics.stdevDupRate,
            meanSurplusAtN: metrics.meanSurplusAtN,
            truncationRate: metrics.truncationRate,
            seedVariance: metrics.seedVariance,
            insufficientRate: metrics.insufficientRate,
            formatErrorRate: metrics.formatErrorRate,
            bestRun: bestRun,
            worstRun: worstRun,
            allRuns: runs
        )
    }

    private struct AggregateMetrics {
        let passAtNRate: Double
        let jsonStrictRate: Double
        let meanUniqueItems: Double
        let meanTimePerUnique: Double
        let meanDupRate: Double
        let stdevDupRate: Double
        let meanSurplusAtN: Double
        let truncationRate: Double
        let seedVariance: Double
        let insufficientRate: Double
        let formatErrorRate: Double
    }

    private static func calculateAggregateMetrics(runs: [SingleRunResult]) -> AggregateMetrics {
        let passAtNCount = runs.filter { $0.passAtN }.count
        let passAtNRate = Double(passAtNCount) / Double(runs.count)

        let jsonStrictCount = runs.filter { $0.jsonStrict }.count
        let jsonStrictRate = Double(jsonStrictCount) / Double(runs.count)

        let meanUniqueItems = runs.map { Double($0.uniqueItems) }.reduce(0, +) / Double(runs.count)
        let meanTimePerUnique = runs.map { $0.timePerUnique }.reduce(0, +) / Double(runs.count)

        let (meanDupRate, stdevDupRate) = calculateDupRateStats(runs: runs)
        let meanSurplusAtN = runs.map { Double($0.surplusAtN) }.reduce(0, +) / Double(runs.count)

        let truncationCount = runs.filter { $0.wasTruncated }.count
        let truncationRate = Double(truncationCount) / Double(runs.count)

        let seedVariance = calculateSeedVariance(runs: runs)

        let insufficientCount = runs.filter { $0.insufficient }.count
        let insufficientRate = Double(insufficientCount) / Double(runs.count)

        let formatErrorCount = runs.filter { $0.formatError }.count
        let formatErrorRate = Double(formatErrorCount) / Double(runs.count)

        return AggregateMetrics(
            passAtNRate: passAtNRate,
            jsonStrictRate: jsonStrictRate,
            meanUniqueItems: meanUniqueItems,
            meanTimePerUnique: meanTimePerUnique,
            meanDupRate: meanDupRate,
            stdevDupRate: stdevDupRate,
            meanSurplusAtN: meanSurplusAtN,
            truncationRate: truncationRate,
            seedVariance: seedVariance,
            insufficientRate: insufficientRate,
            formatErrorRate: formatErrorRate
        )
    }

    private static func calculateDupRateStats(runs: [SingleRunResult]) -> (mean: Double, stdev: Double) {
        let dupRates = runs.map { $0.dupRate }
        let meanDupRate = dupRates.reduce(0, +) / Double(runs.count)
        let variance = dupRates.map { pow($0 - meanDupRate, 2) }.reduce(0, +) / Double(runs.count)
        let stdevDupRate = sqrt(variance)
        return (meanDupRate, stdevDupRate)
    }

    private static func calculateSeedVariance(runs: [SingleRunResult]) -> Double {
        let uniqueByRun = runs.map { $0.uniqueItems }
        let meanUnique = uniqueByRun.reduce(0, +) / uniqueByRun.count
        let varianceSum = uniqueByRun.map { pow(Double($0 - meanUnique), 2) }.reduce(0, +)
        let seedVarianceVal = varianceSum / Double(uniqueByRun.count)
        return sqrt(seedVarianceVal)
    }

    private static func findBestAndWorstRuns(runs: [SingleRunResult])
        -> (best: SingleRunResult?, worst: SingleRunResult?)
    {
        let bestRun = runs.max { lhs, rhs in
            if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
            if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
            if lhs.formatError != rhs.formatError { return lhs.formatError }
            return lhs.dupRate > rhs.dupRate
        }
        let worstRun = runs.min { lhs, rhs in
            if lhs.passAtN != rhs.passAtN { return !lhs.passAtN }
            if lhs.uniqueItems != rhs.uniqueItems { return lhs.uniqueItems < rhs.uniqueItems }
            if lhs.formatError != rhs.formatError { return lhs.formatError }
            return lhs.dupRate > rhs.dupRate
        }
        return (bestRun, worstRun)
    }

    // MARK: - Analysis

    private struct ResponseAnalysis {
        let parsedItems: [String]
        let normalizedItems: [String]
        let totalItems: Int
        let uniqueItems: Int
        let duplicateCount: Int
        let dupRate: Double
        let passAtN: Bool
        let insufficient: Bool
        let formatError: Bool
        let wasJsonParsed: Bool
    }

    private static func analyzeResponse(_ text: String, targetCount: Int) -> ResponseAnalysis {
        let (items, wasJsonParsed) = parseResponseItems(text)
        let (normalizedList, duplicateCount) = deduplicateItems(items)

        let totalItems = items.count
        let uniqueItems = normalizedList.count
        let dupRate = totalItems > 0 ? Double(duplicateCount) / Double(totalItems) : 0.0
        let passAtN = uniqueItems >= targetCount
        let insufficient = uniqueItems < Int(Double(targetCount) * 0.8)
        let formatError = items.isEmpty && !text.isEmpty

        return ResponseAnalysis(
            parsedItems: items,
            normalizedItems: normalizedList,
            totalItems: totalItems,
            uniqueItems: uniqueItems,
            duplicateCount: duplicateCount,
            dupRate: dupRate,
            passAtN: passAtN,
            insufficient: insufficient,
            formatError: formatError,
            wasJsonParsed: wasJsonParsed
        )
    }

    private static func parseResponseItems(_ text: String) -> (items: [String], wasJsonParsed: Bool) {
        var items: [String] = []
        var wasJsonParsed = false

        if let jsonData = text.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            items = jsonArray
            wasJsonParsed = true
        } else if let jsonData = text.data(using: .utf8),
                  let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let itemsArray = jsonDict["items"] as? [String] {
            items = itemsArray
            wasJsonParsed = true
        } else {
            items = parseFallbackFormat(text)
        }

        return (items, wasJsonParsed)
    }

    private static func parseFallbackFormat(_ text: String) -> [String] {
        var items: [String] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: #"^\d+[\.):\s]+"#, options: .regularExpression) {
                let content = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    items.append(content)
                }
            }
        }

        if items.isEmpty {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed.count < 100 {
                    items.append(trimmed)
                }
            }
        }

        return items
    }

    private static func deduplicateItems(_ items: [String]) -> (normalizedList: [String], duplicateCount: Int) {
        var seenNormalized = Set<String>()
        var normalizedList: [String] = []
        var duplicateCount = 0

        for item in items {
            let normalized = normalizeForComparison(item)
            if !normalized.isEmpty {
                if seenNormalized.contains(normalized) {
                    duplicateCount += 1
                } else {
                    seenNormalized.insert(normalized)
                    normalizedList.append(normalized)
                }
            }
        }

        return (normalizedList, duplicateCount)
    }

    private static func normalizeForComparison(_ text: String) -> String {
        var normalized = text.lowercased()
        normalized = normalized.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let articles = ["the ", "a ", "an "]
        for article in articles where normalized.hasPrefix(article) {
            normalized = String(normalized.dropFirst(article.count))
        }

        normalized = normalized.replacingOccurrences(of: "™", with: "")
        normalized = normalized.replacingOccurrences(of: "®", with: "")
        normalized = normalized.replacingOccurrences(
            of: #"\s*[\(\[\{].*?[\)\]\}]"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: "&", with: "and")
        normalized = normalized.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        normalized = normalized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Logging

    private static func logToFile(_ message: String, filename: String = "tiercade_test_detailed.log") {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logURL = documentsURL.appendingPathComponent(filename)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }

        // Also print to console
        print(message)
    }

    private static func clearLogFile(filename: String = "tiercade_test_detailed.log") {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logURL = documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: logURL)
    }

    // MARK: - Save Results

    private static func saveFinalResults(_ results: [AggregateResult], to filename: String) async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent(filename)

        // Convert to JSON-serializable dict
        var jsonResults: [[String: Any]] = []
        for result in results {
            jsonResults.append([
                "promptName": result.promptName,
                "passAtNRate": result.passAtNRate,
                "jsonStrictRate": result.jsonStrictRate,
                "meanUniqueItems": result.meanUniqueItems,
                "meanTimePerUnique": result.meanTimePerUnique,
                "nBucket": result.nBucket,
                "domain": result.domain
            ])
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResults, options: .prettyPrinted) {
            try? jsonData.write(to: outputURL)
            logToFile("💾 Saved results: \(outputURL.path)")
        }
    }

    private static func saveStratifiedReport(_ results: [AggregateResult], to filename: String) async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent(filename)

        var report = """
        ================================================================================
        TIERCADE PILOT TEST - STRATIFIED REPORT
        ================================================================================
        Metric Priority: pass@N → jsonStrict% → timePerUnique → dupRate (diagnostic)
        ================================================================================

        """

        // By N-bucket
        let buckets = ["small", "medium", "large", "open"]
        for bucket in buckets {
            let bucketResults = results.filter { $0.nBucket == bucket }
            if bucketResults.isEmpty { continue }

            report += "\n### N-BUCKET: \(bucket.uppercased())\n"
            report += String(repeating: "─", count: 80) + "\n"

            let sorted = bucketResults.sorted { lhs, rhs in
                if abs(lhs.passAtNRate - rhs.passAtNRate) > 0.01 { return lhs.passAtNRate > rhs.passAtNRate }
                if abs(lhs.jsonStrictRate - rhs.jsonStrictRate) > 0.01 {
                    return lhs.jsonStrictRate > rhs.jsonStrictRate
                }
                return lhs.meanTimePerUnique < rhs.meanTimePerUnique
            }

            for result in sorted {
                report += String(
                    format: "%-20s | pass@N=%5.1f%% | jsonS=%5.1f%% | unique=%5.1f | tpu=%4.2fs | dup=%4.1f%%\n",
                    result.promptName,
                    result.passAtNRate * 100,
                    result.jsonStrictRate * 100,
                    result.meanUniqueItems,
                    result.meanTimePerUnique,
                    result.meanDupRate * 100
                )
            }
        }

        try? report.write(to: outputURL, atomically: true, encoding: .utf8)
        logToFile("📄 Saved stratified report: \(outputURL.path)")
    }

    private static func saveRecommendations(_ results: [AggregateResult], to filename: String) async {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent(filename)

        var rec = """
        ================================================================================
        PRODUCTION RECOMMENDATIONS
        ================================================================================

        """

        let sortedByPass = results.sorted { $0.passAtNRate > $1.passAtNRate }
        if let best = sortedByPass.first {
            rec += "DEFAULT PROMPT: \(best.promptName)\n"
            rec += "  pass@N: \(String(format: "%.1f", best.passAtNRate * 100))%\n"
            rec += "  jsonStrict: \(String(format: "%.1f", best.jsonStrictRate * 100))%\n\n"
        }

        let avgJsonStrict = results.map { $0.jsonStrictRate }.reduce(0, +) / Double(results.count)
        if avgJsonStrict < 0.90 {
            rec += "⚠️  FORCE GUIDED SCHEMA: Average jsonStrict is " +
                   "\(String(format: "%.1f", avgJsonStrict * 100))% (< 90%)\n\n"
        }

        try? rec.write(to: outputURL, atomically: true, encoding: .utf8)
        logToFile("📋 Saved recommendations: \(outputURL.path)")
    }

    // MARK: - Timeout

    struct TimeoutError: Error, Sendable {}

    nonisolated private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Prompts (Pilot: G0, G2, G3, G6)

    private static let enhancedPrompts: [(name: String, text: String)] = [
        ("G0-Minimal", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        If a count is given, produce about 1.4× that many candidates. If no count, return a reasonable set.
        No commentary. Do not sort.
        """),

        ("G1-BudgetCap", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Produce up to 200 candidates, not more. No commentary. Do not sort.
        """),

        ("G2-LightUnique", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Aim for distinct items. If unsure, vary categories or eras.
        No commentary. Do not sort.
        """),

        ("G3-Diversity", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Encourage variety across regions, time periods, and subtypes. \
        Avoid near-identical variants in the same franchise or model line.
        No commentary. Do not sort.
        """),

        ("G4-CommonNames", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Use common names, not synonyms or parenthetical descriptors.
        No commentary. Do not sort.
        """),

        ("G5-GuidedSchema", """
        You output JSON: {"items":[string,...]} and nothing else.
        Task: {QUERY}
        """),

        ("G6-CandidateOnly", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Generate candidates freely. Do not check for duplicates or normalize.
        No commentary.
        """),

        ("G7-ShortNames", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Use short common names. No qualifiers or parentheticals.
        No commentary. Do not sort.
        """),

        ("G8-CategorySpread", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Aim for coverage across different types or subcategories relevant to the topic.
        No commentary. Do not sort.
        """),

        ("G9-NoNearVariants", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Avoid near-variants of the same item (model year, size, flavor) when a single \
        representative is reasonable.
        No commentary. Do not sort.
        """),

        ("G10-CommonNamePref", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Prefer common names over scientific names or regional synonyms.
        No commentary. Do not sort.
        """),

        ("G11-ProperNounPref", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Prefer distinct proper nouns. Avoid generic descriptions.
        No commentary. Do not sort.
        """)
    ]
}
#endif
