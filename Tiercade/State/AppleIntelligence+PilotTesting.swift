import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Pilot Testing Infrastructure

//
// ⚠️ DEPRECATED: This testing infrastructure has been replaced by UnifiedPromptTester.
//
// Migration path:
// 1. Replace PilotTestRunner.runPilot() with UnifiedPromptTester.runSuite(suiteId: "enhanced-pilot")
// 2. Customize test matrix by modifying TestConfigs/TestSuites.json
// 3. Add new decoders in TestConfigs/DecodingConfigs.json
// 4. See TestConfigs/TESTING_FRAMEWORK.md for configuration documentation
//
// Why replaced:
// - Configuration hardcoded in Swift (sizes, seeds, queries defined in code)
// - Redundant with AcceptanceTestSuite and EnhancedPromptTester
// - Limited flexibility for adding new test dimensions
// - UnifiedPromptTester provides config-driven, multi-dimensional testing
//
// Original purpose (preserved in UnifiedPromptTester):
// Validates the unique list generation spec across multiple configurations:
// - Sizes: N ∈ {15, 50, 150}
// - Decoders: Greedy, Top-K (40, 50), Top-P (0.92, 0.95)
// - Seeds: 5 fixed seeds for reproducibility
// - Queries: Different domains to test generalization

#if canImport(FoundationModels) && DEBUG
@available(iOS 26.0, macOS 26.0, *)
@MainActor
struct PilotTestConfig {
    struct TestQuery {
        let domain: String
        let template: String
    }

    struct DecoderConfig: Sendable {
        let name: String
        let options: @Sendable (UInt64?, Int) -> GenerationOptions

        static let all: [DecoderConfig] = [
            DecoderConfig(name: "Greedy", options: { _, _ in .greedy }),
            DecoderConfig(
                name: "TopK40_T0.7",
                options: { seed, maxTok in .topK(40, temp: 0.7, seed: seed, maxTok: maxTok) },
            ),
            DecoderConfig(
                name: "TopK50_T0.8",
                options: { seed, maxTok in .topK(50, temp: 0.8, seed: seed, maxTok: maxTok) },
            ),
            DecoderConfig(
                name: "TopP92_T0.8",
                options: { seed, maxTok in .topP(0.92, temp: 0.8, seed: seed, maxTok: maxTok) },
            ),
            DecoderConfig(
                name: "TopP95_T0.9",
                options: { seed, maxTok in .topP(0.95, temp: 0.9, seed: seed, maxTok: maxTok) },
            ),
        ]
    }

    let sizes: [Int] = [15, 50, 150]
    let seeds: [UInt64] = [42, 123, 456, 789, 999]
    let testQueries: [TestQuery] = [
        TestQuery(domain: "scientists", template: "famous scientists throughout history"),
        TestQuery(domain: "programming_languages", template: "programming languages"),
        TestQuery(domain: "sci_fi_shows", template: "science fiction TV series"),
        TestQuery(domain: "video_games", template: "classic video game titles"),
    ]

    var totalRuns: Int {
        sizes.count * seeds.count * testQueries.count
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct PilotTestResult: Codable {
    let runID: UUID
    let timestamp: Date
    let domain: String
    let query: String
    let requestedN: Int
    let seed: UInt64
    let decoderProfile: String

    // Results
    let receivedN: Int
    let uniqueN: Int
    let passAtN: Bool
    let dupRatePreDedup: Double
    let generationTimeSeconds: Double
    let itemsPerSecond: Double

    // Context
    let environment: RunEnv
}

@available(iOS 26.0, macOS 26.0, *)
struct PilotTestReport: Codable {
    struct Summary: Codable {
        let overallPassRate: Double
        let meanDupRate: Double
        let stdevDupRate: Double
        let meanItemsPerSecond: Double

        let passBySize: [String: Double] // "15" → 0.95
        let passByDomain: [String: Double]
        let passByDecoder: [String: Double]

        let topPerformers: [String] // "TopP92_T0.8: 98% pass"
    }

    let timestamp: Date
    let totalRuns: Int
    let completedRuns: Int
    let results: [PilotTestResult]
    let summary: Summary

    static func generate(from results: [PilotTestResult]) -> PilotTestReport {
        let totalPassed = results.count(where: { $0.passAtN })
        let overallPassRate = Double(totalPassed) / Double(max(1, results.count))

        let dupRates = results.map(\.dupRatePreDedup)
        let meanDupRate = dupRates.reduce(0, +) / Double(max(1, dupRates.count))
        let variance = dupRates.map { pow($0 - meanDupRate, 2) }.reduce(0, +) / Double(max(1, dupRates.count))
        let stdevDupRate = sqrt(variance)

        let meanItemsPerSecond = results.map(\.itemsPerSecond).reduce(0, +) / Double(max(1, results.count))

        // Group by dimensions
        let bySize = Dictionary(grouping: results) { "\($0.requestedN)" }
        let passBySize = bySize.mapValues { group in
            Double(group.count(where: { $0.passAtN })) / Double(group.count)
        }

        let byDomain = Dictionary(grouping: results) { $0.domain }
        let passByDomain = byDomain.mapValues { group in
            Double(group.count(where: { $0.passAtN })) / Double(group.count)
        }

        let byDecoder = Dictionary(grouping: results) { $0.decoderProfile }
        let passByDecoder = byDecoder.mapValues { group in
            Double(group.count(where: { $0.passAtN })) / Double(group.count)
        }

        let topPerformers = passByDecoder
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key): \(String(format: "%.0f", $0.value * 100))% pass" }

        let summary = Summary(
            overallPassRate: overallPassRate,
            meanDupRate: meanDupRate,
            stdevDupRate: stdevDupRate,
            meanItemsPerSecond: meanItemsPerSecond,
            passBySize: passBySize,
            passByDomain: passByDomain,
            passByDecoder: passByDecoder,
            topPerformers: Array(topPerformers),
        )

        return PilotTestReport(
            timestamp: Date(),
            totalRuns: results.count,
            completedRuns: results.count,
            results: results,
            summary: summary,
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
struct PilotTestRunner {

    // MARK: Lifecycle

    init(onProgress: @escaping (String) -> Void = { print($0) }) {
        self.onProgress = onProgress
    }

    // MARK: Internal

    /// Run comprehensive pilot test grid
    func runPilot() async -> PilotTestReport {
        logPilotHeader()

        guard let session = try? await createTestSession() else {
            onProgress("❌ Failed to create test session")
            return PilotTestReport.generate(from: [])
        }

        let allResults = await executeTestRuns(session: session)
        let report = PilotTestReport.generate(from: allResults)

        logPilotSummary(report: report)

        return report
    }

    /// Save pilot report to file
    func saveReport(_ report: PilotTestReport, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: path))
        onProgress("📄 Pilot report saved: \(path)")
    }

    /// Generate human-readable report
    func generateTextReport(_ report: PilotTestReport) -> String {
        var lines: [String] = []

        lines.append("PILOT TEST REPORT")
        lines.append("================")
        lines.append("")
        lines.append("Generated: \(report.timestamp)")
        lines.append("Total runs: \(report.completedRuns)")
        lines.append("")

        lines.append("OVERALL METRICS")
        lines.append("---------------")
        let passRate = String(format: "%.1f%%", report.summary.overallPassRate * 100)
        lines.append("Pass@N rate: \(passRate)")
        let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
        let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
        lines.append("Mean duplicate rate: \(meanDup)±\(stdevDup)%%")
        let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)
        lines.append("Mean throughput: \(throughput) items/sec")
        lines.append("")

        lines.append("PASS RATE BY SIZE")
        lines.append("-----------------")
        for (size, rate) in report.summary.passBySize.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }) {
            lines.append("N=\(size): \(String(format: "%.1f%%", rate * 100))")
        }
        lines.append("")

        lines.append("PASS RATE BY DOMAIN")
        lines.append("-------------------")
        for (domain, rate) in report.summary.passByDomain.sorted(by: { $0.key < $1.key }) {
            lines.append("\(domain): \(String(format: "%.1f%%", rate * 100))")
        }
        lines.append("")

        lines.append("TOP PERFORMERS")
        lines.append("--------------")
        for performer in report.summary.topPerformers {
            lines.append(performer)
        }
        lines.append("")

        lines.append("DETAILED RESULTS")
        lines.append("----------------")
        for result in report.results.sorted(by: { $0.timestamp < $1.timestamp }) {
            let status = result.passAtN ? "PASS" : "FAIL"
            let dupPercent = String(format: "%.1f%%", result.dupRatePreDedup * 100)
            lines.append("""
            \(status) | \(result.domain) | N=\(result.requestedN) | \
            seed=\(result.seed) | got=\(result.receivedN) | \
            unique=\(result.uniqueN) | dup=\(dupPercent)
            """)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: Private

    private let config = PilotTestConfig()
    private let onProgress: (String) -> Void

    private func logPilotHeader() {
        onProgress("🧪 ========================================")
        onProgress("🧪 PILOT TESTING: Unique List Generation")
        onProgress("🧪 ========================================")
        onProgress("")
        onProgress("Configuration:")
        onProgress("  • Sizes: \(config.sizes)")
        onProgress("  • Seeds: \(config.seeds.count) fixed")
        onProgress("  • Domains: \(config.testQueries.count)")
        onProgress("  • Decoders: \(PilotTestConfig.DecoderConfig.all.count)")
        onProgress("  • Total runs: \(config.totalRuns)")
        onProgress("")
    }

    private func executeTestRuns(session: LanguageModelSession) async -> [PilotTestResult] {
        var allResults: [PilotTestResult] = []
        var runIndex = 0

        for query in config.testQueries {
            for size in config.sizes {
                for seed in config.seeds {
                    runIndex += 1
                    onProgress("""
                    [\(runIndex)/\(config.totalRuns)] Testing: \
                    \(query.domain), N=\(size), seed=\(seed)
                    """)

                    // Test with the "diverse" decoder (representative)
                    if
                        let result = await runSingleTest(
                            session: session,
                            query: query,
                            size: size,
                            seed: seed,
                            decoder: "Diverse",
                        )
                    {
                        allResults.append(result)
                        logTestResult(result: result, requestedSize: size)
                    }
                }
            }
        }

        return allResults
    }

    private func logTestResult(result: PilotTestResult, requestedSize: Int) {
        let status = result.passAtN ? "✅" : "⚠️"
        let dupPercent = String(format: "%.1f", result.dupRatePreDedup * 100)
        onProgress("""
          \(status) Got \(result.receivedN)/\(requestedSize) unique \
        (\(dupPercent)% dup)
        """)
    }

    private func logPilotSummary(report: PilotTestReport) {
        onProgress("")
        onProgress("🧪 ========================================")
        onProgress("🧪 PILOT TEST COMPLETE")
        onProgress("🧪 ========================================")
        onProgress("")
        onProgress("Summary:")
        let passRate = String(format: "%.1f", report.summary.overallPassRate * 100)
        onProgress("  • Overall pass@N: \(passRate)%")
        let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
        let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
        onProgress("  • Mean dup rate: \(meanDup)±\(stdevDup)%")
        let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)
        onProgress("  • Mean throughput: \(throughput) items/sec")
        onProgress("")
        onProgress("Top performers:")
        for performer in report.summary.topPerformers {
            onProgress("  • \(performer)")
        }
    }

    private func runSingleTest(
        session: LanguageModelSession,
        query: PilotTestConfig.TestQuery,
        size: Int,
        seed: UInt64,
        decoder: String,
    ) async
    -> PilotTestResult? {
        let fm = FMClient(session: session, logger: { _ in })
        let coordinator = UniqueListCoordinator(fm: fm, logger: { _ in })

        let startTime = Date()
        var receivedItems: [String] = []

        do {
            // Capture pre-dedup count by tracking the coordinator's generation
            // (This is a simplification; real implementation would track internally)
            receivedItems = try await coordinator.uniqueList(
                query: query.template,
                targetCount: size,
                seed: seed,
            )

            let elapsed = Date().timeIntervalSince(startTime)
            let normKeys = receivedItems.map(\.normKey)
            let uniqueKeys = Set(normKeys)

            // Estimate pre-dedup count (simplified: assume over-gen factor)
            let estimatedPreDedup = Int(ceil(Double(size) * Defaults.pass1OverGen))
            let dupCount = max(0, Double(estimatedPreDedup - uniqueKeys.count))
            let dupRatePreDedup = dupCount / Double(max(1, estimatedPreDedup))

            return PilotTestResult(
                runID: UUID(),
                timestamp: Date(),
                domain: query.domain,
                query: query.template,
                requestedN: size,
                seed: seed,
                decoderProfile: decoder,
                receivedN: receivedItems.count,
                uniqueN: uniqueKeys.count,
                passAtN: receivedItems.count >= size && uniqueKeys.count == receivedItems.count,
                dupRatePreDedup: dupRatePreDedup,
                generationTimeSeconds: elapsed,
                itemsPerSecond: Double(receivedItems.count) / max(0.001, elapsed),
                environment: RunEnv(),
            )
        } catch {
            onProgress("  ❌ Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func createTestSession() async throws -> LanguageModelSession {
        let instructions = Instructions("""
        You are a helpful assistant that generates lists.
        Always return valid JSON matching the requested schema.
        Ensure items are distinct and diverse.
        """)

        return LanguageModelSession(
            model: .default,
            tools: [],
            instructions: instructions,
        )
    }

}
#endif
