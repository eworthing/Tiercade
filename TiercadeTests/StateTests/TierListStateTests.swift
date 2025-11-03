import Testing
@testable import Tiercade
import TiercadeCore

/// Tests for TierListState
///
/// Focus on snapshot/restore logic for undo/redo and computed properties
/// for item counting and validation.
@MainActor
struct TierListStateTests {
    // MARK: - Test Helpers

    func makeTestItem(_ id: String, _ name: String) -> Item {
        Item(id: id, attributes: ["name": name])
    }

    func populateState(_ state: TierListState) {
        state.tiers["S"] = [makeTestItem("item1", "Item 1")]
        state.tiers["A"] = [makeTestItem("item2", "Item 2"), makeTestItem("item3", "Item 3")]
        state.tiers["B"] = []
        state.tierLabels["S"] = "Best"
        state.tierColors["S"] = "#FF0000"
        state.lockedTiers.insert("F")
    }

    // MARK: - Snapshot & Restore Tests

    @Test("captureTierSnapshot captures all state")
    func captureTierSnapshot() {
        let state = TierListState()
        populateState(state)

        let snapshot = state.captureTierSnapshot()

        #expect(snapshot.tiers["S"]?.count == 1)
        #expect(snapshot.tiers["A"]?.count == 2)
        #expect(snapshot.tierOrder == state.tierOrder)
        #expect(snapshot.tierLabels["S"] == "Best")
        #expect(snapshot.tierColors["S"] == "#FF0000")
        #expect(snapshot.lockedTiers.contains("F"))
    }

    @Test("restore applies snapshot state")
    func restore() {
        let state = TierListState()
        populateState(state)

        let snapshot = state.captureTierSnapshot()

        // Modify state
        state.tiers["S"] = []
        state.tierLabels.removeAll()
        state.tierColors.removeAll()
        state.lockedTiers.removeAll()

        // Restore
        state.restore(from: snapshot)

        #expect(state.tiers["S"]?.count == 1)
        #expect(state.tiers["A"]?.count == 2)
        #expect(state.tierLabels["S"] == "Best")
        #expect(state.tierColors["S"] == "#FF0000")
        #expect(state.lockedTiers.contains("F"))
    }

    @Test("restore preserves exact tier structure")
    func restore_preservesStructure() {
        let state = TierListState()
        populateState(state)

        let snapshot = state.captureTierSnapshot()

        // Clear and add different data
        state.tiers.removeAll()
        state.tiers["X"] = [makeTestItem("other", "Other")]

        // Restore should replace completely
        state.restore(from: snapshot)

        #expect(state.tiers["X"] == nil)
        #expect(state.tiers["S"]?.count == 1)
        #expect(state.tiers["A"]?.count == 2)
    }

    // MARK: - Selection Tests

    @Test("isSelected returns correct value")
    func isSelected() {
        let state = TierListState()
        state.selection.insert("item1")

        #expect(state.isSelected("item1") == true)
        #expect(state.isSelected("item2") == false)
    }

    @Test("toggleSelection adds and removes items")
    func toggleSelection() {
        let state = TierListState()

        state.toggleSelection("item1")
        #expect(state.isSelected("item1") == true)

        state.toggleSelection("item1")
        #expect(state.isSelected("item1") == false)
    }

    @Test("clearSelection removes all items")
    func clearSelection() {
        let state = TierListState()
        state.selection = ["item1", "item2", "item3"]

        state.clearSelection()
        #expect(state.selection.isEmpty)
    }

    // MARK: - Computed Properties Tests

    @Test("totalItemCount sums all tiers")
    func totalItemCount() {
        let state = TierListState()
        populateState(state)

        #expect(state.totalItemCount == 3)  // 1 in S, 2 in A
    }

    @Test("totalItemCount handles empty tiers")
    func totalItemCount_empty() {
        let state = TierListState()
        #expect(state.totalItemCount == 0)
    }

    @Test("hasAnyItems returns true when items exist")
    func hasAnyItems_true() {
        let state = TierListState()
        populateState(state)

        #expect(state.hasAnyItems == true)
    }

    @Test("hasAnyItems returns false when no items")
    func hasAnyItems_false() {
        let state = TierListState()
        #expect(state.hasAnyItems == false)
    }

    @Test("hasEnoughForPairing requires at least 2 items")
    func hasEnoughForPairing() {
        let state = TierListState()

        #expect(state.hasEnoughForPairing == false)

        state.tiers["S"] = [makeTestItem("item1", "Item 1")]
        #expect(state.hasEnoughForPairing == false)

        state.tiers["A"] = [makeTestItem("item2", "Item 2")]
        #expect(state.hasEnoughForPairing == true)
    }

    @Test("canRandomizeItems requires more than 1 item")
    func canRandomizeItems() {
        let state = TierListState()

        #expect(state.canRandomizeItems == false)

        state.tiers["S"] = [makeTestItem("item1", "Item 1")]
        #expect(state.canRandomizeItems == false)

        state.tiers["A"] = [makeTestItem("item2", "Item 2")]
        #expect(state.canRandomizeItems == true)
    }

    // MARK: - Display Helpers Tests

    @Test("displayLabel returns custom label or fallback")
    func displayLabel() {
        let state = TierListState()
        state.tierLabels["S"] = "Best"

        #expect(state.displayLabel(for: "S") == "Best")
        #expect(state.displayLabel(for: "A") == "A")  // Fallback
    }

    @Test("displayColorHex returns custom color or nil")
    func displayColorHex() {
        let state = TierListState()
        state.tierColors["S"] = "#FF0000"

        #expect(state.displayColorHex(for: "S") == "#FF0000")
        #expect(state.displayColorHex(for: "A") == nil)
    }

    // MARK: - Undo/Redo Tests

    @Test("canUndo returns false without undo manager")
    func canUndo_noManager() {
        let state = TierListState()
        #expect(state.canUndo == false)
    }

    @Test("canRedo returns false without undo manager")
    func canRedo_noManager() {
        let state = TierListState()
        #expect(state.canRedo == false)
    }

    @Test("updateUndoManager sets the undo manager")
    func updateUndoManager() {
        let state = TierListState()
        let manager = UndoManager()

        state.updateUndoManager(manager)
        #expect(state.undoManager != nil)
    }
}
