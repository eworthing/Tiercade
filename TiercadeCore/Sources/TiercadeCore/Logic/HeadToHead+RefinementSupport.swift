import Foundation

extension HeadToHeadLogic {
    struct CandidatePair: Sendable {
        let pair: (Item, Item)
        let closeness: Double
        let minComparisons: Int
    }

    struct RefinementCutContext {
        let quantCuts: [Int]
        let refinedCuts: [Int]
        let primaryCuts: [Int]
        let totalComparisons: Int
        let requiredComparisons: Int
        let churn: Double
        let itemCount: Int
    }

    struct RefinementLogContext {
        let ordered: [Item]
        let metrics: [String: HeadToHeadMetrics]
        let averageComparisons: Double
        let zRefine: Double
        let overlapEps: Double
        let totalComparisons: Int
        let primaryCuts: [Int]
        let refinedCuts: [Int]
        let quantCuts: [Int]
        let required: Int
    }

    struct RefinementComputation {
        let metrics: [String: HeadToHeadMetrics]
        let ordered: [Item]
        let totalComparisons: Int
        let quantCuts: [Int]
        let refinedCuts: [Int]
        let primaryCuts: [Int]
        let overlapEps: Double
        let averageComparisons: Double
        let zRefine: Double

        func logContext(required: Int) -> RefinementLogContext {
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
                required: required,
            )
        }

        func cutContext(churn: Double, requiredComparisons: Int) -> RefinementCutContext {
            RefinementCutContext(
                quantCuts: quantCuts,
                refinedCuts: refinedCuts,
                primaryCuts: primaryCuts,
                totalComparisons: totalComparisons,
                requiredComparisons: requiredComparisons,
                churn: churn,
                itemCount: ordered.count,
            )
        }
    }

    static func forcedBoundaryPairs(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
        limit: Int,
        seen: inout Set<PairKey>,
    )
    -> [(Item, Item)] {
        var results: [(Item, Item)] = []

        func appendIfNew(_ pair: (Item, Item)) {
            if seen.insert(PairKey(pair.0, pair.1)).inserted {
                results.append(pair)
            }
        }

        for pair in topBoundaryComparisons(ordered: ordered, metrics: metrics, epsilon: Tun.epsTieTop) {
            appendIfNew(pair)
            if results.count >= limit {
                return results
            }
        }

        for pair in bottomBoundaryComparisons(ordered: ordered, metrics: metrics, epsilon: Tun.epsTieBottom) {
            appendIfNew(pair)
            if results.count >= limit {
                return results
            }
        }

        return results
    }

    static func frontierCandidatePairs(
        artifacts: HeadToHeadArtifacts,
        metrics: [String: HeadToHeadMetrics],
        seen: inout Set<PairKey>,
    )
    -> [CandidatePair] {
        var candidates: [CandidatePair] = []

        for boundary in artifacts.frontier {
            let upperBand = slice(artifacts.rankable, boundary.upperRange)
            let lowerBand = slice(artifacts.rankable, boundary.lowerRange)
            guard !upperBand.isEmpty, !lowerBand.isEmpty else {
                continue
            }

            for upperItem in upperBand {
                for lowerItem in lowerBand where upperItem.id != lowerItem.id {
                    guard
                        let upperMetrics = metrics[upperItem.id],
                        let lowerMetrics = metrics[lowerItem.id]
                    else {
                        continue
                    }
                    let key = PairKey(upperItem, lowerItem)
                    guard seen.insert(key).inserted else {
                        continue
                    }
                    let closeness = abs(upperMetrics.wilsonLB - lowerMetrics.wilsonUB)
                    let minComparisons = min(upperMetrics.comparisons, lowerMetrics.comparisons)
                    candidates.append(
                        CandidatePair(
                            pair: (upperItem, lowerItem),
                            closeness: closeness,
                            minComparisons: minComparisons,
                        ),
                    )
                }
            }
        }

        return candidates.sorted()
    }

    static func averageComparisons(
        for artifacts: HeadToHeadArtifacts,
        records: [String: HeadToHeadRecord],
    )
    -> Double {
        guard !artifacts.rankable.isEmpty else {
            return 0
        }
        let total = artifacts.rankable.reduce(into: 0) { partial, item in
            partial += records[item.id]?.total ?? 0
        }
        return Double(total) / Double(artifacts.rankable.count)
    }

    static func totalComparisons(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
    )
    -> Int {
        ordered.reduce(into: 0) { total, item in
            total += metrics[item.id]?.comparisons ?? 0
        }
    }

    static func adjustedRefinedCuts(
        primaryCuts: [Int],
        quantCuts: [Int],
        tierCount: Int,
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
    )
    -> [Int] {
        guard !primaryCuts.isEmpty else {
            return quantCuts
        }

        var refined = mergeCutsPreferRefined(
            primary: primaryCuts,
            tierCount: tierCount,
            itemCount: ordered.count,
            metrics: metrics,
            ordered: ordered,
        )

        if
            refined.count >= tierCount - 1,
            let start = bottomClusterStart(ordered: ordered, metrics: metrics)
        {
            let lastIndex = refined.count - 1
            let previousCut = lastIndex > 0 ? refined[lastIndex - 1] : 0
            if start > previousCut, start < ordered.count {
                refined[lastIndex] = start
                refined = Array(Set(refined)).sorted()
            }
        }

        return refined.isEmpty ? quantCuts : refined
    }

    static func makeRefinementComputation(
        artifacts: HeadToHeadArtifacts,
        records: [String: HeadToHeadRecord],
        tierCount: Int,
        requiredComparisons: Int,
    )
    -> RefinementComputation {
        let average = averageComparisons(for: artifacts, records: records)
        let zRefine = average < 3.0 ? Tun.zRefineEarly : Tun.zStd
        let metrics = metricsDictionary(for: artifacts.rankable, records: records, z: zRefine)
        let ordered = orderedItems(artifacts.rankable, metrics: metrics)
        let total = totalComparisons(ordered: ordered, metrics: metrics)
        let quantCuts = quantileCuts(count: ordered.count, tierCount: tierCount)
        let overlapEps = total >= requiredComparisons ? Tun.softOverlapEps : 0.0
        let primary = dropCuts(
            for: ordered,
            metrics: metrics,
            tierCount: tierCount,
            overlapEps: overlapEps,
        )
        let refined = adjustedRefinedCuts(
            primaryCuts: primary,
            quantCuts: quantCuts,
            tierCount: tierCount,
            ordered: ordered,
            metrics: metrics,
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
            zRefine: zRefine,
        )
    }

    static func selectRefinedCuts(_ context: RefinementCutContext) -> [Int] {
        let decisionsSoFar = Double(context.totalComparisons)
        let required = max(context.requiredComparisons, 1)

        guard decisionsSoFar >= Double(required) else {
            return context.quantCuts
        }

        let ramp = min(1.0, decisionsSoFar / Double(required))
        let softOK = context.churn <= Tun.hysteresisMaxChurnSoft
        let hardOK = context.churn <= Tun.hysteresisMaxChurnHard * ramp
        let smallN = context.itemCount <= 16
        let canUseRefined = !context.primaryCuts.isEmpty && (smallN || softOK || hardOK)

        guard canUseRefined, !context.refinedCuts.isEmpty else {
            return context.quantCuts
        }
        return context.refinedCuts
    }

    static func logRefinementDetails(_ context: RefinementLogContext) {
        #if DEBUG
        guard HeadToHeadLogic.loggingEnabled else {
            return
        }
        logRefinementSummary(context)
        logOrderedMetrics(context)
        logGapMetrics(context)
        logCutComparison(context)
        #endif
    }

    static func makeRefinedArtifacts(
        artifacts: HeadToHeadArtifacts,
        ordered: [Item],
        cuts: [Int],
        metrics: [String: HeadToHeadMetrics],
    )
    -> HeadToHeadArtifacts {
        HeadToHeadArtifacts(
            tierNames: artifacts.tierNames,
            rankable: ordered,
            undersampled: artifacts.undersampled,
            provisionalCuts: cuts,
            frontier: buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth),
            warmUpComparisons: artifacts.warmUpComparisons,
            mode: .done,
            metrics: metrics,
        )
    }

    #if DEBUG
    private static func logRefinementSummary(_ context: RefinementLogContext) {
        if !context.primaryCuts.isEmpty, context.refinedCuts == context.quantCuts {
            NSLog(
                "[Tiering] WARN refined == quantile cuts. primary=%@ quant=%@",
                String(describing: context.primaryCuts),
                String(describing: context.quantCuts),
            )
        }

        NSLog(
            "[Tiering] finalize: N=%d required=%d total=%d avg=%.2f zRefine=%.2f useEps=%.3f",
            context.ordered.count,
            context.required,
            context.totalComparisons,
            context.averageComparisons,
            context.zRefine,
            context.overlapEps,
        )
    }

    private static func logOrderedMetrics(_ context: RefinementLogContext) {
        for (index, item) in context.ordered.enumerated() {
            guard let metric = context.metrics[item.id] else {
                continue
            }
            NSLog(
                "[Tiering] %2d. %@ W:%d C:%d LB:%.3f UB:%.3f",
                index + 1,
                item.id,
                metric.wins,
                metric.comparisons,
                metric.wilsonLB,
                metric.wilsonUB,
            )
        }
    }

    private static func logGapMetrics(_ context: RefinementLogContext) {
        guard context.ordered.count >= 2 else {
            return
        }
        for index in 0 ..< (context.ordered.count - 1) {
            guard
                let upper = context.metrics[context.ordered[index].id],
                let lower = context.metrics[context.ordered[index + 1].id]
            else {
                continue
            }
            let delta = max(0, upper.wilsonLB - lower.wilsonUB)
            guard delta > 0 else {
                continue
            }
            let minComparisons = Double(min(upper.comparisons, lower.comparisons))
            let maxComparisons = Double(max(upper.comparisons, lower.comparisons))
            let confidence = minComparisons + Tun.confBonusBeta * maxComparisons
            let score = delta * log1p(max(confidence, 0))
            NSLog(
                "[Tiering] gap idx=%d delta=%.4f conf=%.2f score=%.4f",
                index + 1,
                delta,
                confidence,
                score,
            )
        }
    }

    private static func logCutComparison(_ context: RefinementLogContext) {
        NSLog(
            "[Tiering] quantCuts=%@ primaryCuts=%@ refinedCuts=%@",
            String(describing: context.quantCuts),
            String(describing: context.primaryCuts),
            String(describing: context.refinedCuts),
        )
    }
    #endif
}

// MARK: - HeadToHeadLogic.CandidatePair + Equatable

extension HeadToHeadLogic.CandidatePair: Equatable {
    static func == (lhs: HeadToHeadLogic.CandidatePair, rhs: HeadToHeadLogic.CandidatePair) -> Bool {
        lhs.pair.0.id == rhs.pair.0.id &&
            lhs.pair.1.id == rhs.pair.1.id &&
            lhs.closeness == rhs.closeness &&
            lhs.minComparisons == rhs.minComparisons
    }
}

// MARK: - HeadToHeadLogic.CandidatePair + Comparable

extension HeadToHeadLogic.CandidatePair: Comparable {
    static func < (lhs: HeadToHeadLogic.CandidatePair, rhs: HeadToHeadLogic.CandidatePair) -> Bool {
        if lhs.closeness != rhs.closeness {
            return lhs.closeness < rhs.closeness
        }
        if lhs.minComparisons != rhs.minComparisons {
            return lhs.minComparisons < rhs.minComparisons
        }
        let leftIds = lhs.pair.0.id + lhs.pair.1.id
        let rightIds = rhs.pair.0.id + rhs.pair.1.id
        return leftIds < rightIds
    }
}
