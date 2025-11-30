import Foundation
import Testing
@testable import TiercadeCore

@Suite("TierIdentifier")
struct TierIdentifierTests {
    @Test("Display metadata matches expectations")
    func displayProperties() {
        #expect(TierIdentifier.s.displayName == "S")
        #expect(TierIdentifier.unranked.displayName == "Unranked")
        #expect(TierIdentifier.s.sortOrder < TierIdentifier.a.sortOrder)
        #expect(TierIdentifier.s.defaultColorHex == "#FF4444")
        #expect(TierIdentifier.unranked.isRanked == false)
    }

    @Test("Standard order lists ranked tiers first")
    func standardOrderOrdering() {
        let order = TierIdentifier.standardOrder
        #expect(order.first == .s)
        #expect(order.last == .unranked)
        #expect(TierIdentifier.rankedTiers.allSatisfy { $0 != .unranked })
    }

    @Test("Dictionary conversion preserves known tiers and buckets unknown into unranked")
    func dictionaryConversion() {
        let sItem = Item(id: "alpha", name: "Alpha")
        let unknownItem = Item(id: "mystery", name: "Mystery")
        let items: Items = [
            "S": [sItem],
            "custom": [unknownItem],
        ]

        let typed = items.toTyped()
        #expect(typed[.s]?.first?.id == "alpha")
        #expect(typed[.unranked]?.first?.id == "mystery")

        let roundTrip = typed.toStringKeyed()
        #expect(roundTrip["S"]?.first?.id == "alpha")
        #expect(roundTrip["unranked"]?.first?.id == "mystery")
    }

    @Test("ExpressibleByStringLiteral defaults unknowns to unranked")
    func expressibleByStringLiteralFallback() {
        let tier: TierIdentifier = "C"
        #expect(tier == .c)

        let unknown: TierIdentifier = "Unknown"
        #expect(unknown == .unranked)
    }
}
