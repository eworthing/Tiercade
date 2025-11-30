import Foundation
import os
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - HeadToHead lifecycle

    func startHeadToHead() {
        if headToHead.isActive {
            showInfoToast("HeadToHead Already Active", message: "Finish or cancel the current matchup first")
            return
        }

        guard hasEnoughForPairing else {
            showInfoToast("Need More Items", message: "Add at least two items before starting HeadToHead")
            return
        }

        let pool = (tiers["unranked"] ?? []) + tierOrder.flatMap { tiers[$0] ?? [] }
        let targetComparisons = quickPhaseTargetComparisons(for: pool.count)
        let pairs = HeadToHeadLogic.initialComparisonQueueWarmStart(
            from: pool,
            records: [:],
            tierOrder: tierOrder,
            currentTiers: tiers,
            targetComparisonsPerItem: targetComparisons,
        )

        guard !pairs.isEmpty else {
            showInfoToast("Not Enough Comparisons", message: "Add more items before starting HeadToHead")
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

        // swiftformat:disable redundantSelf - Swift 6 requires explicit self in @autoclosure
        Logger.headToHead.info(
            """
            Started HeadToHead: pool=\(self.headToHead.pool.count) \
            target=\(targetComparisons) pairs=\(self.headToHead.totalComparisons)
            """,
        )
        // swiftformat:enable redundantSelf

        nextHeadToHeadPair()
    }

    func nextHeadToHeadPair() {
        guard headToHead.isActive else {
            return
        }

        if headToHead.pairsQueue.isEmpty, !headToHead.deferredPairs.isEmpty {
            headToHead.pairsQueue = headToHead.deferredPairs
            headToHead.deferredPairs = []
            // swiftformat:disable:next redundantSelf - Swift 6 requires explicit self in @autoclosure
            Logger.headToHead.info("Recycling skipped pairs: count=\(self.headToHead.pairsQueue.count)")
        }

        guard !headToHead.pairsQueue.isEmpty else {
            headToHead.currentPair = nil
            Logger.headToHead.debug("Next pair: queue empty")
            return
        }

        let pair = headToHead.pairsQueue.removeFirst()
        headToHead.currentPair = (pair.0, pair.1)
        // swiftformat:disable:next redundantSelf - Swift 6 requires explicit self in @autoclosure
        Logger.headToHead.debug("Next pair: \(pair.0.id)-\(pair.1.id), queue=\(self.headToHead.pairsQueue.count)")
    }

    func voteHeadToHead(winner: Item) {
        guard headToHead.isActive, let pair = headToHead.currentPair else {
            return
        }
        let a = pair.0
        let b = pair.1
        #if DEBUG
        let poolIds = Set(headToHead.pool.map(\.id))
        assert(
            poolIds.contains(a.id) && poolIds.contains(b.id),
            "Voting on items that are no longer in the HeadToHead pool",
        )
        #endif
        HeadToHeadLogic.vote(a, b, winner: winner, records: &headToHead.records)
        if headToHead.phase == .refinement {
            headToHead.refinementCompletedComparisons = min(
                headToHead.refinementCompletedComparisons + 1,
                headToHead.refinementTotalComparisons,
            )
        } else {
            headToHead.completedComparisons = min(headToHead.completedComparisons + 1, headToHead.totalComparisons)
        }
        headToHead.skippedPairKeys.remove(headToHeadPairKey(pair))
        headToHead.currentPair = nil
        nextHeadToHeadPair()

        autoAdvanceIfNeeded()

        let pairDesc = "\(a.id)-\(b.id)"
        if headToHead.phase == .refinement {
            let progress = "\(headToHead.refinementCompletedComparisons)/\(headToHead.refinementTotalComparisons)"
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(pairDesc) refine=\(progress)")
        } else {
            let progress = "\(headToHead.completedComparisons)/\(headToHead.totalComparisons)"
            Logger.headToHead.info("Vote: win=\(winner.id) pair=\(pairDesc) progress=\(progress)")
        }
    }

    func skipCurrentHeadToHeadPair() {
        guard headToHead.isActive, let pair = headToHead.currentPair else {
            return
        }
        headToHead.deferredPairs.append(pair)
        headToHead.skippedPairKeys.insert(headToHeadPairKey(pair))
        headToHead.currentPair = nil
        // swiftformat:disable redundantSelf - Swift 6 requires explicit self in @autoclosure
        Logger.headToHead.info(
            "Skipped pair: \(pair.0.id)-\(pair.1.id), deferred=\(self.headToHead.deferredPairs.count)",
        )
        // swiftformat:enable redundantSelf
        nextHeadToHeadPair()
    }

    func finishHeadToHead() {
        guard headToHead.isActive else {
            return
        }
        handleCombinedCompletion()
    }

    private func autoAdvanceIfNeeded() {
        guard headToHead.isActive else {
            return
        }
        let queueEmpty = headToHead.pairsQueue.isEmpty
        let deferredEmpty = headToHead.deferredPairs.isEmpty
        guard queueEmpty, deferredEmpty, headToHead.currentPair == nil else {
            return
        }
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
            baseTiers: tiers,
        )

        tiers = quick.tiers

        if let artifacts = quick.artifacts, !quick.suggestedPairs.isEmpty {
            transitionToRefinement(artifacts: artifacts, suggestedPairs: quick.suggestedPairs)
            return
        }

        finalizeHeadToHead(with: quick.artifacts)
    }

    private func transitionToRefinement(artifacts: HeadToHeadArtifacts, suggestedPairs: [(Item, Item)]) {
        headToHead.artifacts = artifacts
        headToHead.suggestedPairs = suggestedPairs
        headToHead.pairsQueue = suggestedPairs
        headToHead.deferredPairs = []
        headToHead.skippedPairKeys = []
        headToHead.refinementTotalComparisons = suggestedPairs.count
        headToHead.refinementCompletedComparisons = 0
        headToHead.phase = .refinement

        Logger.headToHead.info("Entering refinement phase: pairs=\(suggestedPairs.count)")
        nextHeadToHeadPair()
    }

    private func finalizeHeadToHead(with artifacts: HeadToHeadArtifacts?) {
        let snapshot = headToHead.initialSnapshot ?? captureTierSnapshot()
        if let artifacts {
            let result = HeadToHeadLogic.finalizeTiers(
                artifacts: artifacts,
                records: headToHead.records,
                tierOrder: tierOrder,
                baseTiers: tiers,
            )
            tiers = result.tiers
        }

        finalizeChange(action: "HeadToHead Results", undoSnapshot: snapshot)
        showSuccessToast("HeadToHead Complete", message: "Results applied to your tiers.")
        logPhaseSummary(
            prefix: "combined phase complete",
            debugSuffix: "combined phase complete counts",
            summary: tierSummary(),
        )
        headToHead.initialSnapshot = nil
        resetHeadToHeadSession()
    }

    private func finalizeRefinement(using artifacts: HeadToHeadArtifacts) {
        let result = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: headToHead.records,
            tierOrder: tierOrder,
            baseTiers: tiers,
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

    private func logPhaseSummary(prefix: String, debugSuffix _: String, summary: String) {
        Logger.headToHead.info("HeadToHead \(prefix): \(summary)")
    }

    func cancelHeadToHead(fromExitCommand: Bool = false) {
        guard headToHead.isActive else {
            return
        }
        #if os(tvOS)
        let debounceWindow = TVInteraction.exitCommandDebounce
        if
            fromExitCommand, let activated = headToHead.activatedAt,
            Date().timeIntervalSince(activated) < debounceWindow
        {
            Logger.headToHead.debug("Cancel ignored: exitCommand within debounce window")
            return
        }
        #endif
        resetHeadToHeadSession()
        showInfoToast("HeadToHead Cancelled", message: "No changes were made.")
        Logger.headToHead.info("HeadToHead cancelled: trigger=\(fromExitCommand ? "exitCommand" : "user")")
    }

    private func resetHeadToHeadSession(clearRecords: Bool = true) {
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

    private func headToHeadPairKey(_ pair: (Item, Item)) -> String {
        [pair.0.id, pair.1.id].sorted().joined(separator: "-")
    }

    private func quickPhaseTargetComparisons(for poolCount: Int) -> Int {
        guard poolCount > 1 else {
            return 0
        }
        let maxUnique = poolCount - 1

        // Adaptive comparison budget based on simulation evidence
        // (See TiercadeCore/Tests/SIMULATION_FINDINGS.md for full analysis)
        //
        // Key findings:
        // - Small pools (< 10): 3 comparisons achieve tau=0.73, 50% tier accuracy
        // - Medium pools (10-20): 4 comparisons maintain quality with scale
        // - Large pools (20-40): 5 comparisons needed to counteract dilution
        // - XL pools (40+): 6 comparisons for stable rankings
        //
        // This scaling ensures consistent quality across pool sizes while
        // respecting the user's time budget (Swiss system log₂(n) principle)
        let desired = switch poolCount {
        case 0 ..< 10:
            // Small pools: Excellent coverage with 3 comparisons/item
            // Simulation: tau=0.73, tier_accuracy=50%
            3
        case 10 ..< 20:
            // Medium pools: Scale up to maintain quality
            // Simulation: 4 comp/item improves tau from 0.42 → 0.63
            4
        case 20 ..< 40:
            // Large pools: Additional comparisons needed
            // Simulation: 5 comp/item achieves tau=0.66, efficiency=0.13
            5
        default:
            // XL pools: Maximum practical budget
            // Beyond 6, diminishing returns set in (see budget analysis)
            6
        }

        return max(1, min(desired, maxUnique))
    }

}
