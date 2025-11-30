import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Core Tests

@available(iOS 26.0, macOS 26.0, *)
@MainActor
extension AcceptanceTestSuite {
    static func testStructure(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 1/7] Structure - JSON decoding across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T1_Structure",
            query: "science fiction TV series captains",
            targetN: 10,
            logger: logger,
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(
                    domain: "AcceptanceTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create session"],
                )
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.count(where: { $0.ok })
        let success = result.passAtN >= 0.6 // 60% pass rate threshold

        let message = success
            ? "JSON decoding successful: \(passedCount)/\(seedRing.count) seeds passed, " +
            "median ips=\(String(format: "%.2f", result.medianIPS))"
            : "JSON decoding inconsistent: only \(passedCount)/\(seedRing.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Structure",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(seedRing.count)",
            ],
        )
    }

    // MARK: - Test 2: Uniqueness

    static func testUniqueness(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 2/7] Uniqueness - normKey deduplication across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T2_Uniqueness",
            query: "famous scientists throughout history",
            targetN: 25,
            logger: logger,
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(
                    domain: "AcceptanceTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create session"],
                )
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.count(where: { $0.ok })
        let success = result.passAtN >= 0.6 // 60% pass rate threshold

        let message = success
            ? "Uniqueness validated: \(passedCount)/\(seedRing.count) seeds passed, " +
            "median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Uniqueness inconsistent: only \(passedCount)/\(seedRing.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Uniqueness",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(seedRing.count)",
            ],
        )
    }

    // MARK: - Test 3: Backfill

    static func testBackfill(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 3/8] Backfill - verify unguided fill mechanism across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T3_Backfill",
            query: "programming languages",
            targetN: 50,
            logger: logger,
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(
                    domain: "AcceptanceTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create session"],
                )
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger)
        }

        let passedCount = result.runs.count(where: { $0.ok })
        let success = result.passAtN >= 0.6 // 60% pass rate threshold

        let message = success
            ? "Backfill validated: \(passedCount)/\(seedRing.count) seeds passed, " +
            "median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Backfill unreliable: only \(passedCount)/\(seedRing.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "Backfill",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(seedRing.count)",
            ],
        )
    }

    // MARK: - Test 4: Guided Backfill

    static func testGuidedBackfill(logger: @escaping (String) -> Void) async -> TestResult {
        logger("\n[Test 4/8] Guided Backfill - verify guided fill mechanism across seed ring...")

        let result = await runAcrossSeeds(
            testId: "T4_GuidedBackfill",
            query: "programming languages",
            targetN: 50,
            logger: logger,
        ) {
            guard let session = try? await createTestSession() else {
                throw NSError(
                    domain: "AcceptanceTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create session"],
                )
            }
            let fm = FMClient(session: session, logger: logger)
            return UniqueListCoordinator(fm: fm, logger: logger, useGuidedBackfill: true)
        }

        let passedCount = result.runs.count(where: { $0.ok })
        let success = result.passAtN >= 0.6 // 60% pass rate threshold

        let message = success
            ? "Guided backfill validated: \(passedCount)/\(seedRing.count) seeds passed, " +
            "median ips=\(String(format: "%.2f", result.medianIPS))"
            : "Guided backfill unreliable: only \(passedCount)/\(seedRing.count) seeds passed"

        logger(success ? "  ✓ \(message)" : "  ⚠️ \(message)")

        return TestResult(
            testName: "GuidedBackfill",
            passed: success,
            message: message,
            details: [
                "passAtN": String(format: "%.2f", result.passAtN),
                "medianIPS": String(format: "%.2f", result.medianIPS),
                "seedsPassed": "\(passedCount)/\(seedRing.count)",
            ],
        )
    }

    // MARK: - Test 5: Overflow Handling

}
#endif
