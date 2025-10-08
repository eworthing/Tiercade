import Foundation
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

        let log = "[AppState] startH2H: poolCount=\(h2hPool.count) initialTarget=\(targetComparisons) scheduledPairs=\(h2hTotalComparisons)"
        print(log)
        NSLog("%@", log)
        Task { await appendDebugFile("startH2H: poolCount=\(h2hPool.count) totalPairs=\(h2hTotalComparisons)") }

        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }

        if h2hPairsQueue.isEmpty, !h2hDeferredPairs.isEmpty {
            h2hPairsQueue = h2hDeferredPairs
            h2hDeferredPairs = []
            let recycle = "[AppState] nextH2HPair: recycling skipped pairs count=\(h2hPairsQueue.count)"
            print(recycle)
            NSLog("%@", recycle)
            Task { await appendDebugFile("nextH2HPair: recycling skipped pairs count=\(h2hPairsQueue.count)") }
        }

        guard !h2hPairsQueue.isEmpty else {
            h2hPair = nil
            let message = "[AppState] nextH2HPair: no remaining pairs"
            print(message)
            NSLog("%@", message)
            Task { await appendDebugFile("nextH2HPair: queueEmpty") }
            return
        }

        let pair = h2hPairsQueue.removeFirst()
        h2hPair = (pair.0, pair.1)
        let pairDescriptor = "\(pair.0.id)-\(pair.1.id)"
        let remainingQueue = h2hPairsQueue.count
        let message = [
            "[AppState] nextH2HPair:",
            "pair=\(pairDescriptor)",
            "remainingQueue=\(remainingQueue)"
        ].joined(separator: " ")
        print(message)
        NSLog("%@", message)
        Task {
            await appendDebugFile(
                "nextH2HPair: pair=\(pairDescriptor) remainingQueue=\(remainingQueue)"
            )
        }
    }

    func voteH2H(winner: Item) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0
        let b = pair.1
#if DEBUG
        let poolIds = Set(h2hPool.map(\.id))
        assert(poolIds.contains(a.id) && poolIds.contains(b.id), "Voting on items that are no longer in the head-to-head pool")
#endif
        HeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        h2hCompletedComparisons = min(h2hCompletedComparisons + 1, h2hTotalComparisons)
        h2hSkippedPairKeys.remove(h2hPairKey(pair))
        h2hPair = nil
        nextH2HPair()

        let message = [
            "[AppState] voteH2H:",
            "winner=\(winner.id)",
            "pair=\(a.id)-\(b.id)",
            "completed=\(h2hCompletedComparisons)/\(h2hTotalComparisons)",
            "remainingQueue=\(h2hPairsQueue.count)",
            "records=\(h2hRecords.count)"
        ].joined(separator: " ")
        print(message)
        NSLog("%@", message)
        Task {
            await appendDebugFile(
                "voteH2H: winner=\(winner.id) completed=\(h2hCompletedComparisons)/\(h2hTotalComparisons)"
            )
        }
    }

    func skipCurrentH2HPair() {
        guard h2hActive, let pair = h2hPair else { return }
        h2hDeferredPairs.append(pair)
        h2hSkippedPairKeys.insert(h2hPairKey(pair))
        h2hPair = nil
        let messageComponents = [
            "[AppState] skipH2H:",
            "pair=\(pair.0.id)-\(pair.1.id)",
            "deferredCount=\(h2hDeferredPairs.count)"
        ]
        let message = messageComponents.joined(separator: " ")
        print(message)
        NSLog("%@", message)
        Task {
            await appendDebugFile(
                "skipH2H: pair=\(pair.0.id)-\(pair.1.id) deferredCount=\(h2hDeferredPairs.count)"
            )
        }
        nextH2HPair()
    }

    func finishH2H() {
        guard h2hActive else { return }
        switch h2hPhase {
        case .quick:
            let quick = HeadToHeadLogic.quickTierPass(
                from: h2hPool,
                records: h2hRecords,
                tierOrder: tierOrder,
                baseTiers: tiers
            )

            var appliedTiers = quick.tiers
            var artifacts = quick.artifacts

            if let initialArtifacts = artifacts, quick.suggestedPairs.isEmpty {
                let (finalTiers, updatedArtifacts) = HeadToHeadLogic.finalizeTiers(
                    artifacts: initialArtifacts,
                    records: h2hRecords,
                    tierOrder: tierOrder,
                    baseTiers: tiers
                )
                appliedTiers = finalTiers
                artifacts = updatedArtifacts
            }

            tiers = appliedTiers
            markAsChanged()

            if let artifacts, !quick.suggestedPairs.isEmpty {
                h2hArtifacts = artifacts
                h2hSuggestedPairs = quick.suggestedPairs
                h2hPairsQueue = quick.suggestedPairs
                h2hDeferredPairs = []
                h2hSkippedPairKeys = []
                h2hTotalComparisons = quick.suggestedPairs.count
                h2hCompletedComparisons = 0
                h2hPhase = .refinement
                let message = "[AppState] finishH2H: entering refinement phase with \(quick.suggestedPairs.count) pairs"
                print(message)
                NSLog("%@", message)
                showInfoToast(
                    "Preliminary Results Applied",
                    message: "Complete \(quick.suggestedPairs.count) targeted matchups to refine your tiers."
                )
                Task {
                    await appendDebugFile("finishH2H: entering refinement phase with \(quick.suggestedPairs.count) pairs")
                }
                nextH2HPair()
                return
            }

            history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
            showSuccessToast("Head-to-Head Complete", message: "Results applied to your tiers.")
            let summary = tierOrder
                .map { "\($0):\(tiers[$0]?.count ?? 0)" }
                .joined(separator: ", ")
            let message = "[AppState] finishH2H: quick phase complete; counts: \(summary)"
            print(message)
            NSLog("%@", message)
            Task { await appendDebugFile("finishH2H: quick phase complete counts=\(summary)") }
            resetH2HSession()

        case .refinement:
            guard let artifacts = h2hArtifacts else {
                h2hPhase = .quick
                finishH2H()
                return
            }

            let (finalTiers, updatedArtifacts) = HeadToHeadLogic.finalizeTiers(
                artifacts: artifacts,
                records: h2hRecords,
                tierOrder: tierOrder,
                baseTiers: tiers
            )
            tiers = finalTiers
            h2hArtifacts = updatedArtifacts
            history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
            markAsChanged()
            showSuccessToast("Head-to-Head Complete", message: "Refined tiers applied.")
            let summary = tierOrder
                .map { "\($0):\(tiers[$0]?.count ?? 0)" }
                .joined(separator: ", ")
            let message = "[AppState] finishH2H: refinement phase complete; counts: \(summary)"
            print(message)
            NSLog("%@", message)
            Task { await appendDebugFile("finishH2H: refinement phase complete counts=\(summary)") }
            resetH2HSession()
        }
    }

    func cancelH2H(fromExitCommand: Bool = false) {
        guard h2hActive else { return }
        if fromExitCommand, let activatedAt = h2hActivatedAt, Date().timeIntervalSince(activatedAt) < 0.35 {
            Task { await appendDebugFile("cancelH2H: ignored exitCommand within debounce window") }
            return
        }
        resetH2HSession()
        showInfoToast("Head-to-Head Cancelled", message: "No changes were made.")
        let trigger = fromExitCommand ? "exitCommand" : "user"
        Task { await appendDebugFile("cancelH2H: trigger=\(trigger)") }
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
