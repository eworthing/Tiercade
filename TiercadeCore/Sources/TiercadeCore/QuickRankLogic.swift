import Foundation

public enum QuickRankLogic {
    /// Returns updated items after assigning an item by id into a tier.
    /// If item already in target tier or not found, returns original tiers.
    public static func assign(_ tiers: Items, itemId: String, to tierName: String) -> Items {
        TierLogic.moveItem(tiers, itemId: itemId, targetTierName: tierName)
    }
}
