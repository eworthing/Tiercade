// ============================================================================
// COMPREHENSIVE PROMPT TESTING FRAMEWORK - FINAL VERSION
// ============================================================================
//
// ⚠️ DEPRECATED: This testing infrastructure has been replaced by UnifiedPromptTester.
//
// Migration path:
// 1. Replace EnhancedPromptTester.testPrompts() with UnifiedPromptTester.runSuite(suiteId: "diversity-comparison")
// 2. All 12 enhanced prompts (G0-G11, F2-F3) are now in TestConfigs/SystemPrompts.json
// 3. Customize test configuration via TestConfigs/TestSuites.json
// 4. See TestConfigs/TESTING_FRAMEWORK.md for full configuration documentation
//
// Why replaced:
// - Prompts hardcoded in Swift (G0-G11, F2-F3 defined in code)
// - Configuration scattered across multiple methods
// - Redundant with AcceptanceTestSuite and PilotTestRunner
// - UnifiedPromptTester provides config-driven, multi-dimensional testing
//
// Original features (all preserved in UnifiedPromptTester):
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
internal class EnhancedPromptTester {
    // MARK: - Testing

    internal static func testPrompts(
        config: TestConfig = TestConfig(),
        onProgress: @MainActor @escaping (String) -> Void
    ) async -> [AggregateResult] {
        internal var aggregateResults: [AggregateResult] = []

        logTestHeader(config: config, onProgress: onProgress)

        internal let totalRuns = calculateTotalRuns(config: config)
        internal var completedTests = 0

        internal let pilotPrompts = selectPilotPrompts()

        for (promptIndex, (promptName, promptText)) in pilotPrompts {
            internal let promptNumber = promptIndex + 1
            onProgress("\n📝 Testing Prompt: \(promptName)")

            internal let runResults = await executePromptTestRuns(
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

            internal let aggregate = computeAggregate(
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

    internal struct SingleRunParameters {
        internal let config: TestConfig
        internal let promptNumber: Int
        internal let promptName: String
        internal let promptText: String
        internal let runNumber: Int
        internal let query: String
        internal let targetCount: Int?
        internal let domain: String
        internal let decodingConfig: DecodingConfig
        internal let seed: UInt64
        internal let useGuidedSchema: Bool
    }

    internal static func testSingleRun(_ params: SingleRunParameters) async -> SingleRunResult {
        internal let startTime = Date()

        internal let effectiveTarget = params.targetCount ?? 40
        internal let nBucket = params.config.nBucket(for: params.targetCount)
        internal let overgenFactor = params.config.overgenFactor(for: effectiveTarget)
        internal let maxTokens = params.config.dynamicMaxTokens(targetCount: effectiveTarget, overgenFactor: overgenFactor)

        logRunStart(params: params, effectiveTarget: effectiveTarget, maxTokens: maxTokens)

        do {
            internal let response = try await executeLanguageModelRequest(
                params: params,
                maxTokens: maxTokens
            )

            internal let duration = Date().timeIntervalSince(startTime)
            internal let analysis = analyzeResponse(response.content, targetCount: effectiveTarget)

            internal let surplusAtN = max(0, analysis.uniqueItems - effectiveTarget)
            internal let timePerUnique = analysis.uniqueItems > 0 ? duration / Double(analysis.uniqueItems) : duration

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
            internal let duration = Date().timeIntervalSince(startTime)
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

    internal static func logRunStart(params: SingleRunParameters, effectiveTarget: Int, maxTokens: Int) {
        logToFile(
            "🔵 RUN #\(params.runNumber): prompt=\(params.promptName), query='\(params.query)', N=\(effectiveTarget), " +
            "domain=\(params.domain), decoder=\(params.decodingConfig.name), seed=\(params.seed), " +
            "guided=\(params.useGuidedSchema), maxTok=\(maxTokens)"
        )
    }

    internal struct LanguageModelResponse: Sendable {
        internal let content: String
        internal let finishReason: String?
        internal let wasTruncated: Bool
    }

    internal struct SuccessResultContext: Sendable {
        internal let params: SingleRunParameters
        internal let nBucket: String
        internal let responseContent: String
        internal let analysis: ResponseAnalysis
        internal let surplusAtN: Int
        internal let finishReason: String?
        internal let wasTruncated: Bool
        internal let maxTokens: Int
        internal let duration: TimeInterval
        internal let timePerUnique: Double
    }

    internal struct ErrorResultContext: Sendable {
        internal let params: SingleRunParameters
        internal let nBucket: String
        internal let effectiveTarget: Int
        internal let maxTokens: Int
        internal let duration: TimeInterval
        internal let error: Error
    }

    internal struct TestExecutionContext: Sendable {
        internal let config: TestConfig
        internal let promptNumber: Int
        internal let promptName: String
        internal let promptText: String
        internal let totalRuns: Int
    }

    internal static func executeLanguageModelRequest(
        params: SingleRunParameters,
        maxTokens: Int
    ) async throws -> LanguageModelResponse {
        internal let finalPrompt = params.promptText.replacingOccurrences(of: "{QUERY}", with: params.query)
        internal let instructions = Instructions(finalPrompt)
        internal let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
        internal let opts = params.decodingConfig.generationOptions(seed: params.seed, maxTokens: maxTokens)

        if params.useGuidedSchema {
            internal let stringList: StringList = try await withTimeout(seconds: 60) {
                try await session.respond(
                    to: Prompt(params.query),
                    generating: StringList.self,
                    includeSchemaInPrompt: true,
                    options: opts
                ).content
            }
            internal let jsonData = try JSONEncoder().encode(stringList)
            internal let content = String(data: jsonData, encoding: .utf8) ?? ""
            return LanguageModelResponse(content: content, finishReason: "guided-schema", wasTruncated: false)
        } else {
            internal let content = try await withTimeout(seconds: 60) {
                try await session.respond(to: Prompt(params.query), options: opts).content
            }
            internal let charLimit = maxTokens * 4
            if content.count >= charLimit {
                return LanguageModelResponse(content: content, finishReason: "likely-truncated", wasTruncated: true)
            } else {
                return LanguageModelResponse(content: content, finishReason: "stop", wasTruncated: false)
            }
        }
    }

    internal static func logRunSuccess(
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

    internal static func buildSuccessResult(context: SuccessResultContext) -> SingleRunResult {
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

    internal static func buildErrorResult(context: ErrorResultContext) -> SingleRunResult {
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
}
#endif
