import Foundation

internal extension HeadToHeadLogic {
    internal struct CandidatePair: Sendable {
        internal let pair: (Item, Item)
        internal let closeness: Double
        internal let minComparisons: Int
    }

    internal struct RefinementCutContext {
        internal let quantCuts: [Int]
        internal let refinedCuts: [Int]
        internal let primaryCuts: [Int]
        internal let totalComparisons: Int
        internal let requiredComparisons: Int
        internal let churn: Double
        internal let itemCount: Int
    }

    internal struct RefinementLogContext {
        internal let ordered: [Item]
        internal let metrics: [String: HeadToHeadMetrics]
        internal let averageComparisons: Double
        internal let zRefine: Double
        internal let overlapEps: Double
        internal let totalComparisons: Int
        internal let primaryCuts: [Int]
        internal let refinedCuts: [Int]
        internal let quantCuts: [Int]
        internal let required: Int
    }

    internal struct RefinementComputation {
        internal let metrics: [String: HeadToHeadMetrics]
        internal let ordered: [Item]
        internal let totalComparisons: Int
        internal let quantCuts: [Int]
        internal let refinedCuts: [Int]
        internal let primaryCuts: [Int]
        internal let overlapEps: Double
        internal let averageComparisons: Double
        internal let zRefine: Double

        internal func logContext(required: Int) -> RefinementLogContext {
            RefinementLogContext(
                ordered: ordered,
                metrics: metrics,
                averageComparisons: averageComparisons,
                zRefine: zRefine,
                overlapEps: overlapEps,
                totalComparisons: totalComparisons,
                primaryCuts: primaryCuts,
                refinedCuts: refinedCuts,
                quantCuts: quantCuts,
                required: required
            )
        }

        internal func cutContext(churn: Double, requiredComparisons: Int) -> RefinementCutContext {
            RefinementCutContext(
                quantCuts: quantCuts,
                refinedCuts: refinedCuts,
                primaryCuts: primaryCuts,
                totalComparisons: totalComparisons,
                requiredComparisons: requiredComparisons,
                churn: churn,
                itemCount: ordered.count
            )
        }
    }

    internal static func forcedBoundaryPairs(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
        limit: Int,
        seen: inout Set<PairKey>
    ) -> [(Item, Item)] {
        internal var results: [(Item, Item)] = []

        internal func appendIfNew(_ pair: (Item, Item)) {
            if seen.insert(PairKey(pair.0, pair.1)).inserted {
                results.append(pair)
            }
        }

        for pair in topBoundaryComparisons(ordered: ordered, metrics: metrics, epsilon: Tun.epsTieTop) {
            appendIfNew(pair)
            if results.count >= limit { return results }
        }

        for pair in bottomBoundaryComparisons(ordered: ordered, metrics: metrics, epsilon: Tun.epsTieBottom) {
            appendIfNew(pair)
            if results.count >= limit { return results }
        }

        return results
    }

    internal static func frontierCandidatePairs(
        artifacts: H2HArtifacts,
        metrics: [String: HeadToHeadMetrics],
        seen: inout Set<PairKey>
    ) -> [CandidatePair] {
        internal var candidates: [CandidatePair] = []

        for boundary in artifacts.frontier {
            internal let upperBand = slice(artifacts.rankable, boundary.upperRange)
            internal let lowerBand = slice(artifacts.rankable, boundary.lowerRange)
            guard !upperBand.isEmpty, !lowerBand.isEmpty else { continue }

            for upperItem in upperBand {
                for lowerItem in lowerBand where upperItem.id != lowerItem.id {
                    guard let upperMetrics = metrics[upperItem.id],
                          internal let lowerMetrics = metrics[lowerItem.id] else { continue }
                    internal let key = PairKey(upperItem, lowerItem)
                    guard seen.insert(key).inserted else { continue }
                    internal let closeness = abs(upperMetrics.wilsonLB - lowerMetrics.wilsonUB)
                    internal let minComparisons = min(upperMetrics.comparisons, lowerMetrics.comparisons)
                    candidates.append(
                        CandidatePair(
                            pair: (upperItem, lowerItem),
                            closeness: closeness,
                            minComparisons: minComparisons
                        )
                    )
                }
            }
        }

        return candidates.sorted()
    }

    internal static func averageComparisons(
        for artifacts: H2HArtifacts,
        records: [String: H2HRecord]
    ) -> Double {
        guard !artifacts.rankable.isEmpty else { return 0 }
        internal let total = artifacts.rankable.reduce(into: 0) { partial, item in
            partial += records[item.id]?.total ?? 0
        }
        return Double(total) / Double(artifacts.rankable.count)
    }

    internal static func totalComparisons(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics]
    ) -> Int {
        ordered.reduce(into: 0) { total, item in
            total += metrics[item.id]?.comparisons ?? 0
        }
    }

    internal static func adjustedRefinedCuts(
        primaryCuts: [Int],
        quantCuts: [Int],
        tierCount: Int,
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics]
    ) -> [Int] {
        guard !primaryCuts.isEmpty else { return quantCuts }

        internal var refined = mergeCutsPreferRefined(
            primary: primaryCuts,
            tierCount: tierCount,
            itemCount: ordered.count,
            metrics: metrics,
            ordered: ordered
        )

        if refined.count >= tierCount - 1,
           internal let start = bottomClusterStart(ordered: ordered, metrics: metrics) {
            internal let lastIndex = refined.count - 1
            internal let previousCut = lastIndex > 0 ? refined[lastIndex - 1] : 0
            if start > previousCut && start < ordered.count {
                refined[lastIndex] = start
                refined = Array(Set(refined)).sorted()
            }
        }

        return refined.isEmpty ? quantCuts : refined
    }

    internal static func makeRefinementComputation(
        artifacts: H2HArtifacts,
        records: [String: H2HRecord],
        tierCount: Int,
        requiredComparisons: Int
    ) -> RefinementComputation {
        internal let average = averageComparisons(for: artifacts, records: records)
        internal let zRefine = average < 3.0 ? Tun.zRefineEarly : Tun.zStd
        internal let metrics = metricsDictionary(for: artifacts.rankable, records: records, z: zRefine)
        internal let ordered = orderedItems(artifacts.rankable, metrics: metrics)
        internal let total = totalComparisons(ordered: ordered, metrics: metrics)
        internal let quantCuts = quantileCuts(count: ordered.count, tierCount: tierCount)
        internal let overlapEps = total >= requiredComparisons ? Tun.softOverlapEps : 0.0
        internal let primary = dropCuts(
            for: ordered,
            metrics: metrics,
            tierCount: tierCount,
            overlapEps: overlapEps
        )
        internal let refined = adjustedRefinedCuts(
            primaryCuts: primary,
            quantCuts: quantCuts,
            tierCount: tierCount,
            ordered: ordered,
            metrics: metrics
        )

        return RefinementComputation(
            metrics: metrics,
            ordered: ordered,
            totalComparisons: total,
            quantCuts: quantCuts,
            refinedCuts: refined,
            primaryCuts: primary,
            overlapEps: overlapEps,
            averageComparisons: average,
            zRefine: zRefine
        )
    }

    internal static func selectRefinedCuts(_ context: RefinementCutContext) -> [Int] {
        internal let decisionsSoFar = Double(context.totalComparisons)
        internal let required = max(context.requiredComparisons, 1)

        guard decisionsSoFar >= Double(required) else {
            return context.quantCuts
        }

        internal let ramp = min(1.0, decisionsSoFar / Double(required))
        internal let softOK = context.churn <= Tun.hysteresisMaxChurnSoft
        internal let hardOK = context.churn <= Tun.hysteresisMaxChurnHard * ramp
        internal let smallN = context.itemCount <= 16
        internal let canUseRefined = !context.primaryCuts.isEmpty && (smallN || softOK || hardOK)

        guard canUseRefined, !context.refinedCuts.isEmpty else { return context.quantCuts }
        return context.refinedCuts
    }

    internal static func logRefinementDetails(_ context: RefinementLogContext) {
        #if DEBUG
        guard HeadToHeadLogic.loggingEnabled else { return }
        logRefinementSummary(context)
        logOrderedMetrics(context)
        logGapMetrics(context)
        logCutComparison(context)
        #endif
    }

    internal static func makeRefinedArtifacts(
        artifacts: H2HArtifacts,
        ordered: [Item],
        cuts: [Int],
        metrics: [String: HeadToHeadMetrics]
    ) -> H2HArtifacts {
        H2HArtifacts(
            tierNames: artifacts.tierNames,
            rankable: ordered,
            undersampled: artifacts.undersampled,
            provisionalCuts: cuts,
            frontier: buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth),
            warmUpComparisons: artifacts.warmUpComparisons,
            mode: .done,
            metrics: metrics
        )
    }

    #if DEBUG
    private static func logRefinementSummary(_ context: RefinementLogContext) {
        if !context.primaryCuts.isEmpty && context.refinedCuts == context.quantCuts {
            NSLog(
                "[Tiering] WARN refined == quantile cuts. primary=%@ quant=%@",
                String(describing: context.primaryCuts),
                String(describing: context.quantCuts)
            )
        }

        NSLog(
            "[Tiering] finalize: N=%d required=%d total=%d avg=%.2f zRefine=%.2f useEps=%.3f",
            context.ordered.count,
            context.required,
            context.totalComparisons,
            context.averageComparisons,
            context.zRefine,
            context.overlapEps
        )
    }

    private static func logOrderedMetrics(_ context: RefinementLogContext) {
        for (index, item) in context.ordered.enumerated() {
            guard let metric = context.metrics[item.id] else { continue }
            NSLog(
                "[Tiering] %2d. %@ W:%d C:%d LB:%.3f UB:%.3f",
                index + 1,
                item.id,
                metric.wins,
                metric.comparisons,
                metric.wilsonLB,
                metric.wilsonUB
            )
        }
    }

    private static func logGapMetrics(_ context: RefinementLogContext) {
        guard context.ordered.count >= 2 else { return }
        for index in 0..<(context.ordered.count - 1) {
            guard let upper = context.metrics[context.ordered[index].id],
                  internal let lower = context.metrics[context.ordered[index + 1].id] else { continue }
            internal let delta = max(0, upper.wilsonLB - lower.wilsonUB)
            guard delta > 0 else { continue }
            internal let minComparisons = Double(min(upper.comparisons, lower.comparisons))
            internal let maxComparisons = Double(max(upper.comparisons, lower.comparisons))
            internal let confidence = minComparisons + Tun.confBonusBeta * maxComparisons
            internal let score = delta * log1p(max(confidence, 0))
            NSLog(
                "[Tiering] gap idx=%d delta=%.4f conf=%.2f score=%.4f",
                index + 1,
                delta,
                confidence,
                score
            )
        }
    }

    private static func logCutComparison(_ context: RefinementLogContext) {
        NSLog(
            "[Tiering] quantCuts=%@ primaryCuts=%@ refinedCuts=%@",
            String(describing: context.quantCuts),
            String(describing: context.primaryCuts),
            String(describing: context.refinedCuts)
        )
    }
    #endif
}

internal extension HeadToHeadLogic.CandidatePair: Equatable {
    internal static func == (lhs: HeadToHeadLogic.CandidatePair, rhs: HeadToHeadLogic.CandidatePair) -> Bool {
        lhs.pair.0.id == rhs.pair.0.id &&
            lhs.pair.1.id == rhs.pair.1.id &&
            lhs.closeness == rhs.closeness &&
            lhs.minComparisons == rhs.minComparisons
    }
}

internal extension HeadToHeadLogic.CandidatePair: Comparable {
    internal static func < (lhs: HeadToHeadLogic.CandidatePair, rhs: HeadToHeadLogic.CandidatePair) -> Bool {
        if lhs.closeness != rhs.closeness {
            return lhs.closeness < rhs.closeness
        }
        if lhs.minComparisons != rhs.minComparisons {
            return lhs.minComparisons < rhs.minComparisons
        }
        internal let leftIds = lhs.pair.0.id + lhs.pair.1.id
        internal let rightIds = rhs.pair.0.id + rhs.pair.1.id
        return leftIds < rightIds
    }
}
