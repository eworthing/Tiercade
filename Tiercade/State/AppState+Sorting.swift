import Foundation
import TiercadeCore

// MARK: - Sorting Extension

@MainActor
extension AppState {

    // MARK: - Set Global Sort Mode

    /// Set the global sort mode (display-only projection until applied)
    /// - Parameter mode: The new sort mode to apply
    func setGlobalSortMode(_ mode: GlobalSortMode) {
        globalSortMode = mode
        persistence.hasUnsavedChanges = true
    }

    // MARK: - Apply Global Sort (Commit to Storage)

    /// Commit the current global sort to storage (bake into arrays, flip to .custom)
    /// This makes the current sorted view the new "manual order"
    func applyGlobalSortToCustom() {
        // Don't apply if already in custom mode
        guard !globalSortMode.isCustom else {
            showInfoToast("Already Custom", message: "Items are already in manual order")
            return
        }

        let snapshot = captureTierSnapshot()

        // Apply sort to all tiers and bake into arrays
        for tierName in tierOrder + ["unranked"] {
            guard let items = tiers[tierName] else {
                continue
            }
            tiers[tierName] = Sorting.sortItems(items, by: globalSortMode)
        }

        // Flip to custom mode
        let previousMode = globalSortMode.displayName
        globalSortMode = .custom

        finalizeChange(action: "Apply Global Sort", undoSnapshot: snapshot)
        showSuccessToast("Sort Applied", message: "\(previousMode) is now your custom order")
    }

    // MARK: - Reorder Items

    /// Reorder items within a tier (only allowed when in .custom mode)
    /// - Parameters:
    ///   - tierName: The tier containing the items
    ///   - indices: IndexSet of item indices to move
    ///   - destination: Target index position
    func reorderItems(in tierName: String, from indices: IndexSet, to destination: Int) {
        // Block reordering when not in custom mode
        guard globalSortMode.isCustom else {
            showInfoToast(
                "Sort Active",
                message: "Tap 'Apply Global Sort' to enable reordering",
            )
            return
        }

        guard let index = indices.first else {
            return
        }
        let snapshot = captureTierSnapshot()

        // Use existing TierLogic.reorderWithin
        tiers = TierLogic.reorderWithin(tiers, tierName: tierName, from: index, to: destination)

        finalizeChange(action: "Reorder Items", undoSnapshot: snapshot)
    }

    /// Reorder a block of items (multi-select) preserving their relative order
    /// - Parameters:
    ///   - tierName: The tier containing the items
    ///   - indices: IndexSet of item indices to move (can be non-contiguous)
    ///   - destination: Target index position for the block
    func reorderBlock(in tierName: String, from indices: IndexSet, to destination: Int) {
        // Block reordering when not in custom mode
        guard globalSortMode.isCustom else {
            showInfoToast(
                "Sort Active",
                message: "Tap 'Apply Global Sort' to enable reordering",
            )
            return
        }

        guard var items = tiers[tierName] else {
            return
        }
        guard !indices.isEmpty else {
            return
        }

        let snapshot = captureTierSnapshot()

        // Extract items to move, preserving their relative order
        let itemsToMove = indices.sorted().map { items[$0] }

        // Remove items from original positions (in reverse order to maintain indices)
        for index in indices.sorted().reversed() {
            items.remove(at: index)
        }

        // Calculate adjusted destination (accounts for removed items)
        let adjustedDestination = destination - indices.count(where: { $0 < destination })

        // Insert items at destination, preserving their relative order
        items.insert(contentsOf: itemsToMove, at: adjustedDestination)

        tiers[tierName] = items
        finalizeChange(action: "Reorder Block", undoSnapshot: snapshot)
    }

    /// Move item left within its tier (tvOS onMoveCommand support)
    /// - Parameters:
    ///   - itemId: Item to move
    ///   - tierName: Tier containing the item
    func moveItemLeft(_ itemId: String, in tierName: String) {
        guard globalSortMode.isCustom else {
            showInfoToast("Sort Active", message: "Apply global sort to enable reordering")
            return
        }

        guard var items = tiers[tierName] else {
            return
        }
        guard let currentIndex = items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        guard currentIndex > 0 else {
            return
        } // Already at start

        let snapshot = captureTierSnapshot()

        // Swap with previous item
        items.swapAt(currentIndex, currentIndex - 1)
        tiers[tierName] = items

        finalizeChange(action: "Move Item Left", undoSnapshot: snapshot)
    }

    /// Move item right within its tier (tvOS onMoveCommand support)
    /// - Parameters:
    ///   - itemId: Item to move
    ///   - tierName: Tier containing the item
    func moveItemRight(_ itemId: String, in tierName: String) {
        guard globalSortMode.isCustom else {
            showInfoToast("Sort Active", message: "Apply global sort to enable reordering")
            return
        }

        guard var items = tiers[tierName] else {
            return
        }
        guard let currentIndex = items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        guard currentIndex < items.count - 1 else {
            return
        } // Already at end

        let snapshot = captureTierSnapshot()

        // Swap with next item
        items.swapAt(currentIndex, currentIndex + 1)
        tiers[tierName] = items

        finalizeChange(action: "Move Item Right", undoSnapshot: snapshot)
    }

    // MARK: - Discover Sortable Attributes

    /// Discover sortable attributes available across all tiers
    /// - Returns: Dictionary of attribute key to inferred type
    func discoverSortableAttributes() -> [String: AttributeType] {
        Sorting.discoverSortableAttributes(in: tiers)
    }
}
