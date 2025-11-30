import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

@MainActor
class EnhancedPromptTester {
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

    struct LanguageModelResponse: Sendable {
        let content: String
        let finishReason: String?
        let wasTruncated: Bool
    }

    struct SuccessResultContext: Sendable {
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

    struct ErrorResultContext: Sendable {
        let params: SingleRunParameters
        let nBucket: String
        let effectiveTarget: Int
        let maxTokens: Int
        let duration: TimeInterval
        let error: Error
    }

    struct TestExecutionContext: Sendable {
        let config: TestConfig
        let promptNumber: Int
        let promptName: String
        let promptText: String
        let totalRuns: Int
    }

    // MARK: - Testing

    static func testPrompts(
        config: TestConfig = TestConfig(),
        onProgress: @MainActor @escaping (String) -> Void,
    ) async
    -> [AggregateResult] {
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
                    totalRuns: totalRuns,
                ),
                completedTests: &completedTests,
                onProgress: onProgress,
            )

            let aggregate = computeAggregate(
                config: config,
                promptNumber: promptNumber,
                promptName: promptName,
                promptText: promptText,
                runs: runResults,
            )

            aggregateResults.append(aggregate)
            logAggregateResult(aggregate, promptName: promptName, onProgress: onProgress)
        }

        logTestCompletion(completedTests: completedTests, onProgress: onProgress)
        await saveAllResults(aggregateResults)

        return aggregateResults
    }

    static func testSingleRun(_ params: SingleRunParameters) async -> SingleRunResult {
        let startTime = Date()

        let effectiveTarget = params.targetCount ?? 40
        let nBucket = params.config.nBucket(for: params.targetCount)
        let overgenFactor = params.config.overgenFactor(for: effectiveTarget)
        let maxTokens = params.config.dynamicMaxTokens(targetCount: effectiveTarget, overgenFactor: overgenFactor)

        logRunStart(params: params, effectiveTarget: effectiveTarget, maxTokens: maxTokens)

        do {
            let response = try await executeLanguageModelRequest(
                params: params,
                maxTokens: maxTokens,
            )

            let duration = Date().timeIntervalSince(startTime)
            let analysis = analyzeResponse(response.content, targetCount: effectiveTarget)

            let surplusAtN = max(0, analysis.uniqueItems - effectiveTarget)
            let timePerUnique = analysis.uniqueItems > 0 ? duration / Double(analysis.uniqueItems) : duration

            logRunSuccess(
                analysis: analysis, surplusAtN: surplusAtN, timePerUnique: timePerUnique,
                duration: duration, finishReason: response.finishReason,
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
                timePerUnique: timePerUnique,
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
                error: error,
            ))
        }
    }

    static func logRunStart(params: SingleRunParameters, effectiveTarget: Int, maxTokens: Int) {
        logToFile(
            "🔵 RUN #\(params.runNumber): prompt=\(params.promptName), query='\(params.query)', N=\(effectiveTarget), " +
                "domain=\(params.domain), decoder=\(params.decodingConfig.name), seed=\(params.seed), " +
                "guided=\(params.useGuidedSchema), maxTok=\(maxTokens)",
        )
    }

    static func executeLanguageModelRequest(
        params: SingleRunParameters,
        maxTokens: Int,
    ) async throws
    -> LanguageModelResponse {
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
                    options: opts,
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

    static func logRunSuccess(
        analysis: ResponseAnalysis,
        surplusAtN: Int,
        timePerUnique: Double,
        duration: TimeInterval,
        finishReason: String?,
    ) {
        logToFile(
            "✅ SUCCESS: unique=\(analysis.uniqueItems), pass@N=\(analysis.passAtN), " +
                "jsonStrict=\(analysis.wasJsonParsed), " +
                "dup=\(String(format: "%.1f", analysis.dupRate * 100))%, surplus=\(surplusAtN), " +
                "tpu=\(String(format: "%.3f", timePerUnique))s, " +
                "dur=\(String(format: "%.2f", duration))s, finish=\(finishReason ?? "unknown")",
        )
    }

    static func buildSuccessResult(context: SuccessResultContext) -> SingleRunResult {
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
            timePerUnique: context.timePerUnique,
        )
    }

    static func buildErrorResult(context: ErrorResultContext) -> SingleRunResult {
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
            timePerUnique: 0.0,
        )
    }
}
#endif
