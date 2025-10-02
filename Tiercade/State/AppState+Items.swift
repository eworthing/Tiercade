import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Item Management
    func reset(showToast: Bool = false) {
        // Check if there's any data to reset
        let hasAnyData = (tierOrder + ["unranked"]).contains { tierName in
            (tiers[tierName] ?? []).count > 0
        }

        if hasAnyData && !showToast {
            showResetConfirmation = true
            return
        }

        performReset(showToast: showToast)
    }

    func performReset(showToast: Bool = false) {
        tiers = makeEmptyTiers()
        seed()
        history = HistoryLogic.initHistory(tiers, limit: history.limit)
        markAsChanged()

        if showToast {
            showSuccessToast("Tier list reset")
            announce("Tier list reset")
        }
    }

    func addItem(id: String, attributes: [String: String]? = nil) {
        let item = Item(id: id, attributes: attributes)
        tiers["unranked", default: []].append(item)
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        let display = attributes?["name"] ?? id
        showSuccessToast("Added", message: "Added \(display) to Unranked")
        announce("Added \(display) to unranked")
    }

    func randomize() {
        guard canRandomizeItems else {
            showInfoToast("Nothing to Randomize", message: "Add more items before shuffling tiers")
            return
        }

        // Check if there's data in ranked tiers (excluding unranked)
        let hasRankedData = tierOrder.contains { tierName in
            (tiers[tierName] ?? []).count > 0
        }

        if hasRankedData {
            showRandomizeConfirmation = true
            return
        }

        performRandomize()
    }

    func performRandomize() {
        var allItems: [Item] = []
        for tierName in tierOrder + ["unranked"] {
            allItems.append(contentsOf: tiers[tierName] ?? [])
        }

        var newTiers = tiers
        for tierName in tierOrder + ["unranked"] {
            newTiers[tierName] = []
        }

        allItems.shuffle()
        let tiersToFill = tierOrder
        let itemsPerTier = max(1, allItems.count / tiersToFill.count)

        for (index, item) in allItems.enumerated() {
            let tierIndex = min(index / itemsPerTier, tiersToFill.count - 1)
            let tierName = tiersToFill[tierIndex]
            newTiers[tierName, default: []].append(item)
        }

        tiers = newTiers
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        showSuccessToast("Tiers Randomized", message: "All items have been redistributed randomly")
        announce("Tiers randomized")
    }

    private func makeEmptyTiers() -> Items {
        [
            "S": [],
            "A": [],
            "B": [],
            "C": [],
            "D": [],
            "F": [],
            "unranked": []
        ]
    }
}
