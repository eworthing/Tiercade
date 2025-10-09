import Testing
@testable import TiercadeCore

struct HeadToHeadTieringTests {
    @Test
    func quickPassPlacesUndersampledIntoUnranked() {
        let items = [
            Item(id: "alpha", name: "Alpha"),
            Item(id: "bravo", name: "Bravo"),
            Item(id: "charlie", name: "Charlie")
        ]
        let records: [String: H2HRecord] = [
            "alpha": H2HRecord(wins: 3, losses: 0),
            "bravo": H2HRecord(wins: 2, losses: 1),
            "charlie": H2HRecord(wins: 1, losses: 0) // undersampled (<3)
        ]
        let base: Items = ["S": [], "A": [], "B": [], "unranked": []]

        let result = HeadToHeadLogic.quickTierPass(
            from: items,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        #expect(result.tiers["unranked"]?.map { $0.id } == ["charlie"])
        #expect(result.tiers["S"]?.contains(where: { $0.id == "alpha" }) == true)
        #expect(result.tiers["A"]?.contains(where: { $0.id == "bravo" }) == true)
    }

    @Test
    func finalizeUsesNaturalBreaksWhenDataSupportsThem() {
        let items = (1...6).map { idx in Item(id: "item-\(idx)", name: "Item \(idx)") }
        let winRates: [Double] = [0.95, 0.90, 0.74, 0.73, 0.72, 0.55]
        let records = Dictionary(uniqueKeysWithValues: zip(items, winRates).map { pair in
            let wins = Int((pair.1 * 20.0).rounded())
            let losses = max(0, 20 - wins)
            return (pair.0.id, H2HRecord(wins: wins, losses: losses))
        })
        let base: Items = ["S": [], "A": [], "B": []]

        let quick = HeadToHeadLogic.quickTierPass(
            from: items,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        #expect(quick.artifacts != nil)

        let (rebuilt, _) = HeadToHeadLogic.finalizeTiers(
            artifacts: quick.artifacts!,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        let sTier = rebuilt["S"]?.map { $0.id } ?? []
        let aTier = rebuilt["A"]?.map { $0.id } ?? []
        let bTier = rebuilt["B"]?.map { $0.id } ?? []

        #expect(sTier.count == 2)
        #expect(aTier.count == 3)
        #expect(bTier.count == 1)
        #expect(sTier == ["item-1", "item-2"])
        #expect(bTier == ["item-6"])
    }

    @Test
    func finalizeFallsBackToQuantilesForFlatData() {
        let items = (1...6).map { idx in Item(id: "flat-\(idx)", name: "Flat \(idx)") }
        let records = Dictionary(uniqueKeysWithValues: items.map { item in
            (item.id, H2HRecord(wins: 3, losses: 3))
        })
        let base: Items = ["S": [], "A": [], "B": []]

        let quick = HeadToHeadLogic.quickTierPass(
            from: items,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        let (rebuilt, _) = HeadToHeadLogic.finalizeTiers(
            artifacts: quick.artifacts!,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        let counts = [
            rebuilt["S"]?.count ?? 0,
            rebuilt["A"]?.count ?? 0,
            rebuilt["B"]?.count ?? 0
        ]
        let maxDifference = (counts.max() ?? 0) - (counts.min() ?? 0)
        #expect(maxDifference <= 1)
    }

    @Test
    func refinementPairsPreferHighConfidenceBoundary() {
        let upperHigh = Item(id: "upper-high", name: "Upper High")
        let upperLow = Item(id: "upper-low", name: "Upper Low")
        let lowerHigh = Item(id: "lower-high", name: "Lower High")
        let lowerLow = Item(id: "lower-low", name: "Lower Low")
        let pool = [upperHigh, upperLow, lowerHigh, lowerLow]

        let records: [String: H2HRecord] = [
            upperHigh.id: H2HRecord(wins: 33, losses: 27),  // 60 comparisons, tight interval
            upperLow.id: H2HRecord(wins: 8, losses: 2),      // 10 comparisons, wide interval
            lowerHigh.id: H2HRecord(wins: 27, losses: 33),
            lowerLow.id: H2HRecord(wins: 2, losses: 8)
        ]

        let base: Items = ["S": [], "A": []]
        let quick = HeadToHeadLogic.quickTierPass(
            from: pool,
            records: records,
            tierOrder: ["S", "A"],
            baseTiers: base
        )

        #expect(quick.artifacts != nil)
        let artifacts = quick.artifacts!

        let pairs = HeadToHeadLogic.refinementPairs(
            artifacts: artifacts,
            records: records,
            limit: 2
        )

        #expect(!pairs.isEmpty)
        let first = pairs.first
        #expect(first?.0.id == upperHigh.id)
        #expect(first?.1.id == lowerHigh.id)
    }
}
