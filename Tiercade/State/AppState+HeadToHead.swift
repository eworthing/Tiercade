import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Head to Head
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
        h2hPool = pool
        h2hRecords = [:]
        h2hActive = true
        print("[AppState] startH2H: poolCount=\(h2hPool.count)")
        NSLog("[AppState] startH2H: poolCount=%d", h2hPool.count)
        appendDebugFile("startH2H: poolCount=\(h2hPool.count)")
        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }
        if let pair = HeadToHeadLogic.pickPair(from: h2hPool, rng: { Double.random(in: 0...1) }) {
            h2hPair = (pair.0, pair.1)
            let message = "[AppState] nextH2HPair: pair=\(pair.0.id) vs \(pair.1.id)"
            print(message)
            NSLog("%@", message)
        } else {
            h2hPair = nil
            let message = "[AppState] nextH2HPair: no pair available (ending H2H?)"
            print(message)
            NSLog("%@", message)
        }
    }

    func voteH2H(winner: Item) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0, b = pair.1
        HeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        nextH2HPair()
        let message = [
            "[AppState] voteH2H:",
            "winner=\(winner.id)",
            "pair=\(a.id)-\(b.id)",
            "remainingPool=\(h2hPool.count)",
            "records=\(h2hRecords.count)"
        ].joined(separator: " ")
        print(message)
        NSLog("%@", message)
    }

    func finishH2H() {
        guard h2hActive else { return }
        let ranking = HeadToHeadLogic.ranking(from: h2hPool, records: h2hRecords)
        let distributed = HeadToHeadLogic.distributeRoundRobin(ranking, into: tierOrder, baseTiers: tiers)
        tiers = distributed
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        h2hActive = false
        h2hPair = nil
        h2hPool = []
        h2hRecords = [:]
        let summary = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        let message = "[AppState] finishH2H: finished and distributed; counts: \(summary)"
        print(message)
        NSLog("%@", message)
        appendDebugFile("finishH2H: counts=\(summary)")
    }
}
