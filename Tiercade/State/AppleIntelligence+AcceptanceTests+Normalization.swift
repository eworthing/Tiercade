import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Normalization Tests

@available(iOS 26.0, macOS 26.0, *)
@MainActor
extension AcceptanceTestSuite {
static func testNormalization(logger: @escaping (String) -> Void) -> TestResult {
    logger("\n[Test 7/8] Normalization - edge case handling...")

    let testCases = buildNormalizationTestCases()
    let result = runNormalizationTests(testCases: testCases, logger: logger)

    let success = result.failed == 0
    let message = success
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
    let passed: Int
    let failed: Int
    let failures: [String]
}

static func runNormalizationTests(
    testCases: [NormalizationTestCase],
    logger: @escaping (String) -> Void
) -> NormalizationTestResult {
    var passed = 0
    var failed = 0
    var failures: [String] = []

    for testCase in testCases {
        let result = testCase.input.normKey
        if result == testCase.expected {
            passed += 1
            logger("  ✓ \(testCase.description): '\(testCase.input)' → '\(result)'")
        } else {
            failed += 1
            let msg = "\(testCase.description): '\(testCase.input)' → '\(result)' (expected '\(testCase.expected)')"
            failures.append(msg)
            logger("  ✗ \(msg)")
        }
    }

    return NormalizationTestResult(passed: passed, failed: failed, failures: failures)
}

// MARK: - Test 8: Token Budgeting

}
#endif
