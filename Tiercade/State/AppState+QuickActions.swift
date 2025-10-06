import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Quick Rank
    func beginQuickRank(_ item: Item) {
        quickRankTarget = item
    }

    func cancelQuickRank() {
        quickRankTarget = nil
    }

    func commitQuickRank(to tier: String) {
        guard let target = quickRankTarget else { return }
        let next = QuickRankLogic.assign(tiers, itemId: target.id, to: tier)
        guard next != tiers else {
            quickRankTarget = nil
            return
        }

        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        quickRankTarget = nil

        logEvent("commitQuickRank: item=\(target.id) -> tier=\(tier)")
    }

    // MARK: - Quick Move (tvOS Play/Pause)
    func beginQuickMove(_ item: Item) {
        quickMoveTarget = item
        batchQuickMoveActive = false
    }

    func cancelQuickMove() {
        quickMoveTarget = nil
        batchQuickMoveActive = false
    }

    func commitQuickMove(to tier: String) {
        // Handle batch move if in batch mode
        if batchQuickMoveActive {
            commitBatchQuickMove(to: tier)
            return
        }

        guard let item = quickMoveTarget else { return }
        let previous = tiers
        let next = QuickRankLogic.assign(tiers, itemId: item.id, to: tier)
        guard next != tiers else {
            quickMoveTarget = nil
            return
        }

        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        quickMoveTarget = nil

        let movedName = item.name ?? item.id
        let displayTier = displayLabel(for: tier)
        showSuccessToast("Moved", message: "Moved '\(movedName)' to \(displayTier)")
        announce("Moved '\(movedName)' to \(displayTier) tier")
    }

    // MARK: - Batch Quick Move
    func presentBatchQuickMove() {
        guard !selection.isEmpty else { return }
        batchQuickMoveActive = true
        // Use a dummy item to trigger the overlay
        quickMoveTarget = Item(id: "batch", attributes: ["name": "\(selection.count) Items"])
    }

    func commitBatchQuickMove(to tier: String) {
        guard !selection.isEmpty else {
            cancelQuickMove()
            return
        }

        batchMove(Array(selection), to: tier)
        cancelQuickMove()
    }

}
