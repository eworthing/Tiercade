import Foundation
import Testing
@testable import TiercadeCore

@Suite("TierLogic")
struct TierLogicTests {
    @Test("Move item between tiers updates source and target")
    func moveItemBetweenTiers() {
        let tiers = makeSampleTiers()
        let moved = TierLogic.moveItem(tiers, itemId: "beta", targetTierName: "S")

        #expect(moved["A"]?.map(\.id) == ["alpha"])
        #expect(moved["S"]?.contains(where: { $0.id == "beta" }) == true)
        #expect(moved["S"]?.count == 2)
    }

    @Test("Moving within same tier is a no-op")
    func moveItemSameTierNoOp() {
        let tiers = makeSampleTiers()
        let moved = TierLogic.moveItem(tiers, itemId: "alpha", targetTierName: "A")
        #expect(moved == tiers)
    }

    @Test("Reorder within tier shifts items to the specified index")
    func reorderWithinTier() {
        var tiers = makeSampleTiers()
        tiers["S"] = [
            makeItem("s1", name: "First"),
            makeItem("s2", name: "Second"),
            makeItem("s3", name: "Third")
        ]

        let reordered = TierLogic.reorderWithin(tiers, tierName: "S", from: 0, to: 2)
        #expect(reordered["S"]?.map(\.id) == ["s2", "s3", "s1"])
    }

    @Test("Reorder ignores out-of-bounds input")
    func reorderOutOfBoundsNoOp() {
        let tiers = makeSampleTiers()
        let reordered = TierLogic.reorderWithin(tiers, tierName: "S", from: 1, to: 5)
        #expect(reordered == tiers)
    }
}

private extension TierLogicTests {
    func makeSampleTiers() -> Items {
        [
            "S": [makeItem("sigma", name: "Sigma")],
            "A": [
                makeItem("alpha", name: "Alpha"),
                makeItem("beta", name: "Beta")
            ],
            "unranked": [makeItem("omega", name: "Omega")]
        ]
    }

    func makeItem(_ id: String, name: String) -> Item {
        Item(id: id, name: name)
    }
}
