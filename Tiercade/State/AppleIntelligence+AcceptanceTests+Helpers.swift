import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Test Helpers

@available(iOS 26.0, macOS 26.0, *)
@MainActor
extension AcceptanceTestSuite {
static func median(_ xs: [Double]) -> Double {
    guard !xs.isEmpty else { return 0 }
    let s = xs.sorted()
    let n = s.count
    return n % 2 == 1 ? s[n/2] : 0.5 * (s[n/2 - 1] + s[n/2])
}

struct SeedRunResults {
    let passAtN: Double
    let medianIPS: Double
    let runs: [SeedRun]
}

/// Run test across seed ring with telemetry export
static func runAcrossSeeds(
    testId: String,
    query: String,
    targetN: Int,
    logger: @escaping (String) -> Void,
    makeCoordinator: () async throws -> UniqueListCoordinator
) async -> SeedRunResults {
    var runs: [SeedRun] = []

    for seed in seedRing {
        do {
            let coordinator = try await makeCoordinator()
            let t0 = Date()
            let items = (try? await coordinator.uniqueList(query: query, targetCount: targetN, seed: seed)) ?? []
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

    let passAtN = Double(runs.filter { $0.ok }.count) / Double(seedRing.count)
    let medianIPS = median(runs.map { $0.ips })

    let seedResults = runs.map { $0.ok }
    logger(
        "🔎 \(testId): pass@N=\(String(format: "%.2f", passAtN))  " +
        "per-seed=\(seedResults)  median ips=\(String(format: "%.2f", medianIPS))"
    )

    return SeedRunResults(passAtN: passAtN, medianIPS: medianIPS, runs: runs)
}


static func createTestSession() async throws -> LanguageModelSession {
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

}
#endif
