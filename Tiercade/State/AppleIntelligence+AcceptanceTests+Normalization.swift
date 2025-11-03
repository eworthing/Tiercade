import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Normalization Tests

@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal extension AcceptanceTestSuite {
static func testNormalization(logger: @escaping (String) -> Void) -> TestResult {
    logger("\n[Test 7/8] Normalization - edge case handling...")

    internal let testCases = buildNormalizationTestCases()
    internal let result = runNormalizationTests(testCases: testCases, logger: logger)

    internal let success = result.failed == 0
    internal let message = success
        ? "All \(testCases.count) normalization tests passed"
        : "\(result.failed)/\(testCases.count) normalization tests failed"

    return TestResult(
        testName: "Normalization",
        passed: success,
        message: message,
        details: [
            "passed": "\(result.passed)",
            "failed": "\(result.failed)",
            "failures": result.failures.joined(separator: "; ")
        ]
    )
}

static func buildNormalizationTestCases() -> [NormalizationTestCase] {
    [
        NormalizationTestCase(input: "The Matrix", expected: "matrix", description: "leading article"),
        NormalizationTestCase(input: "Star Trek™", expected: "star trek", description: "trademark symbol"),
        NormalizationTestCase(
            input: "Star Trek: The Next Generation",
            expected: "star trek next generation",
            description: "colon and article"
        ),
        NormalizationTestCase(input: "Star Trek (2009)", expected: "star trek", description: "year in parentheses"),
        NormalizationTestCase(
            input: "Doctor Who & Torchwood",
            expected: "doctor who and torchwood",
            description: "ampersand"
        ),
        NormalizationTestCase(input: "Pokémon", expected: "pokemon", description: "diacritic"),
        NormalizationTestCase(input: "Heroes", expected: "hero", description: "plural trim"),
        NormalizationTestCase(input: "The A-Team", expected: "team", description: "leading article + hyphen")
    ]
}

internal struct NormalizationTestResult: Sendable {
    internal let passed: Int
    internal let failed: Int
    internal let failures: [String]
}

static func runNormalizationTests(
    testCases: [NormalizationTestCase],
    logger: @escaping (String) -> Void
) -> NormalizationTestResult {
    internal var passed = 0
    internal var failed = 0
    internal var failures: [String] = []

    for testCase in testCases {
        internal let result = testCase.input.normKey
        if result == testCase.expected {
            passed += 1
            logger("  ✓ \(testCase.description): '\(testCase.input)' → '\(result)'")
        } else {
            failed += 1
            internal let msg = "\(testCase.description): '\(testCase.input)' → '\(result)' (expected '\(testCase.expected)')"
            failures.append(msg)
            logger("  ✗ \(msg)")
        }
    }

    return NormalizationTestResult(passed: passed, failed: failed, failures: failures)
}

// MARK: - Test 8: Token Budgeting

}
#endif
