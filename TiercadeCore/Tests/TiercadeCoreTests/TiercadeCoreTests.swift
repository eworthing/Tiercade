import XCTest
@testable import TiercadeCore

final class TiercadeCoreTests: XCTestCase {
    func testDecodeAndValidate() throws {
    let itemsJSON = """
    {"c1": {"id":"c1","name":"One","season": 1}, "c2": {"id":"c2","name":"Two","season":"2"}}
    """.data(using: .utf8)!
        let groupsJSON = """
        {"All": ["c1", "c2"]}
        """.data(using: .utf8)!
        let loader = DataLoader()
        let items = try loader.decodeItems(from: itemsJSON)
            let groups = try loader.decodeGroups(from: groupsJSON)
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

    func testH2HDistributeRoundRobin() {
        let a = Item(id: "a", name: "A")
        let b = Item(id: "b", name: "B")
        let c = Item(id: "c", name: "C")
    let ranking = [H2HRankingEntry(item: a, winRate: 0.9), H2HRankingEntry(item: b, winRate: 0.8), H2HRankingEntry(item: c, winRate: 0.7)]
        let tiers: Items = ["S": [], "A": [], "B": [], "unranked": [a, b, c]]
        let distributed = HeadToHeadLogic.distributeRoundRobin(ranking, into: ["S", "A", "B"], baseTiers: tiers)
        XCTAssertEqual(distributed["S"]?.map { $0.id }, ["a"])
        XCTAssertEqual(distributed["A"]?.map { $0.id }, ["b"])
        XCTAssertEqual(distributed["B"]?.map { $0.id }, ["c"])
        XCTAssertEqual(distributed["unranked"]?.isEmpty, true)
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
