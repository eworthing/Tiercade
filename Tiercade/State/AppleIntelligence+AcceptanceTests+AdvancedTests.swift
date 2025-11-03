import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Advanced Tests

@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal extension AcceptanceTestSuite {
static func testOverflowHandling(logger: @escaping (String) -> Void) async -> TestResult {
    logger("\n[Test 5/8] Overflow - chunked avoid-list handling...")

    // Test token budgeting with a large avoid-list
    internal let largeAvoidList = (0..<1000).map { "item_\($0)" }
    internal let chunks = largeAvoidList.chunkedByTokenBudget(maxTokens: 800)

    guard chunks.count > 1 else {
        return TestResult(
            testName: "Overflow",
            passed: false,
            message: "Failed to chunk large avoid-list (got \(chunks.count) chunks)"
        )
    }

    // Validate chunks are reasonable sizes
    internal let allItemsCount = chunks.flatMap { $0 }.count
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

static func testReproducibility(logger: @escaping (String) -> Void) async -> TestResult {
    logger("\n[Test 6/8] Reproducibility - fixed seed stability...")

    do {
        guard let session1 = try? await createTestSession(),
              internal let session2 = try? await createTestSession() else {
            return TestResult(
                testName: "Reproducibility",
                passed: false,
                message: "Failed to create test sessions"
            )
        }

        internal let fm1 = FMClient(session: session1, logger: { _ in })
        internal let coordinator1 = UniqueListCoordinator(fm: fm1, logger: { _ in })

        internal let fm2 = FMClient(session: session2, logger: { _ in })
        internal let coordinator2 = UniqueListCoordinator(fm: fm2, logger: { _ in })

        internal let fixedSeed: UInt64 = 999
        internal let query = "classic video game characters"
        internal let targetCount = 15

        internal let items1 = try await coordinator1.uniqueList(query: query, targetCount: targetCount, seed: fixedSeed)
        internal let items2 = try await coordinator2.uniqueList(query: query, targetCount: targetCount, seed: fixedSeed)

        // Check normKey stability
        internal let keys1 = items1.map { $0.normKey }
        internal let keys2 = items2.map { $0.normKey }

        // Count overlap
        internal let set1 = Set(keys1)
        internal let set2 = Set(keys2)
        internal let overlap = set1.intersection(set2).count
        internal let overlapPercent = Double(overlap) / Double(max(keys1.count, keys2.count)) * 100

        // We expect high but not necessarily 100% overlap due to model variability
        internal let threshold = 60.0 // 60% overlap is reasonable
        internal let success = overlapPercent >= threshold

        internal let maxCount = max(keys1.count, keys2.count)
        internal let message = "Overlap: \(overlap)/\(maxCount) (\(String(format: "%.1f", overlapPercent))%)"
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

internal struct NormalizationTestCase {
    internal let input: String
    internal let expected: String
    internal let description: String
}

static func testTokenBudgeting(logger: @escaping (String) -> Void) -> TestResult {
    logger("\n[Test 8/8] Token Budgeting - chunking algorithm...")

    // Test various chunking scenarios
    internal var allPassed = true

    // Scenario 1: Small list fits in one chunk
    internal let small = ["a", "b", "c"]
    internal let smallChunks = small.chunkedByTokenBudget(maxTokens: 100)
    if smallChunks.count != 1 {
        logger("  ✗ Small list: expected 1 chunk, got \(smallChunks.count)")
        allPassed = false
    } else {
        logger("  ✓ Small list: 1 chunk")
    }

    // Scenario 2: Large list requires multiple chunks
    internal let large = (0..<100).map { "item_\($0)" }
    internal let largeChunks = large.chunkedByTokenBudget(maxTokens: 50)
    if largeChunks.count <= 1 {
        logger("  ✗ Large list: expected multiple chunks, got \(largeChunks.count)")
        allPassed = false
    } else {
        logger("  ✓ Large list: \(largeChunks.count) chunks")
    }

    // Scenario 3: All items preserved
    internal let flattenedCount = largeChunks.flatMap { $0 }.count
    if flattenedCount != large.count {
        logger("  ✗ Items lost: \(flattenedCount)/\(large.count)")
        allPassed = false
    } else {
        logger("  ✓ All items preserved: \(flattenedCount)")
    }

    internal let message = allPassed
        ? "Token budgeting tests passed"
        : "Some token budgeting tests failed"

    return TestResult(
        testName: "TokenBudgeting",
        passed: allPassed,
        message: message
    )
}

// MARK: - Helper

}
#endif
