import Foundation

#if canImport(SurvivorCore)
import SurvivorCore
public typealias TLContestant = SurvivorCore.Contestant
public typealias TLTiers = SurvivorCore.Tiers
public typealias TLTierConfig = SurvivorCore.TierConfig
public typealias TLHistory<T> = SurvivorCore.History<T>
public typealias TLHistoryLogic = SurvivorCore.HistoryLogic
public typealias TLTierLogic = SurvivorCore.TierLogic
public typealias TLExportFormatter = SurvivorCore.ExportFormatter
public typealias TLAnalysisFormatter = SurvivorCore.AnalysisFormatter
public typealias TLDataLoader = SurvivorCore.DataLoader
public typealias TLQuickRankLogic = SurvivorCore.QuickRankLogic
public typealias TLHeadToHeadLogic = SurvivorCore.HeadToHeadLogic
public typealias TLH2HRankingEntry = SurvivorCore.H2HRankingEntry
#else
public struct TLContestant: Identifiable, Hashable, Codable {
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
#endif
