//
//  TierIdentifierTests.swift
//  TiercadeCore Tests
//
//  Created by AI Assistant on 9/30/25.
//

import XCTest
@testable import TiercadeCore

final class TierIdentifierTests: XCTestCase {

    // MARK: - Basic Enum Tests

    func testRawValues() {
        XCTAssertEqual(TierIdentifier.s.rawValue, "S")
        XCTAssertEqual(TierIdentifier.a.rawValue, "A")
        XCTAssertEqual(TierIdentifier.b.rawValue, "B")
        XCTAssertEqual(TierIdentifier.c.rawValue, "C")
        XCTAssertEqual(TierIdentifier.d.rawValue, "D")
        XCTAssertEqual(TierIdentifier.f.rawValue, "F")
        XCTAssertEqual(TierIdentifier.unranked.rawValue, "unranked")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(TierIdentifier(rawValue: "S"), .s)
        XCTAssertEqual(TierIdentifier(rawValue: "A"), .a)
        XCTAssertEqual(TierIdentifier(rawValue: "unranked"), .unranked)
        XCTAssertNil(TierIdentifier(rawValue: "invalid"))
    }

    func testDisplayNames() {
        XCTAssertEqual(TierIdentifier.s.displayName, "S")
        XCTAssertEqual(TierIdentifier.unranked.displayName, "Unranked")
    }

    // MARK: - Sort Order Tests

    func testSortOrder() {
        XCTAssertEqual(TierIdentifier.s.sortOrder, 0)
        XCTAssertEqual(TierIdentifier.a.sortOrder, 1)
        XCTAssertEqual(TierIdentifier.unranked.sortOrder, 6)
    }

    func testComparable() {
        XCTAssertTrue(TierIdentifier.s < .a)
        XCTAssertTrue(TierIdentifier.a < .b)
        XCTAssertTrue(TierIdentifier.f < .unranked)
    }

    func testStandardOrder() {
        let ordered = TierIdentifier.standardOrder
        XCTAssertEqual(ordered.first, .s)
        XCTAssertEqual(ordered.last, .unranked)
        XCTAssertEqual(ordered.count, 7)

        // Verify strictly increasing sort order
        for i in 0..<ordered.count - 1 {
            XCTAssertTrue(ordered[i] < ordered[i + 1])
        }
    }

    func testRankedTiers() {
        let ranked = TierIdentifier.rankedTiers
        XCTAssertEqual(ranked.count, 6)
        XCTAssertFalse(ranked.contains(.unranked))
        XCTAssertTrue(ranked.contains(.s))
        XCTAssertTrue(ranked.contains(.f))
    }

    // MARK: - Color Tests

    func testDefaultColors() {
        XCTAssertEqual(TierIdentifier.s.defaultColorHex, "#FF4444")
        XCTAssertEqual(TierIdentifier.unranked.defaultColorHex, "#888888")

        // All tiers should have valid hex colors
        for tier in TierIdentifier.allCases {
            XCTAssertTrue(tier.defaultColorHex.hasPrefix("#"))
            XCTAssertEqual(tier.defaultColorHex.count, 7) // #RRGGBB
        }
    }

    // MARK: - Utility Tests

    func testIsRanked() {
        XCTAssertTrue(TierIdentifier.s.isRanked)
        XCTAssertTrue(TierIdentifier.a.isRanked)
        XCTAssertFalse(TierIdentifier.unranked.isRanked)
    }

    func testCustomStringConvertible() {
        XCTAssertEqual(String(describing: TierIdentifier.s), "S")
        XCTAssertEqual(String(describing: TierIdentifier.unranked), "Unranked")
    }

    func testExpressibleByStringLiteral() {
        let tier: TierIdentifier = "S"
        XCTAssertEqual(tier, .s)

        let invalid: TierIdentifier = "invalid"
        XCTAssertEqual(invalid, .unranked) // Falls back to unranked
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let tier = TierIdentifier.s
        let encoder = JSONEncoder()
        let data = try encoder.encode(tier)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TierIdentifier.self, from: data)

        XCTAssertEqual(tier, decoded)
    }

    func testEncodeArray() throws {
        let tiers = TierIdentifier.allCases
        let encoder = JSONEncoder()
        let data = try encoder.encode(tiers)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([TierIdentifier].self, from: data)

        XCTAssertEqual(tiers, decoded)
    }

    // MARK: - Backward Compatibility Tests

    func testStringKeyedDictionaryAccess() {
        var items: Items = ["S": [Item(id: "test1")], "A": [Item(id: "test2")]]

        // Access using TierIdentifier
        XCTAssertEqual(items[.s]?.first?.id, "test1")
        XCTAssertEqual(items[.a]?.first?.id, "test2")
        XCTAssertNil(items[.b])

        // Modify using TierIdentifier
        items[.b] = [Item(id: "test3")]
        XCTAssertEqual(items["B"]?.first?.id, "test3")
    }

    func testToTypedConversion() {
        let stringItems: Items = [
            "S": [Item(id: "s1"), Item(id: "s2")],
            "A": [Item(id: "a1")],
            "unranked": [Item(id: "u1")]
        ]

        let typed = stringItems.toTyped()

        XCTAssertEqual(typed[.s]?.count, 2)
        XCTAssertEqual(typed[.a]?.count, 1)
        XCTAssertEqual(typed[.unranked]?.count, 1)
        XCTAssertNil(typed[.b])
    }

    func testToStringKeyedConversion() {
        let typedItems: TypedItems = [
            .s: [Item(id: "s1")],
            .a: [Item(id: "a1")],
            .unranked: [Item(id: "u1")]
        ]

        let stringKeyed = typedItems.toStringKeyed()

        XCTAssertEqual(stringKeyed["S"]?.first?.id, "s1")
        XCTAssertEqual(stringKeyed["A"]?.first?.id, "a1")
        XCTAssertEqual(stringKeyed["unranked"]?.first?.id, "u1")
    }

    func testRoundTripConversion() {
        let original: Items = [
            "S": [Item(id: "s1")],
            "A": [Item(id: "a1")],
            "B": [Item(id: "b1")],
            "unranked": [Item(id: "u1")]
        ]

        let typed = original.toTyped()
        let backToString = typed.toStringKeyed()

        // Should preserve all data
        XCTAssertEqual(original.keys.sorted(), backToString.keys.sorted())
        for key in original.keys {
            XCTAssertEqual(original[key]?.count, backToString[key]?.count)
        }
    }

    func testUnknownKeysMapToUnranked() {
        let stringItems: Items = [
            "S": [Item(id: "s1")],
            "unknown1": [Item(id: "u1")],
            "unknown2": [Item(id: "u2")]
        ]

        let typed = stringItems.toTyped()

        XCTAssertEqual(typed[.s]?.count, 1)
        // Unknown keys should merge into unranked
        XCTAssertEqual(typed[.unranked]?.count, 2)
    }

    // MARK: - CaseIterable Tests

    func testCaseIterable() {
        let allCases = TierIdentifier.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.s))
        XCTAssertTrue(allCases.contains(.unranked))
    }

    // MARK: - Hashable Tests

    func testHashable() {
        var set: Set<TierIdentifier> = []
        set.insert(.s)
        set.insert(.a)
        set.insert(.s) // Duplicate

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(.s))
        XCTAssertTrue(set.contains(.a))
    }

    func testHashableInDictionary() {
        let dict: [TierIdentifier: String] = [
            .s: "Top tier",
            .a: "High tier",
            .unranked: "Not ranked"
        ]

        XCTAssertEqual(dict[.s], "Top tier")
        XCTAssertEqual(dict[.unranked], "Not ranked")
    }
}
