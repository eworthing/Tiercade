import Foundation

extension HeadToHeadLogic {
    internal static func quickResultForUndersampled(
        tiers: Items,
        undersampled: [Item],
        baseTiers: Items,
        tierOrder: [String],
        records: [String: HeadToHeadRecord]
    ) -> HeadToHeadQuickResult {
        guard !undersampled.isEmpty else {
            return HeadToHeadQuickResult(tiers: tiers, artifacts: nil, suggestedPairs: [])
        }

        var updatedTiers = tiers
        let unrankedKey = TierIdentifier.unranked.rawValue
        let priors = buildPriors(from: baseTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
        updatedTiers[unrankedKey, default: []] = orderedItems(undersampled, metrics: metrics)
        return HeadToHeadQuickResult(tiers: updatedTiers, artifacts: nil, suggestedPairs: [])
    }

    internal static func appendUndersampled(
        _ undersampled: [Item],
        to tiers: inout Items,
        records: [String: HeadToHeadRecord],
        priors: [String: Prior]
    ) {
        guard !undersampled.isEmpty else { return }
        let unrankedKey = TierIdentifier.unranked.rawValue
        let metrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
        tiers[unrankedKey, default: []] = orderedItems(undersampled, metrics: metrics)
    }

    internal static func makeQuickArtifacts(
        ordered: [Item],
        undersampled: [Item],
        operativeNames: [String],
        cuts: [Int],
        metrics: [String: HeadToHeadMetrics]
    ) -> HeadToHeadArtifacts {
        let audits = buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth)
        return HeadToHeadArtifacts(
            tierNames: operativeNames,
            rankable: ordered,
            undersampled: undersampled,
            provisionalCuts: cuts,
            frontier: audits,
            warmUpComparisons: warmUpComparisons(rankableCount: ordered.count, tierCount: operativeNames.count),
            mode: .quick,
            metrics: metrics
        )
    }
}
