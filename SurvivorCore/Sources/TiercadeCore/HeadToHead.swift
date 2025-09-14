import Foundation

public struct H2HContestant: Hashable, Sendable {
    public let contestant: Contestant
    public init(_ c: Contestant) { self.contestant = c }
}

public struct H2HRecord: Sendable {
    public var wins: Int = 0
    public var losses: Int = 0
    public var total: Int { wins + losses }
    public var winRate: Double { total == 0 ? 0 : Double(wins) / Double(total) }
}

public struct H2HRankingEntry: Sendable { public let contestant: Contestant; public let winRate: Double }

public enum HeadToHeadLogic {
    /// Pick a distinct pair from pool using provided rng; returns nil if <2.
    public static func pickPair(from pool: [Contestant], rng: () -> Double) -> (Contestant, Contestant)? {
        RandomUtils.pickRandomPair(pool, rng: rng)
    }

    /// Apply a vote outcome to the records dictionary.
    public static func vote(_ a: Contestant, _ b: Contestant, winner: Contestant, records: inout [String: H2HRecord]) {
        if winner.id == a.id {
            records[a.id, default: .init()].wins += 1
            records[b.id, default: .init()].losses += 1
        } else {
            records[b.id, default: .init()].wins += 1
            records[a.id, default: .init()].losses += 1
        }
    }

    /// Compute ranking by win rate, descending; ties by total desc, then name asc.
    public static func ranking(from pool: [Contestant], records: [String: H2HRecord]) -> [H2HRankingEntry] {
        let entries = pool.map { c -> H2HRankingEntry in
            let r = records[c.id] ?? H2HRecord()
            return H2HRankingEntry(contestant: c, winRate: r.winRate)
        }
        return entries.sorted { l, r in
            if l.winRate != r.winRate { return l.winRate > r.winRate }
            // Optional: future tie-break by totals; here we only have winRate stored
            let ln = l.contestant.name ?? l.contestant.id
            let rn = r.contestant.name ?? r.contestant.id
            return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
        }
    }

    /// Distribute ranked contestants into ordered tier names in a round-robin pattern.
    public static func distributeRoundRobin(_ ranking: [H2HRankingEntry], into tierOrder: [String], baseTiers: Tiers) -> Tiers {
        var newTiers = baseTiers
        for name in tierOrder { if newTiers[name] == nil { newTiers[name] = [] } }
        // remove any ranked contestant from unranked
        if var unranked = newTiers["unranked"] {
            let ids = Set(ranking.map { $0.contestant.id })
            unranked.removeAll { ids.contains($0.id) }
            newTiers["unranked"] = unranked
        }
        for (i, entry) in ranking.enumerated() {
            let target = tierOrder[i % max(1, tierOrder.count)]
            newTiers[target, default: []].append(entry.contestant)
        }
        return newTiers
    }
}
