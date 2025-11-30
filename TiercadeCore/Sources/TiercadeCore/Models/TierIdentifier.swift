import Foundation

// MARK: - TierIdentifier

/// Type-safe tier identifier with string-based backward compatibility
///
/// This enum provides compile-time safety for tier operations while maintaining
/// backward compatibility with string-based APIs through RawRepresentable.
///
/// Example usage:
/// ```swift
/// // Type-safe access
/// let items = tiers[.s]
///
/// // String fallback for dynamic keys
/// let items = tiers[TierIdentifier(rawValue: tierKey)]
/// ```
public enum TierIdentifier: String, Codable, Sendable, CaseIterable, Hashable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    case unranked

    // MARK: Public

    /// All standard tier keys in sort order
    public static var standardOrder: [TierIdentifier] {
        allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// All ranked tiers (excluding unranked)
    public static var rankedTiers: [TierIdentifier] {
        allCases.filter(\.isRanked)
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .unranked:
            "Unranked"
        default:
            rawValue
        }
    }

    /// Sort order for display (S at top, unranked at bottom)
    public var sortOrder: Int {
        switch self {
        case .s: 0
        case .a: 1
        case .b: 2
        case .c: 3
        case .d: 4
        case .f: 5
        case .unranked: 6
        }
    }

    /// Default color for tier (if not overridden by TierConfig)
    public var defaultColorHex: String {
        switch self {
        case .s: "#FF4444"
        case .a: "#FF8C00"
        case .b: "#FFD700"
        case .c: "#90EE90"
        case .d: "#87CEEB"
        case .f: "#DDA0DD"
        case .unranked: "#888888"
        }
    }

    /// Check if this is a ranked tier (not unranked)
    public var isRanked: Bool {
        self != .unranked
    }

}

// MARK: - Backward Compatibility Extensions

/// Typed Items collection using TierIdentifier keys
public typealias TypedItems = [TierIdentifier: [Item]]

extension [String: [Item]] {
    /// Convert string-keyed Items to type-safe TypedItems
    public func toTyped() -> TypedItems {
        var typed: TypedItems = [:]
        for (key, value) in self {
            if let tier = TierIdentifier(rawValue: key) {
                typed[tier] = value
            } else {
                // Preserve unknown keys by mapping to closest match or unranked
                typed[.unranked, default: []].append(contentsOf: value)
            }
        }
        return typed
    }

    /// Access items using TierIdentifier (convenience)
    public subscript(tier: TierIdentifier) -> Value? {
        get { self[tier.rawValue] }
        set { self[tier.rawValue] = newValue }
    }
}

extension [TierIdentifier: [Item]] {
    /// Convert type-safe TypedItems to string-keyed Items
    public func toStringKeyed() -> Items {
        var items: Items = [:]
        for (tier, itemList) in self {
            items[tier.rawValue] = itemList
        }
        return items
    }
}

// MARK: - TierIdentifier + Comparable

extension TierIdentifier: Comparable {
    public static func < (lhs: TierIdentifier, rhs: TierIdentifier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - TierIdentifier + CustomStringConvertible

extension TierIdentifier: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

// MARK: - TierIdentifier + ExpressibleByStringLiteral

extension TierIdentifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = TierIdentifier(rawValue: value) ?? .unranked
    }
}
