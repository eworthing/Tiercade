import Foundation

/// Sorting utilities for tier items
public enum Sorting {

    // MARK: Public

    // MARK: - Sort Items

    /// Sort items according to the specified global sort mode
    /// - Parameters:
    ///   - items: Array of items to sort
    ///   - mode: The sort mode to apply
    /// - Returns: Sorted array (returns original if mode is .custom)
    public static func sortItems(_ items: [Item], by mode: GlobalSortMode) -> [Item] {
        switch mode {
        case .custom:
            // No-op: maintain current order
            items

        case let .alphabetical(ascending):
            items.sorted { lhs, rhs in
                let lhsName = lhs.name ?? lhs.id
                let rhsName = rhs.name ?? rhs.id
                let comparison = lhsName.localizedStandardCompare(rhsName)
                return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            }

        case let .byAttribute(key, ascending, type):
            sortByAttribute(items, key: key, ascending: ascending, type: type)
        }
    }

    // MARK: - Attribute Discovery

    /// Discover sortable attributes present in ≥70% of items across all tiers
    /// - Parameter allItems: Dictionary of tier names to item arrays
    /// - Returns: Dictionary of attribute key to inferred type
    public static func discoverSortableAttributes(in allItems: Items) -> [String: AttributeType] {
        // Flatten all items
        let flatItems = allItems.values.flatMap(\.self)
        guard !flatItems.isEmpty else {
            return [:]
        }

        let totalCount = flatItems.count
        let threshold = Int(ceil(Double(totalCount) * 0.7))

        var attributeCounts: [String: Int] = [:]
        var attributeTypes: [String: AttributeType] = [:]

        // Count occurrences of each attribute
        // NOTE: Exclude season-specific fields (seasonString, seasonNumber) to maintain
        // domain-agnostic design. Discovery focuses on universally applicable attributes.
        for item in flatItems {
            // Check known string attributes
            if item.name != nil {
                attributeCounts["name", default: 0] += 1
                attributeTypes["name"] = .string
            }
            if item.status != nil {
                attributeCounts["status", default: 0] += 1
                attributeTypes["status"] = .string
            }
            if item.description != nil {
                attributeCounts["description", default: 0] += 1
                attributeTypes["description"] = .string
            }
        }

        // Filter to attributes meeting threshold
        var result: [String: AttributeType] = [:]
        for (key, count) in attributeCounts where count >= threshold {
            if let type = attributeTypes[key] {
                result[key] = type
            }
        }

        return result
    }

    // MARK: Private

    // MARK: - Attribute Sorting

    private static func sortByAttribute(_ items: [Item], key: String, ascending: Bool, type: AttributeType) -> [Item] {
        items.sorted { lhs, rhs in
            let result: ComparisonResult = switch type {
            case .string:
                compareStringAttribute(lhs, rhs, key: key)
            case .number:
                compareNumberAttribute(lhs, rhs, key: key)
            case .bool:
                compareBoolAttribute(lhs, rhs, key: key)
            case .date:
                compareDateAttribute(lhs, rhs, key: key)
            }

            // Apply ascending/descending
            switch result {
            case .orderedAscending:
                return ascending
            case .orderedDescending:
                return !ascending
            case .orderedSame:
                // Stable tiebreaker: by name, then id
                let nameComp = (lhs.name ?? lhs.id).localizedStandardCompare(rhs.name ?? rhs.id)
                if nameComp != .orderedSame {
                    return nameComp == .orderedAscending
                }
                return lhs.id < rhs.id
            }
        }
    }

    private static func compareStringAttribute(_ lhs: Item, _ rhs: Item, key: String) -> ComparisonResult {
        let lhsVal = extractStringValue(from: lhs, key: key)
        let rhsVal = extractStringValue(from: rhs, key: key)

        // nil values sort last
        if lhsVal == nil, rhsVal == nil {
            return .orderedSame
        }
        if lhsVal == nil {
            return .orderedDescending
        }
        if rhsVal == nil {
            return .orderedAscending
        }

        return lhsVal!.localizedStandardCompare(rhsVal!)
    }

    private static func compareNumberAttribute(_ lhs: Item, _ rhs: Item, key: String) -> ComparisonResult {
        let lhsVal = extractNumberValue(from: lhs, key: key)
        let rhsVal = extractNumberValue(from: rhs, key: key)

        // nil values sort last
        if lhsVal == nil, rhsVal == nil {
            return .orderedSame
        }
        if lhsVal == nil {
            return .orderedDescending
        }
        if rhsVal == nil {
            return .orderedAscending
        }

        if lhsVal! < rhsVal! {
            return .orderedAscending
        }
        if lhsVal! > rhsVal! {
            return .orderedDescending
        }
        return .orderedSame
    }

    private static func compareBoolAttribute(_ lhs: Item, _ rhs: Item, key: String) -> ComparisonResult {
        let lhsVal = extractBoolValue(from: lhs, key: key)
        let rhsVal = extractBoolValue(from: rhs, key: key)

        // nil values sort last
        if lhsVal == nil, rhsVal == nil {
            return .orderedSame
        }
        if lhsVal == nil {
            return .orderedDescending
        }
        if rhsVal == nil {
            return .orderedAscending
        }

        // false < true
        if !lhsVal!, rhsVal! {
            return .orderedAscending
        }
        if lhsVal!, !rhsVal! {
            return .orderedDescending
        }
        return .orderedSame
    }

    private static func compareDateAttribute(_ lhs: Item, _ rhs: Item, key: String) -> ComparisonResult {
        let lhsVal = extractDateValue(from: lhs, key: key)
        let rhsVal = extractDateValue(from: rhs, key: key)

        // nil values sort last
        if lhsVal == nil, rhsVal == nil {
            return .orderedSame
        }
        if lhsVal == nil {
            return .orderedDescending
        }
        if rhsVal == nil {
            return .orderedAscending
        }

        if lhsVal! < rhsVal! {
            return .orderedAscending
        }
        if lhsVal! > rhsVal! {
            return .orderedDescending
        }
        return .orderedSame
    }

    // MARK: - Value Extraction

    private static func extractStringValue(from item: Item, key: String) -> String? {
        switch key {
        case "name": item.name
        case "seasonString": item.seasonString
        case "status": item.status
        case "description": item.description
        default: nil
        }
    }

    private static func extractNumberValue(from item: Item, key: String) -> Double? {
        switch key {
        case "seasonNumber": item.seasonNumber.map(Double.init)
        default: nil
        }
    }

    private static func extractBoolValue(from _: Item, key _: String) -> Bool? {
        // Currently Item doesn't have bool properties, but we support the pattern
        nil
    }

    private static func extractDateValue(from _: Item, key _: String) -> Date? {
        // Currently Item doesn't have date properties, but we support the pattern
        nil
    }

}
