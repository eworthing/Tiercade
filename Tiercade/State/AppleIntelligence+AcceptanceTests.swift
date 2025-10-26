import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Acceptance Test Suite
//
// Validates the unique list generation spec implementation:
// 1. Structure: JSON decodes on all runs, no extra prose
// 2. Uniqueness: Set(map(normKey)).count == N
// 3. Backfill: For injected duplicates in pass 1, final output still meets N via fill
// 4. Overflow: Artificially large avoid-list triggers chunking path and succeeds
// 5. Reproducibility: With fixed seed and same OS, outputs stable modulo known variability

#if canImport(FoundationModels) && DEBUG
@available(iOS 26.0, macOS 26.0, *)
@MainActor
enum AcceptanceTestSuite {

    // Seed ring for reproducible retries across tests
    static let seedRing: [UInt64] = [42, 1337, 9999, 123456, 987654]

    struct SeedRun {
        let seed: UInt64
        let ok: Bool
        let ips: Double
    }

    struct TestResult: Codable {
        let testName: String
        let passed: Bool
        let message: String
        let timestamp: Date
        let details: [String: String]

        init(testName: String, passed: Bool, message: String, details: [String: String] = [:]) {
            self.testName = testName
            self.passed = passed
            self.message = message
            self.timestamp = Date()
            self.details = details
        }
    }

    struct TestReport: Codable {
        let totalTests: Int
        let passed: Int
        let failed: Int
        let results: [TestResult]
        let environment: RunEnv
        let timestamp: Date

        var passRate: Double {
            guard totalTests > 0 else { return 0 }
            return Double(passed) / Double(totalTests)
        }
    }

    /// Compute median of array
    /// Run all acceptance tests
    static func runAll(logger: @escaping (String) -> Void = { print($0) }) async throws -> TestReport {
        logger("🧪 Starting Acceptance Test Suite")
        logger("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        var results: [TestResult] = []

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

        let passed = results.filter { $0.passed }.count
        let failed = results.count - passed

        let report = TestReport(
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

        logger("📄 Telemetry: /tmp/unique_list_runs.jsonl")

        return report
    }

    // MARK: - Test 1: Structure (JSON Decoding)

}
#endif
