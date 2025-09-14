import Foundation

public enum QuickRankLogic {
    /// Returns updated tiers after assigning a contestant by id into a tier.
    /// If contestant already in target tier or not found, returns original tiers.
    public static func assign(_ tiers: Tiers, contestantId: String, to tierName: String) -> Tiers {
        TierLogic.moveContestant(tiers, contestantId: contestantId, targetTierName: tierName)
    }
}
