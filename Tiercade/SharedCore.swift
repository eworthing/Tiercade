import Foundation
import SwiftUI

// Common UI support types (available regardless of core package presence)
// MARK: - Filter Types
public enum FilterType: String, CaseIterable {
    case all = "All"
    case ranked = "Ranked"
    case unranked = "Unranked"
}

// MARK: - Toast System

enum ToastType {
    case success
    case error
    case info
    case warning

    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval

    init(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
    }
}

// If TiercadeCore is available, use its canonical types. Otherwise provide local fallbacks
#if canImport(TiercadeCore)
import TiercadeCore

// Expose core names for app code
public typealias Item = TiercadeCore.Item
public typealias Items = TiercadeCore.Items
public typealias H2HRecord = TiercadeCore.H2HRecord
public typealias H2HRankingEntry = TiercadeCore.H2HRankingEntry
public typealias TierConfig = TiercadeCore.TierConfig

public typealias History<T> = TiercadeCore.History<T>
public typealias HistoryLogic = TiercadeCore.HistoryLogic
public typealias TierLogic = TiercadeCore.TierLogic
public typealias QuickRankLogic = TiercadeCore.QuickRankLogic
public typealias HeadToHeadLogic = TiercadeCore.HeadToHeadLogic
public typealias ExportFormatter = TiercadeCore.ExportFormatter

// Compatibility shims: the app still expects a few legacy accessors / types that
// were present on the local fallback. Provide lightweight adapters so we can
// switch to the canonical `TiercadeCore` package without changing `AppState`.

// Provide a small TierListSaveData type so AppState's save/load helpers keep working.
public struct TierListSaveData: Codable {
    public let tiers: Items
    public let createdDate: Date
    public let appVersion: String

    public init(tiers: Items, createdDate: Date, appVersion: String) {
        self.tiers = tiers
        self.createdDate = createdDate
        self.appVersion = appVersion
    }
}

// Extend the core Item to expose the legacy-style accessors used by AppState.
public extension Item {
    // Backwards-compatible attributes bag (computed)
    var attributes: [String: String]? {
        get {
            var dict: [String: String] = [:]
            if let n = name { dict["name"] = n }
            if let s = seasonString { dict["season"] = s }
            if let sn = seasonNumber { dict["seasonNumber"] = String(sn) }
            if let img = imageUrl { dict["imageUrl"] = img }
            if let v = videoUrl { dict["videoUrl"] = v }
            if let st = status { dict["status"] = st }
            if let d = description { dict["description"] = d }
            return dict.isEmpty ? nil : dict
        }
        set {
            guard let a = newValue else {
                name = nil
                seasonString = nil
                seasonNumber = nil
                imageUrl = nil
                videoUrl = nil
                status = nil
                description = nil
                return
            }
            name = a["name"] ?? name
            if let sn = a["seasonNumber"], let n = Int(sn) {
                seasonNumber = n
                seasonString = String(n)
            } else if let s = a["season"] {
                seasonString = s
                seasonNumber = Int(s)
            }
            imageUrl = a["thumbUri"] ?? a["imageUrl"] ?? imageUrl
            videoUrl = a["videoUrl"] ?? videoUrl
            status = a["status"] ?? status
            description = a["description"] ?? description
        }
    }

    // Legacy-season property (string) used throughout the app
    var season: String? {
        get { seasonString }
        set { seasonString = newValue }
    }

    // Legacy thumbnail alias
    var thumbUri: String? {
        get { imageUrl }
        set { imageUrl = newValue }
    }
}

// Add a convenience initializer matching the fallback API so AppState's TierConfig
// construction site continues to compile.
// Note: TierConfigEntry's public initializer is provided by the core package when
// available. We intentionally avoid adding another initializer here to prevent
// initializer visibility and module-initialization conflicts.

#else

// Fallback definitions when TiercadeCore is not available
public struct TLItem: Identifiable, Hashable, Sendable {
    public let id: String
    /// Flexible attributes bag to support arbitrary item types. Common keys: "name", "season", "thumbUri".
    public var attributes: [String: String]?

    public init(id: String, attributes: [String: String]?) {
        self.id = id
        self.attributes = attributes
    }

    // Generic accessor helpers
    public var name: String? {
        get { attributes?["name"] }
        set {
            if attributes == nil { attributes = [:] }
            attributes?["name"] = newValue
        }
    }

    public var season: String? {
        get { attributes?["season"] }
        set {
            if attributes == nil { attributes = [:] }
            attributes?["season"] = newValue
        }
    }

    public var thumbUri: String? {
        get { attributes?["thumbUri"] }
        set {
            if attributes == nil { attributes = [:] }
            attributes?["thumbUri"] = newValue
        }
    }

    // Compatibility accessors for older code that expects imageUrl/videoUrl
    public var imageUrl: String? {
        get { attributes?["imageUrl"] ?? attributes?["thumbUri"] }
        set {
            if attributes == nil { attributes = [:] }
            attributes?["imageUrl"] = newValue
        }
    }

    public var videoUrl: String? {
        get { attributes?["videoUrl"] }
        set {
            if attributes == nil { attributes = [:] }
            attributes?["videoUrl"] = newValue
        }
    }

    // MARK: - Codable (attributes-only)
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }
}

extension TLItem: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(attributes, forKey: .attributes)
    }
}

// Add computed seasonString to TLItem for parity with core Item
extension TLItem {
    public var seasonString: String? {
        get { self.season }
        set { self.season = newValue }
    }
}

public typealias TLTiers = [String: [TLItem]]
public typealias TLTierConfig = [String: TLTierConfigEntry]

public struct TierListSaveData: Codable {
    public let tiers: TLTiers
    public let createdDate: Date
    public let appVersion: String

    public init(tiers: TLTiers, createdDate: Date, appVersion: String) {
        self.tiers = tiers
        self.createdDate = createdDate
        self.appVersion = appVersion
    }
}

public struct TLHistory<T> {
    public var stack: [T]
    public var index: Int
    public var limit: Int

    public init(stack: [T], index: Int, limit: Int) {
        self.stack = stack
        self.index = index
        self.limit = limit
    }
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

    // Add wrapper with core-compatible names to TLTierLogic
    public static func moveItem(_ tiers: TLTiers, itemId: String, targetTierName: String) -> TLTiers {
        moveContestant(tiers, contestantId: itemId, targetTierName: targetTierName)
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
        var s = "My Tier List - \(group)\n"
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

    // Add wrapper to TLQuickRankLogic to match core signature
    public static func assign(_ t: TLTiers, itemId: String, to tierName: String) -> TLTiers {
        assign(t, contestantId: itemId, to: tierName)
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

// Provide a TierConfigEntry fallback matching core's API
public struct TLTierConfigEntry: Codable, Sendable, Equatable {
    public var name: String
    public var colorHex: String?
    public var description: String?
    public init(name: String, colorHex: String? = nil, description: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.description = description
    }
}

// Map fallback names to canonical names so app code can use Item/Items etc.
public typealias Item = TLContestant
public typealias Items = TLTiers
public typealias H2HRecord = TLH2HRecord
public typealias H2HRankingEntry = TLH2HRankingEntry
public typealias TierConfig = TLTierConfig

public typealias History<T> = TLHistory<T>
public typealias HistoryLogic = TLHistoryLogic
public typealias TierLogic = TLTierLogic
public typealias QuickRankLogic = TLQuickRankLogic
public typealias HeadToHeadLogic = TLHeadToHeadLogic
public typealias ExportFormatter = TLExportFormatter
public typealias TierConfigEntry = TLTierConfigEntry
#endif
