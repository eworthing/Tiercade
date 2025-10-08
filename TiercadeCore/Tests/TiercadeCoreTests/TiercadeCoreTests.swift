import XCTest
@testable import TiercadeCore

final class TiercadeCoreTests: XCTestCase {
    func testDecodeAndValidate() throws {
        let itemsJSON = Data(
            """
            {"c1": {"id":"c1","name":"One","season": 1}, "c2": {"id":"c2","name":"Two","season":"2"}}
            """.utf8
        )
        let groupsJSON = """
        {"All": ["c1", "c2"]}
        """
        let groupsData = Data(groupsJSON.utf8)
        let loader = DataLoader()
        let items = try loader.decodeItems(from: itemsJSON)
        let groups = try loader.decodeGroups(from: groupsData)
        XCTAssertTrue(loader.validate(groups: groups, items: items))
            XCTAssertEqual(items["c1"]?.seasonNumber, 1)
            XCTAssertEqual(items["c2"]?.seasonString, "2")
    }

    func testHistory() {
        var h = HistoryLogic.initHistory([0])
        h = HistoryLogic.saveSnapshot(h, snapshot: [0, 1])
        XCTAssertTrue(HistoryLogic.canUndo(h))
        XCTAssertFalse(HistoryLogic.canRedo(h))
        let u = HistoryLogic.undo(h)
        XCTAssertFalse(HistoryLogic.canUndo(u))
    }

    func testQuickRankAssign() {
        let c = Item(id: "x", name: "X")
        let start: Items = ["S": [], "A": [], "unranked": [c]]
        let updated = QuickRankLogic.assign(start, itemId: "x", to: "S")
        XCTAssertEqual(updated["S"]?.first?.id, "x")
        XCTAssertEqual(updated["unranked"]?.isEmpty, true)
    }

    func testH2HTierRebuildPlacesBestIntoTopTier() {
        let a = Item(id: "a", name: "Alpha")
        let b = Item(id: "b", name: "Bravo")
        let c = Item(id: "c", name: "Charlie")
        let pool = [a, b, c]
        var records: [String: H2HRecord] = [:]
        var recordA = H2HRecord()
        recordA.wins = 3
        records[a.id] = recordA
        var recordB = H2HRecord()
        recordB.wins = 1
        recordB.losses = 2
        records[b.id] = recordB
        var recordC = H2HRecord()
        recordC.losses = 3
        records[c.id] = recordC
        let base: Items = ["S": [], "A": [], "B": [], "unranked": pool]

        let quick = HeadToHeadLogic.quickTierPass(
            from: pool,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        let artifacts = quick.artifacts!
        let (rebuilt, _) = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: records,
            tierOrder: ["S", "A", "B"],
            baseTiers: base
        )

        XCTAssertEqual(rebuilt["S"]?.map(\.id), ["a"])
        XCTAssertEqual(rebuilt["A"]?.map(\.id), ["b"])
        XCTAssertEqual(rebuilt["B"]?.map(\.id), ["c"])
        XCTAssertTrue(rebuilt["unranked"]?.isEmpty ?? false)
    }

    func testMoveItem() {
        let c = Item(id: "x", name: "X")
        let start: Items = ["A": [], "B": [c]]
        let moved = TierLogic.moveItem(start, itemId: "x", targetTierName: "A")
        XCTAssertEqual(moved["A"]?.count, 1)
        XCTAssertEqual(moved["B"]?.count, 0)
        // no-op if moving again to same tier
        let noop = TierLogic.moveItem(moved, itemId: "x", targetTierName: "A")
        XCTAssertEqual(noop, moved)
    }

    func testSeededRNGAndPickPair() {
        var rng = SeededRNG(seed: 42)
        let vals = (0..<3).map { _ in rng.next() }
        XCTAssertEqual(vals.count, 3)
        let arr = [1, 2, 3]
        let pair = RandomUtils.pickRandomPair(arr) { rng.next() }
        XCTAssertNotNil(pair)
        if let p = pair { XCTAssertNotEqual(p.0, p.1) }
    }
}
