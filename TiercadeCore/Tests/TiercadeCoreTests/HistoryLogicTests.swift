import XCTest
@testable import TiercadeCore

final class HistoryLogicTests: XCTestCase {
    func testInitAndUndoRedo() {
        let initial: Items = ["A": [Item(id: "one")], "unranked": []]
        var history = HistoryLogic.initHistory(initial, limit: 10)

        // Save a new snapshot
        let next: Items = ["A": [], "unranked": [Item(id: "one")]]
        history = HistoryLogic.saveSnapshot(history, snapshot: next)

        XCTAssertTrue(HistoryLogic.canUndo(history))
        history = HistoryLogic.undo(history)
        XCTAssertEqual(HistoryLogic.current(history)["A"]?.count, 1)

        XCTAssertTrue(HistoryLogic.canRedo(history))
        history = HistoryLogic.redo(history)
        XCTAssertEqual(HistoryLogic.current(history)["unranked"]?.count, 1)
    }
}
