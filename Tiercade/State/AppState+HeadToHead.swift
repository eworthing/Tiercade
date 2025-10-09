import Foundation
import os
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Head-to-Head lifecycle

    func startH2H() {
        if h2hActive {
            showInfoToast("Head-to-Head Already Active", message: "Finish or cancel the current matchup first")
            return
        }

        guard hasEnoughForPairing else {
            showInfoToast("Need More Items", message: "Add at least two items before starting Head-to-Head")
            return
        }

        let pool = (tiers["unranked"] ?? []) + tierOrder.flatMap { tiers[$0] ?? [] }
        let targetComparisons = quickPhaseTargetComparisons(for: pool.count)
        let pairs = HeadToHeadLogic.initialComparisonQueueWarmStart(
            from: pool,
            records: [:],
            tierOrder: tierOrder,
            currentTiers: tiers,
            targetComparisonsPerItem: targetComparisons
        )

        guard !pairs.isEmpty else {
            showInfoToast("Not Enough Matchups", message: "Add more items before starting Head-to-Head")
            return
        }

        h2hPool = pool
        h2hRecords = [:]
        h2hPairsQueue = pairs
        h2hDeferredPairs = []
        h2hTotalComparisons = pairs.count
        h2hCompletedComparisons = 0
        h2hSkippedPairKeys = []
        h2hPair = nil
        h2hActive = true
        h2hActivatedAt = Date()
        h2hPhase = .quick
        h2hArtifacts = nil
        h2hSuggestedPairs = []

        Logger.headToHead.info("Started H2H: pool=\(self.h2hPool.count) target=\(targetComparisons) pairs=\(self.h2hTotalComparisons)")

        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }

        if h2hPairsQueue.isEmpty, !h2hDeferredPairs.isEmpty {
            h2hPairsQueue = h2hDeferredPairs
            h2hDeferredPairs = []
            Logger.headToHead.info("Recycling skipped pairs: count=\(self.h2hPairsQueue.count)")
        }

        guard !h2hPairsQueue.isEmpty else {
            h2hPair = nil
            Logger.headToHead.debug("Next pair: queue empty")
            return
        }

        let pair = h2hPairsQueue.removeFirst()
        h2hPair = (pair.0, pair.1)
        Logger.headToHead.debug("Next pair: \(pair.0.id)-\(pair.1.id), queue=\(self.h2hPairsQueue.count)")
    }

    func voteH2H(winner: Item) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0
        let b = pair.1
#if DEBUG
        let poolIds = Set(h2hPool.map(\.id))
        assert(
            poolIds.contains(a.id) && poolIds.contains(b.id),
            "Voting on items that are no longer in the head-to-head pool"
        )
#endif
        HeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        h2hCompletedComparisons = min(h2hCompletedComparisons + 1, h2hTotalComparisons)
        h2hSkippedPairKeys.remove(h2hPairKey(pair))
        h2hPair = nil
        nextH2HPair()

        Logger.headToHead.info("Vote: winner=\(winner.id) pair=\(a.id)-\(b.id) progress=\(self.h2hCompletedComparisons)/\(self.h2hTotalComparisons)")
    }

    func skipCurrentH2HPair() {
        guard h2hActive, let pair = h2hPair else { return }
        h2hDeferredPairs.append(pair)
        h2hSkippedPairKeys.insert(h2hPairKey(pair))
        h2hPair = nil
        Logger.headToHead.info("Skipped pair: \(pair.0.id)-\(pair.1.id), deferred=\(self.h2hDeferredPairs.count)")
        nextH2HPair()
    }

    func finishH2H() {
        guard h2hActive else { return }
        switch h2hPhase {
        case .quick:
            handleQuickPhaseCompletion()
        case .refinement:
            handleRefinementCompletion()
        }
    }

    private func handleQuickPhaseCompletion() {
        let quick = HeadToHeadLogic.quickTierPass(
            from: h2hPool,
            records: h2hRecords,
            tierOrder: tierOrder,
            baseTiers: tiers
        )

        var appliedTiers = quick.tiers
        var artifacts = quick.artifacts

        if let initialArtifacts = artifacts, quick.suggestedPairs.isEmpty {
            let result = HeadToHeadLogic.finalizeTiers(
                artifacts: initialArtifacts,
                records: h2hRecords,
                tierOrder: tierOrder,
                baseTiers: tiers
            )
            appliedTiers = result.tiers
            artifacts = result.updatedArtifacts
        }

        tiers = appliedTiers
        markAsChanged()

        if let artifacts, !quick.suggestedPairs.isEmpty {
            transitionToRefinement(artifacts: artifacts, suggestedPairs: quick.suggestedPairs)
            return
        }

        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        showSuccessToast("Head-to-Head Complete", message: "Results applied to your tiers.")
        logPhaseSummary(
            prefix: "quick phase complete",
            debugSuffix: "quick phase complete counts",
            summary: tierSummary()
        )
        resetH2HSession()
    }

    private func transitionToRefinement(artifacts: H2HArtifacts, suggestedPairs: [(Item, Item)]) {
        h2hArtifacts = artifacts
        h2hSuggestedPairs = suggestedPairs
        h2hPairsQueue = suggestedPairs
        h2hDeferredPairs = []
        h2hSkippedPairKeys = []
        h2hTotalComparisons = suggestedPairs.count
        h2hCompletedComparisons = 0
        h2hPhase = .refinement

        Logger.headToHead.info("Entering refinement phase: pairs=\(suggestedPairs.count)")
        showInfoToast(
            "Preliminary Results Applied",
            message: "Complete \(suggestedPairs.count) targeted matchups to refine your tiers."
        )
        nextH2HPair()
    }

    private func handleRefinementCompletion() {
        guard let artifacts = h2hArtifacts else {
            h2hPhase = .quick
            finishH2H()
            return
        }

        let result = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: h2hRecords,
            tierOrder: tierOrder,
            baseTiers: tiers
        )

        tiers = result.tiers
        h2hArtifacts = result.updatedArtifacts
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        showSuccessToast("Head-to-Head Complete", message: "Refined tiers applied.")
        logPhaseSummary(
            prefix: "refinement phase complete",
            debugSuffix: "refinement phase complete counts",
            summary: tierSummary()
        )
        resetH2HSession()
    }

    private func tierSummary() -> String {
        tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
    }

    private func logPhaseSummary(prefix: String, debugSuffix: String, summary: String) {
        Logger.headToHead.info("H2H \(prefix): \(summary)")
    }

    func cancelH2H(fromExitCommand: Bool = false) {
        guard h2hActive else { return }
        if fromExitCommand, let activatedAt = h2hActivatedAt, Date().timeIntervalSince(activatedAt) < 0.35 {
            Logger.headToHead.debug("Cancel ignored: exitCommand within debounce window")
            return
        }
        resetH2HSession()
        showInfoToast("Head-to-Head Cancelled", message: "No changes were made.")
        Logger.headToHead.info("H2H cancelled: trigger=\(fromExitCommand ? "exitCommand" : "user")")
    }

    private func resetH2HSession(clearRecords: Bool = true) {
        h2hActive = false
        h2hPair = nil
        h2hPool = []
        h2hPairsQueue = []
        h2hDeferredPairs = []
        h2hTotalComparisons = 0
        h2hCompletedComparisons = 0
        h2hSkippedPairKeys = []
        h2hActivatedAt = nil
        h2hPhase = .quick
        h2hArtifacts = nil
        h2hSuggestedPairs = []
        if clearRecords {
            h2hRecords = [:]
        }
    }

    private func h2hPairKey(_ pair: (Item, Item)) -> String {
        [pair.0.id, pair.1.id].sorted().joined(separator: "-")
    }

    private func quickPhaseTargetComparisons(for poolCount: Int) -> Int {
        guard poolCount > 1 else { return 0 }
        let maxUnique = poolCount - 1
        let desired: Int
        if poolCount >= 10 {
            desired = 3
        } else if poolCount >= 6 {
            desired = 3
        } else {
            desired = 2
        }
        return max(1, min(desired, maxUnique))
    }

}
