import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Theme Picker Overlay
    func presentThemePicker() {
        showThemePicker = true
        themePickerActive = true
    }

    // MARK: - Selection / Multi-Select
    // Note: editMode is managed by view layer via environment
    // AppState only manages the selection Set
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
            let displayTier = displayLabel(for: tier)
            showErrorToast("Tier Locked", message: "Cannot move into \(displayTier)")
            announce("Tier \(displayTier) is locked. Move canceled.")
            return
        }
        let next = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
        guard next != tiers else { return }
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        let displayTier = displayLabel(for: tier)
        if let name = tiers[tier]?.first(where: { $0.id == id })?.name {
            showInfoToast("Moved", message: "Moved '\(name)' to \(displayTier)")
            announce("Moved '\(name)' to \(displayTier) tier")
        } else {
            showInfoToast("Moved", message: "Moved to \(displayTier)")
            announce("Moved to \(displayTier) tier")
        }
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("move: itemId=\(id) -> tier=\(tier) counts=\(counts)")
    }

    func batchMove(_ ids: [String], to tier: String) {
        guard !ids.isEmpty else { return }
        let displayTier = displayLabel(for: tier)
        guard !lockedTiers.contains(tier) else {
            showErrorToast("Tier Locked", message: "Cannot move into \(displayTier)")
            announce("Tier \(displayTier) is locked. Move canceled.")
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
        showSuccessToast("Moved Items", message: "Moved \(ids.count) item(s) to \(displayTier)")
        let count = ids.count
        let announcement = "Moved \(count) item\(count == 1 ? "" : "s") to \(displayTier) tier"
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
        let displayTier = displayLabel(for: tier)
        let toastMessage = "Moved all items from \(displayTier) tier to Unranked"
        showInfoToast("Tier Cleared", message: toastMessage)
        let announcement = "Cleared \(displayTier) tier. Moved \(moving.count) item\(moving.count == 1 ? "" : "s") to Unranked"
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
        // Check for duplicate labels
        let existingTiersWithLabel = tierLabels.filter { $0.key != tierId && $0.value == label }
        if !existingTiersWithLabel.isEmpty {
            showInfoToast("Duplicate Name", message: "Another tier already has this name")
        }
        tierLabels[tierId] = label
        markAsChanged()
    }

    func displayColorHex(for tierId: String) -> String? { tierColors[tierId] }

    func setDisplayColorHex(_ hex: String?, for tierId: String) {
        tierColors[tierId] = hex
    }
}
