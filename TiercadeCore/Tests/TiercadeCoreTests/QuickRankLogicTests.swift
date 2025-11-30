import Foundation
import Testing
@testable import TiercadeCore

// MARK: - QuickRankLogicTests

@Suite("QuickRankLogic")
struct QuickRankLogicTests {
    @Test("Assign moves item into desired tier")
    func assignMovesItem() {
        let tiers = makeSampleTiers()
        let updated = QuickRankLogic.assign(tiers, itemId: "beta", to: "S")

        #expect(updated["S"]?.map(\.id) == ["sigma", "beta"])
        #expect(updated["A"]?.map(\.id) == ["alpha"])
    }

    @Test("Assign with missing item is a no-op")
    func assignMissingItemNoOp() {
        let tiers = makeSampleTiers()
        let updated = QuickRankLogic.assign(tiers, itemId: "missing", to: "S")
        #expect(updated == tiers)
    }

    @Test("Assigning to current tier returns original tiers")
    func assignSameTierNoOp() {
        let tiers = makeSampleTiers()
        let updated = QuickRankLogic.assign(tiers, itemId: "alpha", to: "A")
        #expect(updated == tiers)
    }
}

extension QuickRankLogicTests {
    private func makeSampleTiers() -> Items {
        [
            "S": [Item(id: "sigma", name: "Sigma")],
            "A": [
                Item(id: "alpha", name: "Alpha"),
                Item(id: "beta", name: "Beta"),
            ],
            "unranked": [],
        ]
    }
}
