import Foundation
import os
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Head-to-Head lifecycle

    func startH2H() {
        if headToHead.isActive {
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

        headToHead.initialSnapshot = captureTierSnapshot()
        headToHead.pool = pool
        headToHead.records = [:]
        headToHead.pairsQueue = pairs
        headToHead.deferredPairs = []
        headToHead.totalComparisons = pairs.count
        headToHead.completedComparisons = 0
        headToHead.refinementTotalComparisons = 0
        headToHead.refinementCompletedComparisons = 0
        headToHead.skippedPairKeys = []
        headToHead.currentPair = nil
        headToHead.isActive = true
        headToHead.activatedAt = Date()
        headToHead.phase = .quick
        headToHead.artifacts = nil
        headToHead.suggestedPairs = []

        Logger.headToHead.info(
            "Started H2H: pool=\(self.headToHead.pool.count) target=\(targetComparisons) pairs=\(self.headToHead.totalComparisons)"
        )

        nextH2HPair()
    }

    func nextH2HPair() {
        guard headToHead.isActive else { return }

        if headToHead.pairsQueue.isEmpty, !headToHead.deferredPairs.isEmpty {
            headToHead.pairsQueue = headToHead.deferredPairs
            headToHead.deferredPairs = []
            Logger.headToHead.info("Recycling skipped pairs: count=\(self.headToHead.pairsQueue.count)")
        }

        guard !headToHead.pairsQueue.isEmpty else {
            headToHead.currentPair = nil
            Logger.headToHead.debug("Next pair: queue empty")
            return
        }

        let pair = headToHead.pairsQueue.removeFirst()
        headToHead.currentPair = (pair.0, pair.1)
        Logger.headToHead.debug("Next pair: \(pair.0.id)-\(pair.1.id), queue=\(self.headToHead.pairsQueue.count)")
    }

    func voteH2H(winner: Item) {
        guard headToHead.isActive, let pair = headToHead.currentPair else { return }
        let a = pair.0
        let b = pair.1
        #if DEBUG
        let poolIds = Set(headToHead.pool.map(\.id))
        assert(
            poolIds.contains(a.id) && poolIds.contains(b.id),
            "Voting on items that are no longer in the head-to-head pool"
        )
        #endif
        HeadToHeadLogic.vote(a, b, winner: winner, records: &headToHead.records)
        if headToHead.phase == .refinement {
            headToHead.refinementCompletedComparisons = min(
                headToHead.refinementCompletedComparisons + 1,
                headToHead.refinementTotalComparisons
            )
        } else {
            headToHead.completedComparisons = min(headToHead.completedComparisons + 1, headToHead.totalComparisons)
        }
        headToHead.skippedPairKeys.remove(h2hPairKey(pair))
        headToHead.currentPair = nil
        nextH2HPair()

        autoAdvanceIfNeeded()

        if headToHead.phase == .refinement {
            // swiftlint:disable:next line_length
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(a.id)-\(b.id) target=\(self.headToHead.refinementCompletedComparisons)/\(self.headToHead.refinementTotalComparisons)")
        } else {
            // swiftlint:disable:next line_length
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(a.id)-\(b.id) progress=\(self.headToHead.completedComparisons)/\(self.headToHead.totalComparisons)")
        }
    }

    func skipCurrentH2HPair() {
        guard headToHead.isActive, let pair = headToHead.currentPair else { return }
        headToHead.deferredPairs.append(pair)
        headToHead.skippedPairKeys.insert(h2hPairKey(pair))
        headToHead.currentPair = nil
        Logger.headToHead.info("Skipped pair: \(pair.0.id)-\(pair.1.id), deferred=\(self.headToHead.deferredPairs.count)")
        nextH2HPair()
    }

    func finishH2H() {
        guard headToHead.isActive else { return }
        handleCombinedCompletion()
    }

    private func autoAdvanceIfNeeded() {
        guard headToHead.isActive else { return }
        guard headToHead.pairsQueue.isEmpty, headToHead.deferredPairs.isEmpty, headToHead.currentPair == nil else { return }
        handleCombinedCompletion()
    }

    private func handleCombinedCompletion() {
        if let artifacts = headToHead.artifacts, headToHead.pairsQueue.isEmpty {
            finalizeRefinement(using: artifacts)
            return
        }

        let quick = HeadToHeadLogic.quickTierPass(
            from: headToHead.pool,
            records: headToHead.records,
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
        headToHead.artifacts = artifacts
        headToHead.suggestedPairs = suggestedPairs
        headToHead.pairsQueue = suggestedPairs
        headToHead.deferredPairs = []
        headToHead.skippedPairKeys = []
        headToHead.refinementTotalComparisons = suggestedPairs.count
        headToHead.refinementCompletedComparisons = 0
        headToHead.phase = .refinement

        Logger.headToHead.info("Entering refinement phase: pairs=\(suggestedPairs.count)")
        nextH2HPair()
    }

    private func finalizeHeadToHead(with artifacts: H2HArtifacts?) {
        let snapshot = headToHead.initialSnapshot ?? captureTierSnapshot()
        if let artifacts {
            let result = HeadToHeadLogic.finalizeTiers(
                artifacts: artifacts,
                records: headToHead.records,
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
        headToHead.initialSnapshot = nil
        resetH2HSession()
    }

    private func finalizeRefinement(using artifacts: H2HArtifacts) {
        let result = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: headToHead.records,
            tierOrder: tierOrder,
            baseTiers: tiers
        )

        tiers = result.tiers
        headToHead.artifacts = nil
        headToHead.suggestedPairs = []
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
        guard headToHead.isActive else { return }
        #if os(tvOS)
        if fromExitCommand, let activatedAt = headToHead.activatedAt, Date().timeIntervalSince(activatedAt) < TVInteraction.exitCommandDebounce {
            Logger.headToHead.debug("Cancel ignored: exitCommand within debounce window")
            return
        }
        #endif
        resetH2HSession()
        showInfoToast("Head-to-Head Cancelled", message: "No changes were made.")
        Logger.headToHead.info("H2H cancelled: trigger=\(fromExitCommand ? "exitCommand" : "user")")
    }

    private func resetH2HSession(clearRecords: Bool = true) {
        headToHead.isActive = false
        headToHead.currentPair = nil
        headToHead.pool = []
        headToHead.pairsQueue = []
        headToHead.deferredPairs = []
        headToHead.totalComparisons = 0
        headToHead.completedComparisons = 0
        headToHead.refinementTotalComparisons = 0
        headToHead.refinementCompletedComparisons = 0
        headToHead.skippedPairKeys = []
        headToHead.activatedAt = nil
        headToHead.phase = .quick
        headToHead.artifacts = nil
        headToHead.suggestedPairs = []
        if clearRecords {
            headToHead.records = [:]
        }
        headToHead.initialSnapshot = nil
    }

    private func h2hPairKey(_ pair: (Item, Item)) -> String {
        [pair.0.id, pair.1.id].sorted().joined(separator: "-")
    }

    private func quickPhaseTargetComparisons(for poolCount: Int) -> Int {
        guard poolCount > 1 else { return 0 }
        let maxUnique = poolCount - 1
        let desired: Int
        if poolCount >= H2HHeuristics.largePoolThreshold {
            desired = H2HHeuristics.largeDesiredComparisons
        } else if poolCount >= H2HHeuristics.mediumPoolThreshold {
            desired = H2HHeuristics.mediumDesiredComparisons
        } else {
            desired = H2HHeuristics.smallDesiredComparisons
        }
        return max(1, min(desired, maxUnique))
    }

}
