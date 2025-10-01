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
        let pairs = HeadToHeadLogic.pairings(from: pool, rng: { Double.random(in: 0...1) })

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

        let log = "[AppState] startH2H: poolCount=\(h2hPool.count) totalPairs=\(h2hTotalComparisons)"
        print(log)
        NSLog("%@", log)
        appendDebugFile("startH2H: poolCount=\(h2hPool.count) totalPairs=\(h2hTotalComparisons)")

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
            appendDebugFile("nextH2HPair: recycling skipped pairs count=\(h2hPairsQueue.count)")
        }

        guard !h2hPairsQueue.isEmpty else {
            h2hPair = nil
            let message = "[AppState] nextH2HPair: no remaining pairs"
            print(message)
            NSLog("%@", message)
            appendDebugFile("nextH2HPair: queueEmpty")
            return
        }

        let pair = h2hPairsQueue.removeFirst()
        h2hPair = (pair.0, pair.1)
        let message = "[AppState] nextH2HPair: pair=\(pair.0.id)-\(pair.1.id) remainingQueue=\(h2hPairsQueue.count)"
        print(message)
        NSLog("%@", message)
        appendDebugFile("nextH2HPair: pair=\(pair.0.id)-\(pair.1.id) remainingQueue=\(h2hPairsQueue.count)")
    }

    func voteH2H(winner: Item) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0
        let b = pair.1
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
        appendDebugFile("voteH2H: winner=\(winner.id) completed=\(h2hCompletedComparisons)/\(h2hTotalComparisons)")
    }

    func skipCurrentH2HPair() {
        guard h2hActive, let pair = h2hPair else { return }
        h2hDeferredPairs.append(pair)
        h2hSkippedPairKeys.insert(h2hPairKey(pair))
        h2hPair = nil
        let message = "[AppState] skipH2H: pair=\(pair.0.id)-\(pair.1.id) deferredCount=\(h2hDeferredPairs.count)"
        print(message)
        NSLog("%@", message)
        appendDebugFile("skipH2H: pair=\(pair.0.id)-\(pair.1.id) deferredCount=\(h2hDeferredPairs.count)")
        nextH2HPair()
    }

    func finishH2H() {
        guard h2hActive else { return }
        let ranking = HeadToHeadLogic.ranking(from: h2hPool, records: h2hRecords)
        let distributed = HeadToHeadLogic.distributeRoundRobin(ranking, into: tierOrder, baseTiers: tiers)
        tiers = distributed
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        showSuccessToast("Head-to-Head Complete", message: "Results applied to your tiers.")
        let summary = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        resetH2HSession()
        let message = "[AppState] finishH2H: finished and distributed; counts: \(summary)"
        print(message)
        NSLog("%@", message)
        appendDebugFile("finishH2H: counts=\(summary)")
    }

    func cancelH2H(fromExitCommand: Bool = false) {
        guard h2hActive else { return }
        if fromExitCommand, let activatedAt = h2hActivatedAt, Date().timeIntervalSince(activatedAt) < 0.35 {
            appendDebugFile("cancelH2H: ignored exitCommand within debounce window")
            return
        }
        resetH2HSession()
        showInfoToast("Head-to-Head Cancelled", message: "No changes were made.")
        let trigger = fromExitCommand ? "exitCommand" : "user"
        appendDebugFile("cancelH2H: trigger=\(trigger)")
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
        if clearRecords {
            h2hRecords = [:]
        }
    }

    private func h2hPairKey(_ pair: (Item, Item)) -> String {
        [pair.0.id, pair.1.id].sorted().joined(separator: "-")
    }
}
