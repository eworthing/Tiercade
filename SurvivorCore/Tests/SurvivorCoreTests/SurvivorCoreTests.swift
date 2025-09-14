import XCTest
@testable import SurvivorCore

final class SurvivorCoreTests: XCTestCase {
    func testDecodeAndValidate() throws {
        let contestantsJSON = """
        {"c1": {"id":"c1","name":"One","season": 1}, "c2": {"id":"c2","name":"Two","season":"2"}}
        """.data(using: .utf8)!
        let groupsJSON = """
        {"All": ["c1", "c2"]}
        """.data(using: .utf8)!
        let loader = DataLoader()
        let contestants = try loader.decodeContestants(from: contestantsJSON)
        let groups = try loader.decodeGroups(from: groupsJSON)
        XCTAssertTrue(loader.validate(groups: groups, contestants: contestants))
        XCTAssertEqual(contestants["c1"]?.seasonNumber, 1)
        XCTAssertEqual(contestants["c2"]?.seasonString, "2")
    }

    func testHistory() {
    func testQuickRankAssign() {
        let c = Contestant(id: "x", name: "X")
        let start: Tiers = ["S": [], "A": [], "unranked": [c]]
        let updated = QuickRankLogic.assign(start, contestantId: "x", to: "S")
        XCTAssertEqual(updated["S"]?.first?.id, "x")
        XCTAssertEqual(updated["unranked"]?.isEmpty, true)
    }

    func testH2HDistributeRoundRobin() {
        let a = Contestant(id: "a", name: "A")
        let b = Contestant(id: "b", name: "B")
        let c = Contestant(id: "c", name: "C")
        let ranking = [H2HRankingEntry(contestant: a, winRate: 0.9), H2HRankingEntry(contestant: b, winRate: 0.8), H2HRankingEntry(contestant: c, winRate: 0.7)]
        let tiers: Tiers = ["S": [], "A": [], "B": [], "unranked": [a,b,c]]
        let distributed = HeadToHeadLogic.distributeRoundRobin(ranking, into: ["S","A","B"], baseTiers: tiers)
        XCTAssertEqual(distributed["S"]?.map { $0.id }, ["a"])
        XCTAssertEqual(distributed["A"]?.map { $0.id }, ["b"])
        XCTAssertEqual(distributed["B"]?.map { $0.id }, ["c"])
        XCTAssertEqual(distributed["unranked"]?.isEmpty, true)
    }

        var h = HistoryLogic.initHistory([0])
        h = HistoryLogic.saveSnapshot(h, snapshot: [0,1])
        XCTAssertTrue(HistoryLogic.canUndo(h))
        XCTAssertFalse(HistoryLogic.canRedo(h))
        let u = HistoryLogic.undo(h)
        XCTAssertFalse(HistoryLogic.canUndo(u))
    }

    func testMoveContestant() {
        let c = Contestant(id: "x", name: "X")
        let start: Tiers = ["A": [], "B": [c]]
        let moved = TierLogic.moveContestant(start, contestantId: "x", targetTierName: "A")
        XCTAssertEqual(moved["A"]?.count, 1)
        XCTAssertEqual(moved["B"]?.count, 0)
        // no-op if moving again to same tier
        let noop = TierLogic.moveContestant(moved, contestantId: "x", targetTierName: "A")
        XCTAssertEqual(noop, moved)
    }

    func testSeededRNGAndPickPair() {
        var rng = SeededRNG(seed: 42)
        let vals = (0..<3).map { _ in rng.next() }
        XCTAssertEqual(vals.count, 3)
        let arr = [1,2,3]
        let pair = RandomUtils.pickRandomPair(arr) { rng.next() }
        XCTAssertNotNil(pair)
        if let p = pair { XCTAssertNotEqual(p.0, p.1) }
    }
}
