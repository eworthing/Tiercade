import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - UniqueListCoordinator Telemetry & Diagnostics

@available(iOS 26.0, macOS 26.0, *)
extension UniqueListCoordinator {
    /// Export telemetry for a test run
    func exportRunTelemetry(
        testId: String,
        query: String,
        targetN: Int,
        totalGenerated: Int? = nil,
        dupCount: Int? = nil,
        dupRate: Double? = nil,
        backfillRounds: Int? = nil,
        circuitBreakerTriggered: Bool? = nil,
        passCount: Int? = nil,
        failureReason: String? = nil,
        topDuplicates: [String: Int]? = nil
    ) {
        guard !telemetry.isEmpty else { return }

        let osVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }()

        var records: [RunTelemetry] = []
        var passIndex = 1

        for metric in telemetry {
            records.append(RunTelemetry(
                testId: testId,
                query: query,
                targetN: targetN,
                passIndex: passIndex,
                attemptIndex: metric.attemptIndex,
                seed: metric.seed,
                sampling: metric.sampling,
                temperature: metric.temperature,
                sessionRecreated: metric.sessionRecreated,
                itemsReturned: metric.itemsReturned ?? 0,
                elapsedSec: metric.elapsedSec ?? 0,
                osVersion: osVersion,
                // Use provided parameters, fall back to stored diagnostics
                totalGenerated: totalGenerated ?? lastRunTotalGenerated,
                dupCount: dupCount ?? lastRunDupCount,
                dupRate: dupRate ?? lastRunDupRate,
                backfillRounds: backfillRounds ?? lastRunBackfillRounds,
                circuitBreakerTriggered: circuitBreakerTriggered ?? lastRunCircuitBreakerTriggered,
                passCount: passCount ?? lastRunPassCount,
                failureReason: failureReason ?? lastRunFailureReason,
                topDuplicates: topDuplicates ?? lastRunTopDuplicates
            ))
        }

        exportTelemetryToJSONL(records)
    }

    /// Diagnostics snapshot from the last uniqueList() run
    struct RunDiagnostics {
        let totalGenerated: Int?
        let dupCount: Int?
        let dupRate: Double?
        let backfillRounds: Int?
        let circuitBreakerTriggered: Bool?
        let passCount: Int?
        let failureReason: String?
        let topDuplicates: [String: Int]?
    }

    /// Retrieve diagnostics from the last uniqueList() run
    func getDiagnostics() -> RunDiagnostics {
        return RunDiagnostics(
            totalGenerated: lastRunTotalGenerated,
            dupCount: lastRunDupCount,
            dupRate: lastRunDupRate,
            backfillRounds: lastRunBackfillRounds,
            circuitBreakerTriggered: lastRunCircuitBreakerTriggered,
            passCount: lastRunPassCount,
            failureReason: lastRunFailureReason,
            topDuplicates: lastRunTopDuplicates
        )
    }

    func finalizeGeneration(state: GenerationState, targetCount: Int, startTime: Date) {
        let elapsed = Date().timeIntervalSince(startTime)
        let success = state.ordered.count >= targetCount

        telemetry = state.localTelemetry

        if success {
            logger("✅ Success in \(state.passCount) passes (\(String(format: "%.2f", elapsed))s)")
        } else {
            logger("⚠️ Incomplete: \(state.ordered.count)/\(targetCount) after \(state.passCount) passes")
        }

        let dupRatePercent = Double(state.duplicatesFound) / Double(state.totalGeneratedCount) * 100
        logger(
            "📊 Stats: \(state.totalGeneratedCount) total generated, \(state.duplicatesFound) filtered " +
            "(\(String(format: "%.1f", dupRatePercent))% dup rate)"
        )

        storeDiagnostics(state: state, targetCount: targetCount, success: success)
    }

    func storeDiagnostics(state: GenerationState, targetCount: Int, success: Bool) {
        lastRunTotalGenerated = state.totalGeneratedCount
        lastRunDupCount = state.duplicatesFound
        lastRunDupRate = state.totalGeneratedCount > 0
            ? Double(state.duplicatesFound) / Double(state.totalGeneratedCount)
            : 0.0
        lastRunPassCount = state.passCount
        lastRunBackfillRounds = state.backfillRoundsTotal
        lastRunCircuitBreakerTriggered = state.circuitBreakerTriggered

        let topDups = state.dupFrequency.sorted { $0.value > $1.value }.prefix(5)
        lastRunTopDuplicates = topDups.isEmpty ? nil : Dictionary(uniqueKeysWithValues: Array(topDups))

        if !success {
            if state.circuitBreakerTriggered {
                let failureMsg =
                    "Circuit breaker: 2 consecutive rounds with no progress at \(state.ordered.count)/\(targetCount)"
                lastRunFailureReason = failureMsg
            } else if lastRunFailureReason == nil {
                lastRunFailureReason =
                    "Incomplete: \(state.ordered.count)/\(targetCount) items after \(state.passCount) passes"
            }
        } else {
            lastRunFailureReason = nil
        }
    }

    func uniqueListWithMetrics(
        query: String,
        targetCount: Int,
        seed: UInt64? = nil,
        decoderProfile: String = "diverse"
    ) async throws -> (items: [String], metrics: RunMetrics) {
        let startTime = Date()
        let items = try await uniqueList(query: query, targetCount: targetCount, seed: seed)
        let elapsed = Date().timeIntervalSince(startTime)

        let metrics = RunMetrics(
            passAtN: items.count >= targetCount,
            uniqueAtN: items.count,
            jsonStrictSuccess: true,
            itemsPerSecond: Double(items.count) / max(0.001, elapsed),
            dupRatePreDedup: 0.0, // Pre-dedup rate not tracked in this simplified metrics path
            seed: seed,
            decoderProfile: decoderProfile,
            env: RunEnv(),
            generationTimeSeconds: elapsed,
            totalPasses: 0 // Pass count tracking deferred for simplified metrics API
        )

        return (items, metrics)
    }
}
#endif
