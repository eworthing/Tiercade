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
        // Collect all items from all tiers (including unranked)
        var allItems: [Item] = []
        for tierName in Array(tiers.keys) {
            allItems.append(contentsOf: tiers[tierName] ?? [])
        }

        guard !allItems.isEmpty else { return }

        // Build fresh tiers dictionary - ONLY include tiers from tierOrder plus unranked
        var newTiers: Items = [:]
        for tierName in tierOrder {
            newTiers[tierName] = []
        }
        newTiers["unranked"] = []

        // Shuffle all items
        allItems.shuffle()

        // Distribute to ranked tiers only (NOT unranked)
        var remainingItems = allItems

        // If we have enough items, guarantee at least 1 item per tier
        if allItems.count >= tierOrder.count {
            for tierName in tierOrder {
                if let item = remainingItems.popLast() {
                    newTiers[tierName, default: []].append(item)
                }
            }
        }

        // Randomly distribute remaining items across ranked tiers only
        for item in remainingItems {
            let randomTierName = tierOrder.randomElement() ?? tierOrder[0]
            newTiers[randomTierName, default: []].append(item)
        }

        tiers = newTiers
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()

        showSuccessToast("Tiers Randomized", message: "All \(allItems.count) items distributed randomly")
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
