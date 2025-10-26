import Foundation

extension HeadToHeadLogic {
    internal static func quickResultForUndersampled(
        tiers: Items,
        undersampled: [Item],
        baseTiers: Items,
        tierOrder: [String],
        records: [String: H2HRecord]
    ) -> H2HQuickResult {
        guard !undersampled.isEmpty else {
            return H2HQuickResult(tiers: tiers, artifacts: nil, suggestedPairs: [])
        }

        var updatedTiers = tiers
        let priors = buildPriors(from: baseTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
        updatedTiers["unranked", default: []] = orderedItems(undersampled, metrics: metrics)
        return H2HQuickResult(tiers: updatedTiers, artifacts: nil, suggestedPairs: [])
    }

    internal static func appendUndersampled(
        _ undersampled: [Item],
        to tiers: inout Items,
        records: [String: H2HRecord],
        priors: [String: Prior]
    ) {
        guard !undersampled.isEmpty else { return }
        let metrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
        tiers["unranked", default: []] = orderedItems(undersampled, metrics: metrics)
    }

    internal static func makeQuickArtifacts(
        ordered: [Item],
        undersampled: [Item],
        operativeNames: [String],
        cuts: [Int],
        metrics: [String: HeadToHeadMetrics]
    ) -> H2HArtifacts {
        let audits = buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth)
        return H2HArtifacts(
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
