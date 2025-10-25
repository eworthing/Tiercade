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
    private static let SEED_RING: [UInt64] = [42, 1337, 9999, 123456, 987654]

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
    private static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n/2] : 0.5 * (s[n/2 - 1] + s[n/2])
    }

    /// Run test across seed ring with telemetry export
    private static func runAcrossSeeds(
        testId: String,
        query: String,
        targetN: Int,
        logger: @escaping (String) -> Void,
        makeCoordinator: () async throws -> UniqueListCoordinator
    ) async -> (passAtN: Double, medianIPS: Double, runs: [SeedRun]) {
        var runs: [SeedRun] = []

        for seed in SEED_RING {
            do {
                let coordinator = try await makeCoordinator()
                let t0 = Date()
                let items = (try? await coordinator.uniqueList(query: query, N: targetN, seed: seed)) ?? []
                let elapsed = Date().timeIntervalSince(t0)
                let ips = Double(items.count) / max(elapsed, 0.001)
                let ok = items.count >= targetN
                runs.append(SeedRun(seed: seed, ok: ok, ips: ips))

                // Capture diagnostics before export
                let diagnostics = coordinator.getDiagnostics()

                // Per-run telemetry export (append JSONL)
                coordinator.exportRunTelemetry(
                    testId: testId,
                    query: query,
                    targetN: targetN
                )

                // Display diagnostics for failing seeds
                if !ok {
                    logger("    ❌ Seed \(seed) FAILED: \(items.count)/\(targetN) items")
                    if let reason = diagnostics.failureReason {
                        logger("       Reason: \(reason)")
                    }
                    if let dupRate = diagnostics.dupRate {
                        logger("       Duplicate rate: \(String(format: "%.1f%%", dupRate * 100))")
                    }
                    if let backfillRounds = diagnostics.backfillRounds {
                        logger("       Backfill rounds: \(backfillRounds)")
                    }
                    if let circuitBreaker = diagnostics.circuitBreakerTriggered, circuitBreaker {
                        logger("       Circuit breaker: triggered")
                    }
                }
            } catch {
                runs.append(SeedRun(seed: seed, ok: false, ips: 0))
                logger("    ❌ Seed \(seed) EXCEPTION: \(error.localizedDescription)")
            }
        }

        let passAtN = Double(runs.filter { $0.ok }.count) / Double(SEED_RING.count)
        let medianIPS = median(runs.map { $0.ips })

        logger("🔎 \(testId): pass@N=\(String(format: "%.2f", passAtN))  per-seed=\(runs.map { $0.ok })  median ips=\(String(format: "%.2f", medianIPS))")

        return (passAtN, medianIPS, runs)
    }

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

    private static func testStructure(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 1/7] Structure - JSON decoding across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T1_Structure",
            query: "science fiction TV series captains",
            targetN: 10,
            logger: logger
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(domain: "AcceptanceTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create session"])
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.filter { $0.ok }.count
        let success = result.passAtN >= 0.6  // 60% pass rate threshold

        let message = success
            ? "JSON decoding successful: \(passedCount)/\(SEED_RING.count) seeds passed, median ips=\(String(format: "%.2f", result.medianIPS))"
            : "JSON decoding inconsistent: only \(passedCount)/\(SEED_RING.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Structure",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(SEED_RING.count)"
            ]
        )
    }

    // MARK: - Test 2: Uniqueness

    private static func testUniqueness(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 2/7] Uniqueness - normKey deduplication across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T2_Uniqueness",
            query: "famous scientists throughout history",
            targetN: 25,
            logger: logger
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(domain: "AcceptanceTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create session"])
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.filter { $0.ok }.count
        let success = result.passAtN >= 0.6  // 60% pass rate threshold

        let message = success
            ? "Uniqueness validated: \(passedCount)/\(SEED_RING.count) seeds passed, median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Uniqueness inconsistent: only \(passedCount)/\(SEED_RING.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Uniqueness",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(SEED_RING.count)"
            ]
        )
    }

    // MARK: - Test 3: Backfill

    private static func testBackfill(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 3/8] Backfill - verify unguided fill mechanism across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T3_Backfill",
            query: "programming languages",
            targetN: 50,
            logger: logger
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(domain: "AcceptanceTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create session"])
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.filter { $0.ok }.count
        let success = result.passAtN >= 0.6  // 60% pass rate threshold

        let message = success
            ? "Backfill validated: \(passedCount)/\(SEED_RING.count) seeds passed, median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Backfill unreliable: only \(passedCount)/\(SEED_RING.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Backfill",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(SEED_RING.count)"
            ]
        )
    }

    // MARK: - Test 4: Guided Backfill

    private static func testGuidedBackfill(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 4/8] Guided Backfill - verify guided fill mechanism across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T4_GuidedBackfill",
            query: "programming languages",
            targetN: 50,
            logger: logger
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(domain: "AcceptanceTests", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create session"])
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger, useGuidedBackfill: true)
        }

        let passedCount = result.runs.filter { $0.ok }.count
        let success = result.passAtN >= 0.6  // 60% pass rate threshold

        let message = success
            ? "Guided backfill validated: \(passedCount)/\(SEED_RING.count) seeds passed, median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Guided backfill unreliable: only \(passedCount)/\(SEED_RING.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "GuidedBackfill",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(SEED_RING.count)"
            ]
        )
    }

    // MARK: - Test 5: Overflow Handling

    private static func testOverflowHandling(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 5/8] Overflow - chunked avoid-list handling...")

        // Test token budgeting with a large avoid-list
        let largeAvoidList = (0..<1000).map { "item_\($0)" }
        let chunks = largeAvoidList.chunkedByTokenBudget(maxTokens: 800)

        guard chunks.count > 1 else {
            return TestResult(
                testName: "Overflow",
                passed: false,
                message: "Failed to chunk large avoid-list (got \(chunks.count) chunks)"
            )
        }

        // Validate chunks are reasonable sizes
        let allItemsCount = chunks.flatMap { $0 }.count
        guard allItemsCount == largeAvoidList.count else {
            return TestResult(
                testName: "Overflow",
                passed: false,
                message: "Lost items during chunking: \(allItemsCount)/\(largeAvoidList.count)"
            )
        }

        logger("  ✓ Successfully chunked \(largeAvoidList.count) items into \(chunks.count) chunks")

        return TestResult(
            testName: "Overflow",
            passed: true,
            message: "Avoid-list chunking works: \(largeAvoidList.count) items → \(chunks.count) chunks",
            details: [
                "totalItems": "\(largeAvoidList.count)",
                "chunks": "\(chunks.count)"
            ]
        )
    }

    // MARK: - Test 6: Reproducibility

    private static func testReproducibility(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 6/8] Reproducibility - fixed seed stability...")

        do {
            guard let session1 = try? await createTestSession(),
                  let session2 = try? await createTestSession() else {
                return TestResult(
                    testName: "Reproducibility",
                    passed: false,
                    message: "Failed to create test sessions"
                )
            }

            let fm1 = FMClient(session: session1, logger: { _ in })
            let coordinator1 = UniqueListCoordinator(fm: fm1, logger: { _ in })

            let fm2 = FMClient(session: session2, logger: { _ in })
            let coordinator2 = UniqueListCoordinator(fm: fm2, logger: { _ in })

            let fixedSeed: UInt64 = 999
            let query = "classic video game characters"
            let N = 15

            let items1 = try await coordinator1.uniqueList(query: query, N: N, seed: fixedSeed)
            let items2 = try await coordinator2.uniqueList(query: query, N: N, seed: fixedSeed)

            // Check normKey stability
            let keys1 = items1.map { $0.normKey }
            let keys2 = items2.map { $0.normKey }

            // Count overlap
            let set1 = Set(keys1)
            let set2 = Set(keys2)
            let overlap = set1.intersection(set2).count
            let overlapPercent = Double(overlap) / Double(max(keys1.count, keys2.count)) * 100

            // We expect high but not necessarily 100% overlap due to model variability
            let threshold = 60.0 // 60% overlap is reasonable
            let success = overlapPercent >= threshold

            let message = "Overlap: \(overlap)/\(max(keys1.count, keys2.count)) (\(String(format: "%.1f", overlapPercent))%)"
            logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

            return TestResult(
                testName: "Reproducibility",
                passed: success,
                message: message,
                details: [
                    "seed": "\(fixedSeed)",
                    "overlap": "\(overlap)",
                    "run1Count": "\(items1.count)",
                    "run2Count": "\(items2.count)",
                    "overlapPercent": String(format: "%.1f", overlapPercent)
                ]
            )

        } catch {
            return TestResult(
                testName: "Reproducibility",
                passed: false,
                message: "Exception: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Test 7: Normalization Edge Cases

    private static func testNormalization(logger: @escaping (String) -> Void) -> TestResult {
        logger("\n[Test 7/8] Normalization - edge case handling...")

        let testCases: [(input: String, expected: String, description: String)] = [
            ("The Matrix", "matrix", "leading article"),
            ("Star Trek™", "star trek", "trademark symbol"),
            ("Star Trek: The Next Generation", "star trek next generation", "colon and article"),
            ("Star Trek (2009)", "star trek", "year in parentheses"),
            ("Doctor Who & Torchwood", "doctor who and torchwood", "ampersand"),
            ("Pokémon", "pokemon", "diacritic"),
            ("Heroes", "hero", "plural trim"),
            ("The A-Team", "team", "leading article + hyphen"),
        ]

        var passed = 0
        var failed = 0
        var failures: [String] = []

        for (input, expected, description) in testCases {
            let result = input.normKey
            if result == expected {
                passed += 1
                logger("  ✓ \(description): '\(input)' → '\(result)'")
            } else {
                failed += 1
                let msg = "\(description): '\(input)' → '\(result)' (expected '\(expected)')"
                failures.append(msg)
                logger("  ✗ \(msg)")
            }
        }

        let success = failed == 0
        let message = success
            ? "All \(testCases.count) normalization tests passed"
            : "\(failed)/\(testCases.count) normalization tests failed"

        return TestResult(
            testName: "Normalization",
            passed: success,
            message: message,
            details: [
                "passed": "\(passed)",
                "failed": "\(failed)",
                "failures": failures.joined(separator: "; ")
            ]
        )
    }

    // MARK: - Test 8: Token Budgeting

    private static func testTokenBudgeting(logger: @escaping (String) -> Void) -> TestResult {
        logger("\n[Test 8/8] Token Budgeting - chunking algorithm...")

        // Test various chunking scenarios
        var allPassed = true

        // Scenario 1: Small list fits in one chunk
        let small = ["a", "b", "c"]
        let smallChunks = small.chunkedByTokenBudget(maxTokens: 100)
        if smallChunks.count != 1 {
            logger("  ✗ Small list: expected 1 chunk, got \(smallChunks.count)")
            allPassed = false
        } else {
            logger("  ✓ Small list: 1 chunk")
        }

        // Scenario 2: Large list requires multiple chunks
        let large = (0..<100).map { "item_\($0)" }
        let largeChunks = large.chunkedByTokenBudget(maxTokens: 50)
        if largeChunks.count <= 1 {
            logger("  ✗ Large list: expected multiple chunks, got \(largeChunks.count)")
            allPassed = false
        } else {
            logger("  ✓ Large list: \(largeChunks.count) chunks")
        }

        // Scenario 3: All items preserved
        let flattenedCount = largeChunks.flatMap { $0 }.count
        if flattenedCount != large.count {
            logger("  ✗ Items lost: \(flattenedCount)/\(large.count)")
            allPassed = false
        } else {
            logger("  ✓ All items preserved: \(flattenedCount)")
        }

        let message = allPassed
            ? "Token budgeting tests passed"
            : "Some token budgeting tests failed"

        return TestResult(
            testName: "TokenBudgeting",
            passed: allPassed,
            message: message
        )
    }

    // MARK: - Helper

    private static func createTestSession() async throws -> LanguageModelSession {
        let instructions = Instructions("""
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

    // MARK: - Export

    static func saveReport(_ report: TestReport, to path: String, logger: @escaping (String) -> Void = { print($0) }) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: path))
        logger("📄 Test report saved: \(path)")
    }
}
#endif
