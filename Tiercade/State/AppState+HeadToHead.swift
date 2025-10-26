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

        h2hInitialSnapshot = captureTierSnapshot()
        h2hPool = pool
        h2hRecords = [:]
        h2hPairsQueue = pairs
        h2hDeferredPairs = []
        h2hTotalComparisons = pairs.count
        h2hCompletedComparisons = 0
        h2hRefinementTotalComparisons = 0
        h2hRefinementCompletedComparisons = 0
        h2hSkippedPairKeys = []
        h2hPair = nil
        h2hActive = true
        h2hActivatedAt = Date()
        h2hPhase = .quick
        h2hArtifacts = nil
        h2hSuggestedPairs = []

        Logger.headToHead.info(
            "Started H2H: pool=\(self.h2hPool.count) target=\(targetComparisons) pairs=\(self.h2hTotalComparisons)"
        )

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
        if h2hPhase == .refinement {
            h2hRefinementCompletedComparisons = min(
                h2hRefinementCompletedComparisons + 1,
                h2hRefinementTotalComparisons
            )
        } else {
            h2hCompletedComparisons = min(h2hCompletedComparisons + 1, h2hTotalComparisons)
        }
        h2hSkippedPairKeys.remove(h2hPairKey(pair))
        h2hPair = nil
        nextH2HPair()

        autoAdvanceIfNeeded()

        if h2hPhase == .refinement {
            // swiftlint:disable:next line_length
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(a.id)-\(b.id) target=\(self.h2hRefinementCompletedComparisons)/\(self.h2hRefinementTotalComparisons)")
        } else {
            // swiftlint:disable:next line_length
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(a.id)-\(b.id) progress=\(self.h2hCompletedComparisons)/\(self.h2hTotalComparisons)")
        }
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
        handleCombinedCompletion()
    }

    private func autoAdvanceIfNeeded() {
        guard h2hActive else { return }
        guard h2hPairsQueue.isEmpty, h2hDeferredPairs.isEmpty, h2hPair == nil else { return }
        handleCombinedCompletion()
    }

    private func handleCombinedCompletion() {
        if let artifacts = h2hArtifacts, h2hPairsQueue.isEmpty {
            finalizeRefinement(using: artifacts)
            return
        }

        let quick = HeadToHeadLogic.quickTierPass(
            from: h2hPool,
            records: h2hRecords,
            tierOrder: tierOrder,
            baseTiers: tiers
        )

        tiers = quick.tiers

        if let artifacts = quick.artifacts, !quick.suggestedPairs.isEmpty {
            transitionToRefinement(artifacts: artifacts, suggestedPairs: quick.suggestedPairs)
            return
        }

        finalizeHeadToHead(with: quick.artifacts)
    }

    private func transitionToRefinement(artifacts: H2HArtifacts, suggestedPairs: [(Item, Item)]) {
        h2hArtifacts = artifacts
        h2hSuggestedPairs = suggestedPairs
        h2hPairsQueue = suggestedPairs
        h2hDeferredPairs = []
        h2hSkippedPairKeys = []
        h2hRefinementTotalComparisons = suggestedPairs.count
        h2hRefinementCompletedComparisons = 0
        h2hPhase = .refinement

        Logger.headToHead.info("Entering refinement phase: pairs=\(suggestedPairs.count)")
        nextH2HPair()
    }

    private func finalizeHeadToHead(with artifacts: H2HArtifacts?) {
        let snapshot = h2hInitialSnapshot ?? captureTierSnapshot()
        if let artifacts {
            let result = HeadToHeadLogic.finalizeTiers(
                artifacts: artifacts,
                records: h2hRecords,
                tierOrder: tierOrder,
                baseTiers: tiers
            )
            tiers = result.tiers
        }

        finalizeChange(action: "Head-to-Head Results", undoSnapshot: snapshot)
        showSuccessToast("Head-to-Head Complete", message: "Results applied to your tiers.")
        logPhaseSummary(
            prefix: "combined phase complete",
            debugSuffix: "combined phase complete counts",
            summary: tierSummary()
        )
        h2hInitialSnapshot = nil
        resetH2HSession()
    }

    private func finalizeRefinement(using artifacts: H2HArtifacts) {
        let result = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: h2hRecords,
            tierOrder: tierOrder,
            baseTiers: tiers
        )

        tiers = result.tiers
        h2hArtifacts = nil
        h2hSuggestedPairs = []
        finalizeHeadToHead(with: nil)
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
        h2hRefinementTotalComparisons = 0
        h2hRefinementCompletedComparisons = 0
        h2hSkippedPairKeys = []
        h2hActivatedAt = nil
        h2hPhase = .quick
        h2hArtifacts = nil
        h2hSuggestedPairs = []
        if clearRecords {
            h2hRecords = [:]
        }
        h2hInitialSnapshot = nil
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
