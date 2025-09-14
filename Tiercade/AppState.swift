import Foundation
import SwiftUI

// Ensure SharedCore types are accessible
// TL* types defined in SharedCore.swift should be available in same module

@MainActor
final class AppState: ObservableObject {
    @Published var tiers: TLTiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    @Published var tierOrder: [String] = ["S","A","B","C","D","F"]
    @Published var searchQuery: String = ""
    @Published var toast: String? = nil
    @Published var quickRankTarget: TLContestant? = nil
    // Head-to-Head
    @Published var h2hActive: Bool = false
    @Published var h2hPool: [TLContestant] = []
    @Published var h2hPair: (TLContestant, TLContestant)? = nil
    @Published var h2hRecords: [String: TLH2HRecord] = [:]
    private let storageKey = "Tiercade.tiers.v1"

    private var history = TLHistory<TLTiers>(stack: [], index: 0, limit: 80)

    init() {
        if !load() {
            seed()
        }
        history = TLHistoryLogic.initHistory(tiers, limit: 80)
    }

    func seed() {
        tiers["unranked"] = [
            TLContestant(id: "kyle48", name: "Kyle Fraser", season: "48"),
            TLContestant(id: "parvati", name: "Parvati Shallow", season: "Multiple"),
            TLContestant(id: "sandra", name: "Sandra Diaz-Twine", season: "Multiple")
        ]
    }

    func move(_ id: String, to tier: String) {
        let next = TLTierLogic.moveContestant(tiers, contestantId: id, targetTierName: tier)
        guard next != tiers else { return }
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
    }

    func clearTier(_ tier: String) {
        var next = tiers
        guard let moving = next[tier], !moving.isEmpty else { return }
        next[tier] = []
        next["unranked", default: []].append(contentsOf: moving)
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
    }

    func undo() { guard TLHistoryLogic.canUndo(history) else { return }; history = TLHistoryLogic.undo(history); tiers = TLHistoryLogic.current(history) }
    func redo() { guard TLHistoryLogic.canRedo(history) else { return }; history = TLHistoryLogic.redo(history); tiers = TLHistoryLogic.current(history) }
    var canUndo: Bool { TLHistoryLogic.canUndo(history) }
    var canRedo: Bool { TLHistoryLogic.canRedo(history) }

    func reset() {
        tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
        seed()
        history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
    }

    @discardableResult
    func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(tiers)
            UserDefaults.standard.set(data, forKey: storageKey)
            return true
        } catch {
            print("Save failed: \(error)")
            return false
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return false }
        do {
            let decoded = try JSONDecoder().decode(TLTiers.self, from: data)
            tiers = decoded
            history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
            return true
        } catch {
            print("Load failed: \(error)")
            return false
        }
    }

    func exportText(group: String = "All", themeName: String = "Default") -> String {
        let cfg: TLTierConfig = [
            "S": (name: "S", description: nil),
            "A": (name: "A", description: nil),
            "B": (name: "B", description: nil),
            "C": (name: "C", description: nil),
            "D": (name: "D", description: nil),
            "F": (name: "F", description: nil)
        ]
        return TLExportFormatter.generate(group: group, date: .now, themeName: themeName, tiers: tiers, tierConfig: cfg)
    }

    // MARK: - Quick Rank
    func beginQuickRank(_ contestant: TLContestant) { quickRankTarget = contestant }
    func cancelQuickRank() { quickRankTarget = nil }
    func commitQuickRank(to tier: String) {
        guard let c = quickRankTarget else { return }
        let next = TLQuickRankLogic.assign(tiers, contestantId: c.id, to: tier)
        guard next != tiers else { quickRankTarget = nil; return }
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        quickRankTarget = nil
    }

    // MARK: - Head to Head
    func startH2H() {
        let pool = (tiers["unranked"] ?? []) + tierOrder.flatMap { tiers[$0] ?? [] }
        h2hPool = pool
        h2hRecords = [:]
        h2hActive = true
        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }
        if let pair = TLHeadToHeadLogic.pickPair(from: h2hPool, rng: { Double.random(in: 0...1) }) {
            h2hPair = (pair.0, pair.1)
        } else {
            h2hPair = nil
        }
    }

    func voteH2H(winner: TLContestant) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0, b = pair.1
        TLHeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        nextH2HPair()
    }

    func finishH2H() {
        guard h2hActive else { return }
        // build ranking using current pool and records
        let ranking = TLHeadToHeadLogic.ranking(from: h2hPool, records: h2hRecords)
        let distributed = TLHeadToHeadLogic.distributeRoundRobin(ranking, into: tierOrder, baseTiers: tiers)
        tiers = distributed
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        h2hActive = false
        h2hPair = nil
        h2hPool = []
        h2hRecords = [:]
    }
}
