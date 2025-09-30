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
    }

    func cancelQuickMove() {
        quickMoveTarget = nil
    }

    func commitQuickMove(to tier: String) {
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
        currentToast = ToastMessage(
            type: .info,
            title: "Moved",
            message: "Moved ‘\(movedName)’ to \(tier)",
            duration: 3.0,
            actionTitle: "Undo",
            action: { [weak self] in
                guard let self else { return }
                self.tiers = previous
                self.history = HistoryLogic.saveSnapshot(self.history, snapshot: previous)
                self.markAsChanged()
            }
        )
        announce("Moved ‘\(movedName)’ to \(tier) tier")
    }

    // MARK: - Item Menu (tvOS primary)
    func presentItemMenu(_ item: Item) {
        itemMenuTarget = item
    }

    func dismissItemMenu() {
        itemMenuTarget = nil
    }
}
