import Foundation

#if canImport(TiercadeCore)
import TiercadeCore
import TiercadeCore
public typealias TLTierConfig = TiercadeCore.TierConfig
public typealias TLHistory<T> = TiercadeCore.History<T>
public typealias TLHistoryLogic = TiercadeCore.HistoryLogic
public typealias TLTierLogic = TiercadeCore.TierLogic
public typealias TLExportFormatter = TiercadeCore.ExportFormatter
public typealias TLAnalysisFormatter = TiercadeCore.AnalysisFormatter
public typealias TLDataLoader = TiercadeCore.DataLoader
public typealias TLQuickRankLogic = TiercadeCore.QuickRankLogic
public typealias TLHeadToHeadLogic = TiercadeCore.HeadToHeadLogic
public typealias TLH2HRankingEntry = TiercadeCore.H2HRankingEntry
#else
public struct TLContestant: Identifiable, Hashable, Codable, Sendable {
	public let id: String
	public var name: String?
	public var season: String?
}

public typealias TLTiers = [String: [TLContestant]]
public typealias TLTierConfig = [String: (name: String, description: String?)]

public struct TLHistory<T> {
	public var stack: [T]
	public var index: Int
	public var limit: Int
}

public enum TLHistoryLogic {
	public static func initHistory<T>(_ t: T, limit: Int = 50) -> TLHistory<T> {
		.init(stack: [t], index: 0, limit: limit)
	}

	public static func saveSnapshot<T>(_ h: TLHistory<T>, snapshot: T) -> TLHistory<T> {
		var s = Array(h.stack.prefix(h.index + 1))
		s.append(snapshot)
		let overflow = max(0, s.count - h.limit)
		let ns = overflow > 0 ? Array(s.suffix(h.limit)) : s
		return .init(stack: ns, index: ns.count - 1, limit: h.limit)
	}

	public static func canUndo<T>(_ h: TLHistory<T>) -> Bool { h.index > 0 }
	public static func canRedo<T>(_ h: TLHistory<T>) -> Bool { h.index < h.stack.count - 1 }

	public static func undo<T>(_ h: TLHistory<T>) -> TLHistory<T> {
		canUndo(h) ? .init(stack: h.stack, index: h.index - 1, limit: h.limit) : h
	}

	public static func redo<T>(_ h: TLHistory<T>) -> TLHistory<T> {
		canRedo(h) ? .init(stack: h.stack, index: h.index + 1, limit: h.limit) : h
	}

	public static func current<T>(_ h: TLHistory<T>) -> T { h.stack[h.index] }
}

public enum TLTierLogic {
	public static func moveContestant(
		_ tiers: TLTiers,
		contestantId: String,
		targetTierName: String
	) -> TLTiers {
		var nt = tiers
		var found: TLContestant?
		var src: String?

		for (k, v) in nt {
			if let i = v.firstIndex(where: { $0.id == contestantId }) {
				found = v[i]
				src = k
				var c = v
				c.remove(at: i)
				nt[k] = c
				break
			}
		}
		guard let f = found else { return tiers }
		if src == targetTierName { return tiers }
		var t = nt[targetTierName] ?? []
		t.append(f)
		nt[targetTierName] = t
		return nt
	}
}

public enum TLExportFormatter {
	public static func generate(
		group: String,
		date: Date,
		themeName: String,
		tiers: TLTiers,
		tierConfig: TLTierConfig
	) -> String {
		var s = "My Survivor Tier Ranking - \(group)\n"
		s += "Theme: \(themeName)\n\n"
		s += tiers
			.filter { $0.key != "unranked" }
			.compactMap { (k, v) in
				guard let cfg = tierConfig[k], !v.isEmpty else { return nil }
				return "\(cfg.name): \(v.map { $0.name ?? $0.id }.joined(separator: ", "))"
			}
			.joined(separator: "\n\n")
		return s
	}
}

public enum TLQuickRankLogic {
	public static func assign(_ t: TLTiers, contestantId: String, to tier: String) -> TLTiers {
		TLTierLogic.moveContestant(t, contestantId: contestantId, targetTierName: tier)
	}
}

public struct TLH2HRecord: Sendable, Codable { public var wins: Int = 0; public var losses: Int = 0 }
public struct TLH2HRankingEntry: Sendable, Codable { public let contestant: TLContestant; public let winRate: Double }
public enum TLHeadToHeadLogic {
	public static func pickPair(from pool: [TLContestant], rng: () -> Double) -> (TLContestant, TLContestant)? {
		guard pool.count >= 2 else { return nil }
		let i = Int(rng() * Double(pool.count)) % pool.count
		var j = Int(rng() * Double(pool.count)) % pool.count
		if j == i { j = (j + 1) % pool.count }
		return (pool[i], pool[j])
	}
	public static func vote(_ a: TLContestant, _ b: TLContestant, winner: TLContestant, records: inout [String: TLH2HRecord]) {
		if winner.id == a.id { records[a.id, default: .init()].wins += 1; records[b.id, default: .init()].losses += 1 }
		else { records[b.id, default: .init()].wins += 1; records[a.id, default: .init()].losses += 1 }
	}
	public static func ranking(from pool: [TLContestant], records: [String: TLH2HRecord]) -> [TLH2HRankingEntry] {
		pool.map { c in
			let r = records[c.id] ?? TLH2HRecord()
			let total = max(1, r.wins + r.losses)
			return TLH2HRankingEntry(contestant: c, winRate: Double(r.wins) / Double(total))
		}.sorted { l, r in
			if l.winRate != r.winRate { return l.winRate > r.winRate }
			let ln = l.contestant.name ?? l.contestant.id
			let rn = r.contestant.name ?? r.contestant.id
			return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
		}
	}
	public static func distributeRoundRobin(_ ranking: [TLH2HRankingEntry], into tierOrder: [String], baseTiers: TLTiers) -> TLTiers {
		var newTiers = baseTiers
		for name in tierOrder { if newTiers[name] == nil { newTiers[name] = [] } }
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
#endif
