import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Selection / Multi-Select
    func toggleMultiSelect() {
        isMultiSelect.toggle()
        if !isMultiSelect { selection.removeAll() }
    }

    func isSelected(_ id: String) -> Bool { selection.contains(id) }

    func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    func clearSelection() { selection.removeAll() }

    func move(_ id: String, to tier: String) {
        if lockedTiers.contains(tier) {
            showErrorToast("Tier Locked", message: "Cannot move into \(tier)")
            announce("Tier \(tier) is locked. Move canceled.")
            return
        }
        let next = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
        guard next != tiers else { return }
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        if let name = tiers[tier]?.first(where: { $0.id == id })?.name {
            showInfoToast("Moved", message: "Moved ‘\(name)’ to \(tier)")
            announce("Moved ‘\(name)’ to \(tier) tier")
        } else {
            showInfoToast("Moved", message: "Moved to \(tier)")
            announce("Moved to \(tier) tier")
        }
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("move: itemId=\(id) -> tier=\(tier) counts=\(counts)")
    }

    func batchMove(_ ids: [String], to tier: String) {
        guard !ids.isEmpty else { return }
        guard !lockedTiers.contains(tier) else {
            showErrorToast("Tier Locked", message: "Cannot move into \(tier)")
            announce("Tier \(tier) is locked. Move canceled.")
            return
        }
        var next = tiers
        for id in ids {
            next = TierLogic.moveItem(next, itemId: id, targetTierName: tier)
        }
        guard next != tiers else { return }
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        clearSelection()
        showSuccessToast("Moved Items", message: "Moved \(ids.count) item(s) to \(tier)")
        let count = ids.count
        let announcement = "Moved \(count) item\(count == 1 ? "" : "s") to \(tier) tier"
        announce(announcement)
    }

    func currentTier(of id: String) -> String? {
        for tierName in tierOrder + ["unranked"] where (tiers[tierName]?.contains(where: { $0.id == id }) ?? false) {
            return tierName
        }
        return nil
    }

    func removeFromCurrentTier(_ id: String) {
        move(id, to: "unranked")
    }

    func clearTier(_ tier: String) {
        var next = tiers
        guard let moving = next[tier], !moving.isEmpty else { return }
        next[tier] = []
        next["unranked", default: []].append(contentsOf: moving)
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        let toastMessage = "Moved all items from \(tier) tier to unranked"
        showInfoToast("Tier Cleared", message: toastMessage)
        let announcement = "Cleared \(tier) tier. Moved \(moving.count) item\(moving.count == 1 ? "" : "s") to unranked"
        announce(announcement)
    }

    // MARK: - Tier Locking
    func isTierLocked(_ id: String) -> Bool { lockedTiers.contains(id) }

    func toggleTierLocked(_ id: String) {
        if lockedTiers.contains(id) {
            lockedTiers.remove(id)
        } else {
            lockedTiers.insert(id)
        }
        let label = displayLabel(for: id)
        announce(lockedTiers.contains(id) ? "Locked \(label) tier" : "Unlocked \(label) tier")
    }

    // MARK: - Tier Presentation
    func displayLabel(for tierId: String) -> String { tierLabels[tierId] ?? tierId }

    func setDisplayLabel(_ label: String, for tierId: String) {
        tierLabels[tierId] = label
    }

    func displayColorHex(for tierId: String) -> String? { tierColors[tierId] }

    func setDisplayColorHex(_ hex: String?, for tierId: String) {
        tierColors[tierId] = hex
    }
}
