import Foundation

public enum TierLogic {
    /// Move contestant with id to target tier; returns new tiers or original if no-op.
    public static func moveContestant(_ tiers: Tiers, contestantId: String, targetTierName: String) -> Tiers {
        guard !contestantId.isEmpty, !targetTierName.isEmpty else { return tiers }
        var newTiers = tiers

        var sourceTier: String?
        var found: Contestant?
        for (name, arr) in newTiers {
            if let idx = arr.firstIndex(where: { $0.id == contestantId }) {
                sourceTier = name
                found = arr[idx]
                var copy = arr
                copy.remove(at: idx)
                newTiers[name] = copy
                break
            }
        }
        guard let c = found else { return tiers }
        if sourceTier == targetTierName { return tiers }
        var target = newTiers[targetTierName] ?? []
        target.append(c)
        newTiers[targetTierName] = target
        return newTiers
    }

    /// Reorder within one tier from index to index; bounds-safe no-op on invalid.
    public static func reorderWithin(_ tiers: Tiers, tierName: String, from: Int, to: Int) -> Tiers {
        guard var arr = tiers[tierName], from >= 0, from < arr.count, to >= 0, to < arr.count else { return tiers }
        var copy = arr
        let item = copy.remove(at: from)
        copy.insert(item, at: to)
        var new = tiers
        new[tierName] = copy
        return new
    }

    public static func validateTiersShape(_ tiers: Tiers) -> Bool {
        // In Swift typing already constrains shape, but keep parity placeholder
        true
    }
}
