import Foundation

public struct H2HItem: Hashable, Sendable {
    public let item: Item
    public init(_ c: Item) { self.item = c }
}

public struct H2HRecord: Sendable {
    public var wins: Int = 0
    public var losses: Int = 0
    public var total: Int { wins + losses }
    public var winRate: Double { total == 0 ? 0 : Double(wins) / Double(total) }
}

public struct H2HRankingEntry: Sendable { public let item: Item; public let winRate: Double }

public enum HeadToHeadLogic {
    /// Pick a distinct pair from pool using provided rng; returns nil if <2.
    public static func pickPair(from pool: [Item], rng: () -> Double) -> (Item, Item)? {
        RandomUtils.pickRandomPair(pool, rng: rng)
    }

    /// Generate every unique unordered pairing from the pool and randomize the order.
    public static func pairings(from pool: [Item], rng: () -> Double) -> [(Item, Item)] {
        guard pool.count >= 2 else { return [] }
        var combinations: [(Item, Item)] = []
        combinations.reserveCapacity(pool.count * (pool.count - 1) / 2)
        for i in 0..<(pool.count - 1) {
            let left = pool[i]
            for j in (i + 1)..<pool.count {
                combinations.append((left, pool[j]))
            }
        }

        guard combinations.count > 1 else { return combinations }

        // Fisher–Yates shuffle using supplied RNG for deterministic testing when needed.
        var shuffled = combinations
        var idx = shuffled.count - 1
        while idx > 0 {
            let random = Int(floor(rng() * Double(idx + 1)))
            shuffled.swapAt(idx, random)
            idx -= 1
        }
        return shuffled
    }

    /// Apply a vote outcome to the records dictionary.
    public static func vote(_ a: Item, _ b: Item, winner: Item, records: inout [String: H2HRecord]) {
        if winner.id == a.id {
            records[a.id, default: .init()].wins += 1
            records[b.id, default: .init()].losses += 1
        } else {
            records[b.id, default: .init()].wins += 1
            records[a.id, default: .init()].losses += 1
        }
    }

    /// Compute ranking by win rate, descending; ties by total desc, then name asc.
    public static func ranking(from pool: [Item], records: [String: H2HRecord]) -> [H2HRankingEntry] {
        let entries = pool.map { c -> H2HRankingEntry in
            let r = records[c.id] ?? H2HRecord()
            return H2HRankingEntry(item: c, winRate: r.winRate)
        }
        return entries.sorted { l, r in
            if l.winRate != r.winRate { return l.winRate > r.winRate }
            // Optional: future tie-break by totals; here we only have winRate stored
            let ln = l.item.name ?? l.item.id
            let rn = r.item.name ?? r.item.id
            return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
        }
    }

    /// Distribute ranked items into ordered tier names in a round-robin pattern.
    public static func distributeRoundRobin(
        _ ranking: [H2HRankingEntry],
        into tierOrder: [String],
        baseTiers: Items
    ) -> Items {
        var newTiers = baseTiers
        for name in tierOrder where newTiers[name] == nil {
            newTiers[name] = []
        }
        // remove any ranked item from unranked
        if var unranked = newTiers["unranked"] {
            let ids = Set(ranking.map { $0.item.id })
            unranked.removeAll { ids.contains($0.id) }
            newTiers["unranked"] = unranked
        }
        for (i, entry) in ranking.enumerated() {
            let target = tierOrder[i % max(1, tierOrder.count)]
            newTiers[target, default: []].append(entry.item)
        }
        return newTiers
    }
}
