import Foundation
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Item Management

    func reset(showToast: Bool = false) {
        let hasAnyData = (tierOrder + ["unranked"]).contains { tierName in
            !(tiers[tierName] ?? []).isEmpty
        }

        if hasAnyData, !showToast {
            showResetConfirmation = true
            return
        }

        performReset(showToast: showToast)
    }

    func performReset(showToast: Bool = false) {
        let snapshot = captureTierSnapshot()
        if let defaultProject = bundledProjects.first {
            let state = resolvedTierState(for: defaultProject)
            tierOrder = state.order
            tiers = state.items
            tierLabels = state.labels
            tierColors = state.colors
            lockedTiers = state.locked
        } else {
            tiers = makeEmptyTiers()
        }
        finalizeChange(action: "Reset Tier List", undoSnapshot: snapshot)

        if showToast {
            showSuccessToast("Reset Complete", message: "Tier list reset. Undo available if needed.")
            announce("Tier list reset")
        }
    }

    func addItem(id: String, attributes: [String: String]? = nil) {
        let snapshot = captureTierSnapshot()
        let item = Item(id: id, attributes: attributes)
        tiers["unranked", default: []].append(item)
        finalizeChange(action: "Add Item", undoSnapshot: snapshot)
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
            !(tiers[tierName] ?? []).isEmpty
        }

        if hasRankedData {
            showRandomizeConfirmation = true
            return
        }

        performRandomize()
    }

    func performRandomize() {
        let snapshot = captureTierSnapshot()
        var (lockedTierItems, unlockedItems) = partitionItemsByLockState()
        guard !unlockedItems.isEmpty else {
            return
        }

        var newTiers = baseTierDictionary(using: lockedTierItems)
        let unlockedRankedTiers = tierOrder.filter { !lockedTiers.contains($0) }
        guard !unlockedRankedTiers.isEmpty else {
            return
        }

        unlockedItems.shuffle()
        distribute(unlockedItems: unlockedItems, into: unlockedRankedTiers, tiers: &newTiers)

        tiers = newTiers
        finalizeChange(action: "Randomize Tiers", undoSnapshot: snapshot)

        let lockedCount = lockedTiers.count
        let lockedSuffix = lockedCount == 1 ? "" : "s"
        let lockedSummary = "\(lockedCount) tier\(lockedSuffix) locked {lock}"
        let baseMessage = lockedCount > 0
            ? "\(unlockedItems.count) items distributed randomly (\(lockedSummary))"
            : "All \(unlockedItems.count) items distributed randomly"
        let message = baseMessage + ". Use {undo} to reverse."
        showSuccessToast("Tiers Randomized", message: message)
        announce("Tiers randomized")
    }

    private func partitionItemsByLockState() -> (locked: Items, unlocked: [Item]) {
        var lockedTierItems: Items = [:]
        var unlockedItems: [Item] = []

        for tierName in tiers.keys {
            let tierItems = tiers[tierName] ?? []
            if lockedTiers.contains(tierName) {
                lockedTierItems[tierName] = tierItems
            } else {
                unlockedItems.append(contentsOf: tierItems)
            }
        }

        return (lockedTierItems, unlockedItems)
    }

    private func baseTierDictionary(using lockedItems: Items) -> Items {
        var newTiers: Items = [:]
        for tierName in tierOrder {
            newTiers[tierName] = lockedItems[tierName] ?? []
        }
        newTiers["unranked"] = lockedItems["unranked"] ?? []
        return newTiers
    }

    private func distribute(unlockedItems: [Item], into unlockedRankedTiers: [String], tiers: inout Items) {
        guard !unlockedRankedTiers.isEmpty else {
            return
        }

        var remainingItems = unlockedItems

        if unlockedItems.count >= unlockedRankedTiers.count {
            for tierName in unlockedRankedTiers {
                guard let item = remainingItems.popLast() else {
                    break
                }
                tiers[tierName, default: []].append(item)
            }
        }

        for item in remainingItems {
            guard let randomTierName = unlockedRankedTiers.randomElement() else {
                continue
            }
            tiers[randomTierName, default: []].append(item)
        }
    }

    /// Builds empty tier dictionary dynamically from current tierOrder
    /// This enables custom tier names, ordering, and variable tier counts
    private func makeEmptyTiers() -> Items {
        var result: Items = [:]
        for name in tierOrder {
            result[name] = []
        }
        result["unranked"] = []
        return result
    }
}
