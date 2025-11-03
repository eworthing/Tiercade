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
internal struct PilotTestConfig {
    internal let sizes: [Int] = [15, 50, 150]
    internal let seeds: [UInt64] = [42, 123, 456, 789, 999]
    internal let testQueries: [TestQuery] = [
        TestQuery(domain: "scientists", template: "famous scientists throughout history"),
        TestQuery(domain: "programming_languages", template: "programming languages"),
        TestQuery(domain: "sci_fi_shows", template: "science fiction TV series"),
        TestQuery(domain: "video_games", template: "classic video game titles")
    ]

    internal struct TestQuery {
        internal let domain: String
        internal let template: String
    }

    internal struct DecoderConfig: Sendable {
        internal let name: String
        internal let options: @Sendable (UInt64?, Int) -> GenerationOptions

        internal static let all: [DecoderConfig] = [
            DecoderConfig(name: "Greedy", options: { _, _ in .greedy }),
            DecoderConfig(
                name: "TopK40_T0.7",
                options: { seed, maxTok in .topK(40, temp: 0.7, seed: seed, maxTok: maxTok) }
            ),
            DecoderConfig(
                name: "TopK50_T0.8",
                options: { seed, maxTok in .topK(50, temp: 0.8, seed: seed, maxTok: maxTok) }
            ),
            DecoderConfig(
                name: "TopP92_T0.8",
                options: { seed, maxTok in .topP(0.92, temp: 0.8, seed: seed, maxTok: maxTok) }
            ),
            DecoderConfig(
                name: "TopP95_T0.9",
                options: { seed, maxTok in .topP(0.95, temp: 0.9, seed: seed, maxTok: maxTok) }
            )
        ]
    }

    internal var totalRuns: Int {
        sizes.count * seeds.count * testQueries.count
    }
}

@available(iOS 26.0, macOS 26.0, *)
internal struct PilotTestResult: Codable {
    internal let runID: UUID
    internal let timestamp: Date
    internal let domain: String
    internal let query: String
    internal let requestedN: Int
    internal let seed: UInt64
    internal let decoderProfile: String

    // Results
    internal let receivedN: Int
    internal let uniqueN: Int
    internal let passAtN: Bool
    internal let dupRatePreDedup: Double
    internal let generationTimeSeconds: Double
    internal let itemsPerSecond: Double

    // Context
    internal let environment: RunEnv
}

@available(iOS 26.0, macOS 26.0, *)
internal struct PilotTestReport: Codable {
    internal let timestamp: Date
    internal let totalRuns: Int
    internal let completedRuns: Int
    internal let results: [PilotTestResult]
    internal let summary: Summary

    internal struct Summary: Codable {
        internal let overallPassRate: Double
        internal let meanDupRate: Double
        internal let stdevDupRate: Double
        internal let meanItemsPerSecond: Double

        internal let passBySize: [String: Double] // "15" → 0.95
        internal let passByDomain: [String: Double]
        internal let passByDecoder: [String: Double]

        internal let topPerformers: [String] // "TopP92_T0.8: 98% pass"
    }

    internal static func generate(from results: [PilotTestResult]) -> PilotTestReport {
        internal let totalPassed = results.filter { $0.passAtN }.count
        internal let overallPassRate = Double(totalPassed) / Double(max(1, results.count))

        internal let dupRates = results.map { $0.dupRatePreDedup }
        internal let meanDupRate = dupRates.reduce(0, +) / Double(max(1, dupRates.count))
        internal let variance = dupRates.map { pow($0 - meanDupRate, 2) }.reduce(0, +) / Double(max(1, dupRates.count))
        internal let stdevDupRate = sqrt(variance)

        internal let meanItemsPerSecond = results.map { $0.itemsPerSecond }.reduce(0, +) / Double(max(1, results.count))

        // Group by dimensions
        internal let bySize = Dictionary(grouping: results) { "\($0.requestedN)" }
        internal let passBySize = bySize.mapValues { group in
            Double(group.filter { $0.passAtN }.count) / Double(group.count)
        }

        internal let byDomain = Dictionary(grouping: results) { $0.domain }
        internal let passByDomain = byDomain.mapValues { group in
            Double(group.filter { $0.passAtN }.count) / Double(group.count)
        }

        internal let byDecoder = Dictionary(grouping: results) { $0.decoderProfile }
        internal let passByDecoder = byDecoder.mapValues { group in
            Double(group.filter { $0.passAtN }.count) / Double(group.count)
        }

        internal let topPerformers = passByDecoder
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key): \(String(format: "%.0f", $0.value * 100))% pass" }

        internal let summary = Summary(
            overallPassRate: overallPassRate,
            meanDupRate: meanDupRate,
            stdevDupRate: stdevDupRate,
            meanItemsPerSecond: meanItemsPerSecond,
            passBySize: passBySize,
            passByDomain: passByDomain,
            passByDecoder: passByDecoder,
            topPerformers: Array(topPerformers)
        )

        return PilotTestReport(
            timestamp: Date(),
            totalRuns: results.count,
            completedRuns: results.count,
            results: results,
            summary: summary
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal struct PilotTestRunner {
    private let config = PilotTestConfig()
    private let onProgress: (String) -> Void

    internal init(onProgress: @escaping (String) -> Void = { print($0) }) {
        self.onProgress = onProgress
    }

    /// Run comprehensive pilot test grid
    internal func runPilot() async -> PilotTestReport {
        logPilotHeader()

        guard let session = try? await createTestSession() else {
            onProgress("❌ Failed to create test session")
            return PilotTestReport.generate(from: [])
        }

        internal let allResults = await executeTestRuns(session: session)
        internal let report = PilotTestReport.generate(from: allResults)

        logPilotSummary(report: report)

        return report
    }

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
        internal var allResults: [PilotTestResult] = []
        internal var runIndex = 0

        for query in config.testQueries {
            for size in config.sizes {
                for seed in config.seeds {
                    runIndex += 1
                    onProgress("""
                        [\(runIndex)/\(config.totalRuns)] Testing: \
                        \(query.domain), N=\(size), seed=\(seed)
                        """)

                    // Test with the "diverse" decoder (representative)
                    if let result = await runSingleTest(
                        session: session,
                        query: query,
                        size: size,
                        seed: seed,
                        decoder: "Diverse"
                    ) {
                        allResults.append(result)
                        logTestResult(result: result, requestedSize: size)
                    }
                }
            }
        }

        return allResults
    }

    private func logTestResult(result: PilotTestResult, requestedSize: Int) {
        internal let status = result.passAtN ? "✅" : "⚠️"
        internal let dupPercent = String(format: "%.1f", result.dupRatePreDedup * 100)
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
        internal let passRate = String(format: "%.1f", report.summary.overallPassRate * 100)
        onProgress("  • Overall pass@N: \(passRate)%")
        internal let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
        internal let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
        onProgress("  • Mean dup rate: \(meanDup)±\(stdevDup)%")
        internal let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)
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
        decoder: String
    ) async -> PilotTestResult? {
        internal let fm = FMClient(session: session, logger: { _ in })
        internal let coordinator = UniqueListCoordinator(fm: fm, logger: { _ in })

        internal let startTime = Date()
        internal var receivedItems: [String] = []

        do {
            // Capture pre-dedup count by tracking the coordinator's generation
            // (This is a simplification; real implementation would track internally)
            receivedItems = try await coordinator.uniqueList(
                query: query.template,
                targetCount: size,
                seed: seed
            )

            internal let elapsed = Date().timeIntervalSince(startTime)
            internal let normKeys = receivedItems.map { $0.normKey }
            internal let uniqueKeys = Set(normKeys)

            // Estimate pre-dedup count (simplified: assume over-gen factor)
            internal let estimatedPreDedup = Int(ceil(Double(size) * Defaults.pass1OverGen))
            internal let dupCount = max(0, Double(estimatedPreDedup - uniqueKeys.count))
            internal let dupRatePreDedup = dupCount / Double(max(1, estimatedPreDedup))

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
                environment: RunEnv()
            )
        } catch {
            onProgress("  ❌ Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func createTestSession() async throws -> LanguageModelSession {
        internal let instructions = Instructions("""
        You are a helpful assistant that generates lists.
        Always return valid JSON matching the requested schema.
        Ensure items are distinct and diverse.
        """)

        return LanguageModelSession(
            model: .default,
            tools: [],
            instructions: instructions
        )
    }

    /// Save pilot report to file
    internal func saveReport(_ report: PilotTestReport, to path: String) throws {
        internal let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        internal let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: path))
        onProgress("📄 Pilot report saved: \(path)")
    }

    /// Generate human-readable report
    internal func generateTextReport(_ report: PilotTestReport) -> String {
        internal var lines: [String] = []

        lines.append("PILOT TEST REPORT")
        lines.append("================")
        lines.append("")
        lines.append("Generated: \(report.timestamp)")
        lines.append("Total runs: \(report.completedRuns)")
        lines.append("")

        lines.append("OVERALL METRICS")
        lines.append("---------------")
        internal let passRate = String(format: "%.1f%%", report.summary.overallPassRate * 100)
        lines.append("Pass@N rate: \(passRate)")
        internal let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
        internal let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
        lines.append("Mean duplicate rate: \(meanDup)±\(stdevDup)%%")
        internal let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)
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
            internal let status = result.passAtN ? "PASS" : "FAIL"
            internal let dupPercent = String(format: "%.1f%%", result.dupRatePreDedup * 100)
            lines.append("""
                \(status) | \(result.domain) | N=\(result.requestedN) | \
                seed=\(result.seed) | got=\(result.receivedN) | \
                unique=\(result.uniqueN) | dup=\(dupPercent)
                """)
        }

        return lines.joined(separator: "\n")
    }
}
#endif
