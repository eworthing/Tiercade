import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Coordinator Experiments (DEBUG only)

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal struct CoordinatorExperimentRunner {
    struct Scenario: Sendable {
        let id: String
        let name: String
        let query: String
        let targetN: Int
        let seeds: [UInt64]
        let useGuidedBackfill: Bool
        let prewarm: Bool
        let hybridSwitchEnabled: Bool
        let guidedBudgetBumpFirst: Bool
    }

    struct DiagSummary: Codable, Sendable {
        let totalGenerated: Int?
        let dupCount: Int?
        let dupRate: Double?
        let backfillRounds: Int?
        let circuitBreakerTriggered: Bool?
        let passCount: Int?
        let failureReason: String?
    }

    struct SingleRunResult: Codable, Sendable {
        let scenarioId: String
        let scenarioName: String
        let seed: UInt64
        let guidedBackfill: Bool
        let prewarm: Bool
        let uniqueItems: Int
        let passAtN: Bool
        let duration: Double
        let diagnostics: DiagSummary
        let wouldEscalatePCC: Bool
    }

    struct Report: Codable, Sendable {
        let timestamp: Date
        let scenarios: [String]
        let totalRuns: Int
        let successfulRuns: Int
        let results: [SingleRunResult]
    }

    let onProgress: (String) -> Void

    init(onProgress: @escaping (String) -> Void = { print($0) }) {
        self.onProgress = onProgress
    }

    func runDefaultSuite() async -> Report {
        let scenarios: [Scenario] = [
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

    func runHybridComparisonSuite() async -> Report {
        let scenarios: [Scenario] = [
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

    func runMediumNMicroGrid() async -> Report {
        // Medium-N grid to select best arm by pass@N then time/unique
        let scenarios: [Scenario] = [
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

        let report = await run(scenarios: scenarios)

        // Pick best arm: highest pass@N; tie break by best time/unique
        struct ScenarioMetrics {
            var pass: Int
            var total: Int
            var timePerUnique: Double
        }
        var perScenario: [String: ScenarioMetrics] = [:]
        for r in report.results {
            let key = r.scenarioId
            var entry = perScenario[key] ?? ScenarioMetrics(pass: 0, total: 0, timePerUnique: 0.0)
            entry.total += 1
            if r.passAtN { entry.pass += 1 }
            let tpu = r.uniqueItems > 0 ? r.duration / Double(r.uniqueItems) : r.duration
            entry.timePerUnique += tpu
            perScenario[key] = entry
        }
        struct RankedScenario {
            let id: String
            let score: Double
            let tpu: Double
        }
        var ranked: [RankedScenario] = []
        for (id, v) in perScenario {
            let passRate = Double(v.pass) / Double(max(1, v.total))
            let avgTPU = v.timePerUnique / Double(max(1, v.total))
            ranked.append(RankedScenario(id: id, score: passRate, tpu: avgTPU))
        }
        ranked.sort { (a, b) in
            if abs(a.score - b.score) > 0.0001 { return a.score > b.score }
            return a.tpu < b.tpu
        }
        if let best = ranked.first, let scenario = scenarios.first(where: { $0.id == best.id }) {
            let scoreStr = String(format: "%.1f%%", best.score*100)
            let tpuStr = String(format: "%.2f", best.tpu)
            onProgress("🏆 Medium‑N best arm: \(scenario.name) — pass@N=\(scoreStr), avg TPU=\(tpuStr)")
        }
        return report
    }

    func run(scenarios: [Scenario]) async -> Report {
        onProgress("🔧 Coordinator experiments: starting (\(scenarios.count) scenarios)")

        var results: [SingleRunResult] = []
        var success = 0

        for scenario in scenarios {
            onProgress("▶︎ Scenario: \(scenario.name) seeds=\(scenario.seeds)")

            for seed in scenario.seeds {
                do {
                    let result = try await runSingle(
                        scenario: scenario,
                        seed: seed
                    )

                    let pass = result.items.count >= scenario.targetN
                    if pass { success += 1 }

                    let escalate = shouldEscalatePCC(diagnostics: result.diagnostics, pass: pass)

                    results.append(SingleRunResult(
                        scenarioId: scenario.id,
                        scenarioName: scenario.name,
                        seed: seed,
                        guidedBackfill: scenario.useGuidedBackfill,
                        prewarm: scenario.prewarm,
                        uniqueItems: result.items.count,
                        passAtN: pass,
                        duration: result.duration,
                        diagnostics: DiagSummary(
                            totalGenerated: result.diagnostics.totalGenerated,
                            dupCount: result.diagnostics.dupCount,
                            dupRate: result.diagnostics.dupRate,
                            backfillRounds: result.diagnostics.backfillRounds,
                            circuitBreakerTriggered: result.diagnostics.circuitBreakerTriggered,
                            passCount: result.diagnostics.passCount,
                            failureReason: result.diagnostics.failureReason
                        ),
                        wouldEscalatePCC: escalate
                    ))

                    let dupPct = result.diagnostics.dupRate.map { String(format: "%.1f%%", $0 * 100) } ?? "n/a"
                    let durStr = String(format: "%.2fs", result.duration)
                    let uniqueCount = result.items.count
                    onProgress("  • seed=\(seed) pass=\(pass) unique=\(uniqueCount) dup=\(dupPct) dur=\(durStr) escalate=\(escalate)")

                } catch {
                    onProgress("  ❌ seed=\(seed) error: \(error.localizedDescription)")
                }
            }
        }

        let report = Report(
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

    struct RunResult {
        let items: [String]
        let duration: Double
        let diagnostics: UniqueListCoordinator.RunDiagnostics
    }

    private func runSingle(scenario: Scenario, seed: UInt64) async throws -> RunResult {
        let instructions = Instructions("""
        You are a helpful assistant that generates lists.
        Always return valid JSON matching the requested schema.
        Ensure items are distinct and diverse.
        """)

        // Create session (prewarm optional; API may be a no-op on some builds)
        let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)
        if scenario.prewarm {
            // If Apple exposes prewarm in this SDK, uncomment when available:
            // try? await session.prewarm(promptPrefix: "Return JSON only.")
            onProgress("  (prewarm requested) — continuing without explicit API")
        }

        let fm = FMClient(session: session, logger: { _ in })
        let coordinator = UniqueListCoordinator(
            fm: fm,
            logger: { _ in },
            useGuidedBackfill: scenario.useGuidedBackfill,
            hybridSwitchEnabled: scenario.hybridSwitchEnabled,
            guidedBudgetBumpFirst: scenario.guidedBudgetBumpFirst
        )

        let t0 = Date()
        let items = (try? await coordinator.uniqueList(
            query: scenario.query,
            targetCount: scenario.targetN,
            seed: seed
        )) ?? []
        let dt = Date().timeIntervalSince(t0)

        let diag = coordinator.getDiagnostics()
        return RunResult(items: items, duration: dt, diagnostics: diag)
    }

    private func shouldEscalatePCC(diagnostics: UniqueListCoordinator.RunDiagnostics, pass: Bool) -> Bool {
        if pass { return false }
        if diagnostics.circuitBreakerTriggered == true { return true }
        if let passCount = diagnostics.passCount, passCount >= 3 { return true }
        return false
    }

    private func saveReport(_ report: Report) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("coordinator_experiments_report.json")
            let data = try encoder.encode(report)
            try data.write(to: url)
            onProgress("📄 Saved coordinator report: \(url.path)")
        } catch {
            onProgress("⚠️ Failed to save coordinator report: \(error.localizedDescription)")
        }
    }
}
#endif
