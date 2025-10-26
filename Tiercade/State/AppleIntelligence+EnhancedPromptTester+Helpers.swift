import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Helper Functions

@available(iOS 26.0, macOS 26.0, *)
extension EnhancedPromptTester {
static func logTestHeader(
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

static func calculateTotalRuns(config: TestConfig) -> Int {
    4 * config.testQueries.count * config.decodingConfigs.count *
    config.seeds.count * config.guidedModes.count
}

static func selectPilotPrompts() -> [(Int, (name: String, text: String))] {
    [
        (0, enhancedPrompts[0]),
        (2, enhancedPrompts[2]),
        (3, enhancedPrompts[3]),
        (6, enhancedPrompts[6])
    ]
}

static func executePromptTestRuns(
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

static func logProgressUpdate(
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

static func logAggregateResult(
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

static func logTestCompletion(
    completedTests: Int,
    onProgress: @MainActor @escaping (String) -> Void
) {
    onProgress("\n🎉 Pilot complete! \(completedTests) runs")
    logToFile("🎉 Pilot test complete")
}

    static func saveAllResults(_ aggregateResults: [AggregateResult]) async {
        await saveFinalResults(aggregateResults, to: "tiercade_pilot_results.json")
        await saveStratifiedReport(aggregateResults, to: "tiercade_pilot_report.txt")
        await saveRecommendations(aggregateResults, to: "tiercade_pilot_recommendations.txt")
    }
}
#endif
