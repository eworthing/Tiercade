import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Coordinator Experiments (DEBUG only)

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal struct CoordinatorExperimentRunner {
    internal struct Scenario: Sendable {
        internal let id: String
        internal let name: String
        internal let query: String
        internal let targetN: Int
        internal let seeds: [UInt64]
        internal let useGuidedBackfill: Bool
        internal let prewarm: Bool
        internal let hybridSwitchEnabled: Bool
        internal let guidedBudgetBumpFirst: Bool
    }

    internal struct DiagSummary: Codable, Sendable {
        internal let totalGenerated: Int?
        internal let dupCount: Int?
        internal let dupRate: Double?
        internal let backfillRounds: Int?
        internal let circuitBreakerTriggered: Bool?
        internal let passCount: Int?
        internal let failureReason: String?
    }

    internal struct SingleRunResult: Codable, Sendable {
        internal let scenarioId: String
        internal let scenarioName: String
        internal let seed: UInt64
        internal let guidedBackfill: Bool
        internal let prewarm: Bool
        internal let uniqueItems: Int
        internal let passAtN: Bool
        internal let duration: Double
        internal let diagnostics: DiagSummary
        internal let wouldEscalatePCC: Bool
    }

    internal struct Report: Codable, Sendable {
        internal let timestamp: Date
        internal let scenarios: [String]
        internal let totalRuns: Int
        internal let successfulRuns: Int
        internal let results: [SingleRunResult]
    }

    internal let onProgress: (String) -> Void

    init(onProgress: @escaping (String) -> Void = { print($0) }) {
        self.onProgress = onProgress
    }

    internal func runDefaultSuite() async -> Report {
        internal let scenarios: [Scenario] = [
            Scenario(
                id: "guided-n50",
                name: "Guided Backfill (N=50)",
                query: "best places to live in the United States",
                targetN: 50,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false
            ),
            Scenario(
                id: "unguided-n50",
                name: "Unguided Backfill (N=50)",
                query: "best places to live in the United States",
                targetN: 50,
                seeds: [42, 1337],
                useGuidedBackfill: false,
                prewarm: false,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false
            ),
            Scenario(
                id: "guided-n150-prewarm",
                name: "Guided Backfill (N=150, prewarm)",
                query: "best video games released in 2020-2023",
                targetN: 150,
                seeds: [42],
                useGuidedBackfill: true,
                prewarm: true,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false
            )
        ]

        return await run(scenarios: scenarios)
    }

    internal func runHybridComparisonSuite() async -> Report {
        internal let scenarios: [Scenario] = [
            Scenario(
                id: "guided-n150-hybrid-off",
                name: "Guided N=150 (Hybrid OFF)",
                query: "best video games released in 2020-2023",
                targetN: 150,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false
            ),
            Scenario(
                id: "guided-n150-hybrid-on",
                name: "Guided N=150 (Hybrid ON)",
                query: "best video games released in 2020-2023",
                targetN: 150,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: true,
                guidedBudgetBumpFirst: false
            )
        ]

        return await run(scenarios: scenarios)
    }

    internal func runMediumNMicroGrid() async -> Report {
        // Medium-N grid to select best arm by pass@N then time/unique
        internal let scenarios: [Scenario] = [
            // Guided only (baseline)
            Scenario(
                id: "guided-n50-baseline",
                name: "Guided N=50 (Baseline)",
                query: "best places to live in the United States",
                targetN: 50,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: false
            ),
            // Guided with budget bump only (no hybrid switch)
            Scenario(
                id: "guided-n50-bumpOnly",
                name: "Guided N=50 (Budget Bump)",
                query: "best places to live in the United States",
                targetN: 50,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: false,
                guidedBudgetBumpFirst: true
            ),
            // Hybrid (guided → unguided)
            Scenario(
                id: "hybrid-n50",
                name: "Hybrid N=50 (Guided→Unguided)",
                query: "best places to live in the United States",
                targetN: 50,
                seeds: [42, 1337],
                useGuidedBackfill: true,
                prewarm: false,
                hybridSwitchEnabled: true,
                guidedBudgetBumpFirst: false
            )
        ]

        internal let report = await run(scenarios: scenarios)

        // Pick best arm: highest pass@N; tie break by best time/unique
        internal var perScenario: [String: (pass: Int, total: Int, timePerUnique: Double)] = [:]
        for r in report.results {
            internal let key = r.scenarioId
            internal var entry = perScenario[key] ?? (0, 0, 0.0)
            entry.total += 1
            if r.passAtN { entry.pass += 1 }
            internal let tpu = r.uniqueItems > 0 ? r.duration / Double(r.uniqueItems) : r.duration
            entry.timePerUnique += tpu
            perScenario[key] = entry
        }
        internal var ranked: [(id: String, score: Double, tpu: Double)] = []
        for (id, v) in perScenario {
            internal let passRate = Double(v.pass) / Double(max(1, v.total))
            internal let avgTPU = v.timePerUnique / Double(max(1, v.total))
            ranked.append((id, passRate, avgTPU))
        }
        ranked.sort { (a, b) in
            if abs(a.score - b.score) > 0.0001 { return a.score > b.score }
            return a.tpu < b.tpu
        }
        if let best = ranked.first, let scenario = scenarios.first(where: { $0.id == best.id }) {
            onProgress("🏆 Medium‑N best arm: \(scenario.name) — pass@N=\(String(format: "%.1f%%", best.score*100)), avg TPU=\(String(format: "%.2f", best.tpu))")
        }
        return report
    }

    internal func run(scenarios: [Scenario]) async -> Report {
        onProgress("🔧 Coordinator experiments: starting (\(scenarios.count) scenarios)")

        internal var results: [SingleRunResult] = []
        internal var success = 0

        for scenario in scenarios {
            onProgress("▶︎ Scenario: \(scenario.name) seeds=\(scenario.seeds)")

            for seed in scenario.seeds {
                do {
                    internal let (items, duration, diag) = try await runSingle(
                        scenario: scenario,
                        seed: seed
                    )

                    internal let pass = items.count >= scenario.targetN
                    if pass { success += 1 }

                    internal let escalate = shouldEscalatePCC(diagnostics: diag, pass: pass)

                    results.append(SingleRunResult(
                        scenarioId: scenario.id,
                        scenarioName: scenario.name,
                        seed: seed,
                        guidedBackfill: scenario.useGuidedBackfill,
                        prewarm: scenario.prewarm,
                        uniqueItems: items.count,
                        passAtN: pass,
                        duration: duration,
                        diagnostics: DiagSummary(
                            totalGenerated: diag.totalGenerated,
                            dupCount: diag.dupCount,
                            dupRate: diag.dupRate,
                            backfillRounds: diag.backfillRounds,
                            circuitBreakerTriggered: diag.circuitBreakerTriggered,
                            passCount: diag.passCount,
                            failureReason: diag.failureReason
                        ),
                        wouldEscalatePCC: escalate
                    ))

                    internal let dupPct = diag.dupRate.map { String(format: "%.1f%%", $0 * 100) } ?? "n/a"
                    onProgress("  • seed=\(seed) pass=\(pass) unique=\(items.count) dup=\(dupPct) dur=\(String(format: "%.2fs", duration)) escalate=\(escalate)")

                } catch {
                    onProgress("  ❌ seed=\(seed) error: \(error.localizedDescription)")
                }
            }
        }

        internal let report = Report(
            timestamp: Date(),
            scenarios: scenarios.map { $0.name },
            totalRuns: results.count,
            successfulRuns: success,
            results: results
        )

        saveReport(report)
        onProgress("✅ Coordinator experiments complete: \(success)/\(results.count) passed")

        return report
    }

    private func runSingle(scenario: Scenario, seed: UInt64) async throws -> ([String], Double, UniqueListCoordinator.RunDiagnostics) {
        internal let instructions = Instructions("""
        You are a helpful assistant that generates lists.
        Always return valid JSON matching the requested schema.
        Ensure items are distinct and diverse.
        """)

        // Create session (prewarm optional; API may be a no-op on some builds)
        internal let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
        if scenario.prewarm {
            // If Apple exposes prewarm in this SDK, uncomment when available:
            // try? await session.prewarm(promptPrefix: "Return JSON only.")
            onProgress("  (prewarm requested) — continuing without explicit API")
        }

        internal let fm = FMClient(session: session, logger: { _ in })
        internal let coordinator = UniqueListCoordinator(
            fm: fm,
            logger: { _ in },
            useGuidedBackfill: scenario.useGuidedBackfill,
            hybridSwitchEnabled: scenario.hybridSwitchEnabled,
            guidedBudgetBumpFirst: scenario.guidedBudgetBumpFirst
        )

        internal let t0 = Date()
        internal let items = (try? await coordinator.uniqueList(
            query: scenario.query,
            targetCount: scenario.targetN,
            seed: seed
        )) ?? []
        internal let dt = Date().timeIntervalSince(t0)

        internal let diag = coordinator.getDiagnostics()
        return (items, dt, diag)
    }

    private func shouldEscalatePCC(diagnostics: UniqueListCoordinator.RunDiagnostics, pass: Bool) -> Bool {
        if pass { return false }
        if diagnostics.circuitBreakerTriggered == true { return true }
        if let passCount = diagnostics.passCount, passCount >= 3 { return true }
        return false
    }

    private func saveReport(_ report: Report) {
        internal let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            internal let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("coordinator_experiments_report.json")
            internal let data = try encoder.encode(report)
            try data.write(to: url)
            onProgress("📄 Saved coordinator report: \(url.path)")
        } catch {
            onProgress("⚠️ Failed to save coordinator report: \(error.localizedDescription)")
        }
    }
}
#endif
