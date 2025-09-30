// Models.swift - Swift 6 Codable models for TierList schema
import Foundation

public enum JSONValue: Codable, Equatable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown JSON value")
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }
}

public struct Audit: Codable, Equatable {
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: String?
    public var updatedBy: String?
}

public struct Media: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable { case image, gif, video, audio }
    public var id: String
    public var kind: Kind
    public var uri: String
    public var mime: String
    public var w: Double?
    public var h: Double?
    public var durationMs: Double?
    public var posterUri: String?
    public var thumbUri: String?
    public var alt: String?
    public var attribution: [String: String]?
    public var additional: [String: JSONValue]?
}

public struct Item: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var summary: String?
    public var slug: String?
    public var media: [Media]?
    public var attributes: [String: JSONValue]?
    public var tags: [String]?
    public var rating: Double?
    public var sources: [[String: String]]?
    public var locale: [String: [String: String]]?
    public var meta: Audit?
    public var additional: [String: JSONValue]?
}

public struct ItemOverride: Codable, Equatable {
    public var displayTitle: String?
    public var notes: String?
    public var tags: [String]?
    public var rating: Double?
    public var media: [Media]?
    public var hidden: Bool?
    public var additional: [String: JSONValue]?
}

public struct Tier: Codable, Equatable, Identifiable {
    public var id: String
    public var label: String
    public var color: String?
    public var order: Int
    public var locked: Bool?
    public var collapsed: Bool?
    public var rules: [String: JSONValue]?
    public var itemIds: [String]
    public var additional: [String: JSONValue]?
}

public struct Links: Codable, Equatable { public var visibility: String?; public var shareUrl: String?; public var embedHtml: String?; public var stateUrl: String?; public var additional: [String: JSONValue]? }

public struct Settings: Codable, Equatable {
    public var theme: String?
    public var tierSortOrder: String?
    public var gridSnap: Bool?
    public var showUnranked: Bool?
    public var accessibility: [String: Bool]?
    public var additional: [String: JSONValue]?
}

public struct Member: Codable, Equatable { public var userId: String; public var role: String?; public var additional: [String: JSONValue]? }
public struct Collaboration: Codable, Equatable { public var members: [Member]?; public var additional: [String: JSONValue]? }

public struct Project: Codable, Equatable {
    public var schemaVersion: Int
    public var projectId: String
    public var title: String?
    public var description: String?
    public var tiers: [Tier]
    public var items: [String: Item]
    public var overrides: [String: ItemOverride]?
    public var links: Links?
    public var settings: Settings?
    public var collab: Collaboration?
    public var audit: Audit
    public var additional: [String: JSONValue]?
}
