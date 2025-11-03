import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Acceptance Test Suite
//
// ⚠️ DEPRECATED: This testing infrastructure has been replaced by UnifiedPromptTester.
//
// Migration path:
// 1. Replace AcceptanceTestSuite.runAll() with UnifiedPromptTester.runSuite(suiteId: "standard-prompt-test")
// 2. Use JSON configuration files in TestConfigs/ to define test queries and prompts
// 3. See AIChatOverlay+Tests.swift for updated integration patterns
// 4. Refer to TestConfigs/TESTING_FRAMEWORK.md for configuration documentation
//
// Why replaced:
// - Configuration hardcoded in Swift (difficult to modify without recompiling)
// - Limited test matrix flexibility
// - Redundant with EnhancedPromptTester and PilotTestRunner
// - UnifiedPromptTester provides config-driven, multi-dimensional testing
//
// Original purpose (preserved in UnifiedPromptTester):
// Validates the unique list generation spec implementation:
// 1. Structure: JSON decodes on all runs, no extra prose
// 2. Uniqueness: Set(map(normKey)).count == N
// 3. Backfill: For injected duplicates in pass 1, final output still meets N via fill
// 4. Overflow: Artificially large avoid-list triggers chunking path and succeeds
// 5. Reproducibility: With fixed seed and same OS, outputs stable modulo known variability

#if canImport(FoundationModels) && DEBUG
@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal enum AcceptanceTestSuite {

    // Seed ring for reproducible retries across tests
    internal static let seedRing: [UInt64] = [42, 1337, 9999, 123456, 987654]

    internal struct SeedRun {
        internal let seed: UInt64
        internal let ok: Bool
        internal let ips: Double
    }

    internal struct TestResult: Codable {
        internal let testName: String
        internal let passed: Bool
        internal let message: String
        internal let timestamp: Date
        internal let details: [String: String]

        init(testName: String, passed: Bool, message: String, details: [String: String] = [:]) {
            self.testName = testName
            self.passed = passed
            self.message = message
            self.timestamp = Date()
            self.details = details
        }
    }

    internal struct TestReport: Codable {
        internal let totalTests: Int
        internal let passed: Int
        internal let failed: Int
        internal let results: [TestResult]
        internal let environment: RunEnv
        internal let timestamp: Date

        internal var passRate: Double {
            guard totalTests > 0 else { return 0 }
            return Double(passed) / Double(totalTests)
        }
    }

    /// Compute median of array
    /// Run all acceptance tests
    internal static func runAll(logger: @escaping (String) -> Void = { print($0) }) async throws -> TestReport {
        logger("🧪 Starting Acceptance Test Suite")
        logger("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        internal var results: [TestResult] = []

        // Test 1: Structure (JSON decoding)
        results.append(await testStructure(logger: logger))

        // Test 2: Uniqueness
        results.append(await testUniqueness(logger: logger))

        // Test 3: Backfill with duplicates (unguided)
        results.append(await testBackfill(logger: logger))

        // Test 4: Guided backfill comparison
        results.append(await testGuidedBackfill(logger: logger))

        // Test 5: Context overflow handling
        results.append(await testOverflowHandling(logger: logger))

        // Test 6: Reproducibility
        results.append(await testReproducibility(logger: logger))

        // Test 7: Normalization edge cases
        results.append(testNormalization(logger: logger))

        // Test 8: Token budgeting
        results.append(testTokenBudgeting(logger: logger))

        internal let passed = results.filter { $0.passed }.count
        internal let failed = results.count - passed

        internal let report = TestReport(
            totalTests: results.count,
            passed: passed,
            failed: failed,
            results: results,
            environment: RunEnv(),
            timestamp: Date()
        )

        logger("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        logger("📊 Test Results: \(passed)/\(results.count) passed (\(String(format: "%.1f", report.passRate * 100))%)")

        if failed > 0 {
            logger("❌ Failed tests:")
            for result in results where !result.passed {
                logger("  • \(result.testName): \(result.message)")
            }
        }

        internal let telemetryPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("unique_list_runs.jsonl").path
        logger("📄 Telemetry: \(telemetryPath)")

        return report
    }

    // MARK: - Test 1: Structure (JSON Decoding)

}
#endif
