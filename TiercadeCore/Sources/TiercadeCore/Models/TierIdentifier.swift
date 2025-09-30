//
//  TierIdentifier.swift
//  TiercadeCore
//
//  Created by AI Assistant on 9/30/25.
//  Type-safe tier identification system with backward compatibility
//

import Foundation

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
    case unranked = "unranked"
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .unranked:
            return "Unranked"
        default:
            return rawValue
        }
    }
    
    /// Sort order for display (S at top, unranked at bottom)
    public var sortOrder: Int {
        switch self {
        case .s: return 0
        case .a: return 1
        case .b: return 2
        case .c: return 3
        case .d: return 4
        case .f: return 5
        case .unranked: return 6
        }
    }
    
    /// Default color for tier (if not overridden by TierConfig)
    public var defaultColorHex: String {
        switch self {
        case .s: return "#FF4444"
        case .a: return "#FF8C00"
        case .b: return "#FFD700"
        case .c: return "#90EE90"
        case .d: return "#87CEEB"
        case .f: return "#DDA0DD"
        case .unranked: return "#888888"
        }
    }
    
    /// Check if this is a ranked tier (not unranked)
    public var isRanked: Bool {
        self != .unranked
    }
    
    /// All standard tier keys in sort order
    public static var standardOrder: [TierIdentifier] {
        allCases.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// All ranked tiers (excluding unranked)
    public static var rankedTiers: [TierIdentifier] {
        allCases.filter { $0.isRanked }
    }
}

// MARK: - Backward Compatibility Extensions

/// Typed Items collection using TierIdentifier keys
public typealias TypedItems = [TierIdentifier: [Item]]

extension Dictionary where Key == String, Value == [Item] {
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

extension Dictionary where Key == TierIdentifier, Value == [Item] {
    /// Convert type-safe TypedItems to string-keyed Items
    public func toStringKeyed() -> Items {
        var items: Items = [:]
        for (tier, itemList) in self {
            items[tier.rawValue] = itemList
        }
        return items
    }
}

// MARK: - Comparable for Sorting

extension TierIdentifier: Comparable {
    public static func < (lhs: TierIdentifier, rhs: TierIdentifier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - CustomStringConvertible

extension TierIdentifier: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

// MARK: - ExpressibleByStringLiteral (for testing/migration)

extension TierIdentifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = TierIdentifier(rawValue: value) ?? .unranked
    }
}
