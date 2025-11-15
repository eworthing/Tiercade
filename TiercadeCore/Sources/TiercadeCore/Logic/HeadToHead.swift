import Foundation

public struct HeadToHeadRecord: Sendable {
    public var wins: Int = 0
    public var losses: Int = 0
    public var total: Int { wins + losses }
    public var winRate: Double { total == 0 ? 0 : Double(wins) / Double(total) }
}

public enum HeadToHeadLogic {
    /// Controls diagnostic logging during refinement; set to `false` in tests to suppress noisy output.
    nonisolated(unsafe) public static var loggingEnabled: Bool = true

    // MARK: Pair generation & voting

    public static func pickPair(from pool: [Item], rng: () -> Double) -> (Item, Item)? {
        RandomUtils.pickRandomPair(pool, rng: rng)
    }

    public static func pairings(from pool: [Item], rng: () -> Double) -> [(Item, Item)] {
        guard pool.count >= 2 else { return [] }
        var combinations: [(Item, Item)] = []
        combinations.reserveCapacity(pool.count * (pool.count - 1) / 2)
        for i in 0..<(pool.count - 1) {
            let left = pool[i]
            for j in (i + 1)..<pool.count {
                combinations.append((left, pool[j]))
            }
        }
        guard combinations.count > 1 else { return combinations }
        var shuffled = combinations
        var idx = shuffled.count - 1
        while idx > 0 {
            let random = Int(floor(rng() * Double(idx + 1)))
            shuffled.swapAt(idx, random)
            idx -= 1
        }
        return shuffled
    }

    public static func vote(_ a: Item, _ b: Item, winner: Item, records: inout [String: HeadToHeadRecord]) {
        if winner.id == a.id {
            records[a.id, default: .init()].wins += 1
            records[b.id, default: .init()].losses += 1
        } else {
            records[b.id, default: .init()].wins += 1
            records[a.id, default: .init()].losses += 1
        }
    }

    // MARK: Two-phase tiering entry points

    public static func quickTierPass(
        from pool: [Item],
        records: [String: HeadToHeadRecord],
        tierOrder: [String],
        baseTiers: Items
    ) -> HeadToHeadQuickResult {
        guard !pool.isEmpty else {
            return HeadToHeadQuickResult(tiers: baseTiers, artifacts: nil, suggestedPairs: [])
        }

        let tierNames = normalizedTierNames(from: tierOrder)
        guard !tierNames.isEmpty else {
            return HeadToHeadQuickResult(tiers: baseTiers, artifacts: nil, suggestedPairs: [])
        }

        let (rankable, undersampled) = partitionByComparisons(
            pool,
            records: records,
            minimumComparisons: Tun.minimumComparisonsPerItem
        )

        var tiers = clearedTiers(baseTiers, removing: pool, tierNames: tierNames)
        guard !rankable.isEmpty else {
            return quickResultForUndersampled(
                tiers: tiers,
                undersampled: undersampled,
                baseTiers: baseTiers,
                tierOrder: tierOrder,
                records: records
            )
        }

        let priors = buildPriors(from: baseTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: rankable, records: records, z: Tun.zQuick, priors: priors)
        let ordered = orderedItems(rankable, metrics: metrics)
        let operativeNames = operativeTierNames(from: tierNames)
        let tierCount = operativeNames.count

        let cuts = quantileCuts(count: ordered.count, tierCount: tierCount)
        assignByCuts(ordered: ordered, cuts: cuts, tierNames: operativeNames, into: &tiers)
        sortTierMembers(&tiers, metrics: metrics, tierNames: operativeNames)

        appendUndersampled(undersampled, to: &tiers, records: records, priors: priors)

        let artifacts = makeQuickArtifacts(
            ordered: ordered,
            undersampled: undersampled,
            operativeNames: operativeNames,
            cuts: cuts,
            metrics: metrics
        )

        let suggested = refinementPairs(
            artifacts: artifacts,
            records: records,
            limit: suggestedPairLimit(for: artifacts)
        )

        return HeadToHeadQuickResult(tiers: tiers, artifacts: artifacts, suggestedPairs: suggested)
    }

    public static func refinementPairs(
        artifacts: HeadToHeadArtifacts,
        records: [String: HeadToHeadRecord],
        limit: Int
    ) -> [(Item, Item)] {
        guard artifacts.mode != .done,
              !artifacts.rankable.isEmpty,
              !artifacts.frontier.isEmpty,
              limit > 0 else { return [] }

        let metrics = metricsDictionary(for: artifacts.rankable, records: records, z: Tun.zQuick)
        let ordered = orderedItems(artifacts.rankable, metrics: metrics)

        var seen: Set<PairKey> = []
        var results = forcedBoundaryPairs(
            ordered: ordered,
            metrics: metrics,
            limit: limit,
            seen: &seen
        )

        guard results.count < limit else { return Array(results.prefix(limit)) }

        let candidates = frontierCandidatePairs(
            artifacts: artifacts,
            metrics: metrics,
            seen: &seen
        )

        let remaining = max(0, limit - results.count)
        results.append(contentsOf: candidates.prefix(remaining).map { $0.pair })

        return results
    }

    public static func initialComparisonQueueWarmStart(
        from pool: [Item],
        records: [String: HeadToHeadRecord],
        tierOrder: [String],
        currentTiers: Items,
        targetComparisonsPerItem: Int
    ) -> [(Item, Item)] {
        guard pool.count >= 2, targetComparisonsPerItem > 0 else { return [] }

        let priors = buildPriors(from: currentTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: pool, records: records, z: Tun.zQuick, priors: priors)
        let preparation = prepareWarmStart(
            pool: pool,
            tierOrder: tierOrder,
            currentTiers: currentTiers,
            metrics: metrics
        )

        var builder = WarmStartQueueBuilder(pool: pool, target: targetComparisonsPerItem)
        let frontierWidth = max(1, Tun.frontierWidth)

        if builder.enqueueBoundaryPairs(
            tierOrder: tierOrder,
            tiersByName: preparation.tiersByName,
            frontierWidth: frontierWidth
        ) {
            return builder.queue
        }

        if builder.enqueueUnranked(preparation.unranked, anchors: preparation.anchors) {
            return builder.queue
        }

        if builder.enqueueAdjacentPairs(in: preparation.tiersByName) {
            return builder.queue
        }

        builder.enqueueFallback(from: pool)
        return builder.queue
    }

    /// Chooses how many refinement pairs to surface, ensuring we can touch every active boundary at least once.
    private static func suggestedPairLimit(for artifacts: HeadToHeadArtifacts) -> Int {
        let cutsNeeded = max(artifacts.tierNames.count - 1, 1)
        return max(Tun.maxSuggestedPairs, cutsNeeded)
    }

    public static func finalizeTiers(
        artifacts: HeadToHeadArtifacts,
        records: [String: HeadToHeadRecord],
        tierOrder: [String],
        baseTiers: Items
    ) -> (tiers: Items, updatedArtifacts: HeadToHeadArtifacts) {
        guard !artifacts.rankable.isEmpty else {
            return (baseTiers, artifacts)
        }

        let tierNames = normalizedTierNames(from: tierOrder)
        var tiers = clearedTiers(
            baseTiers,
            removing: artifacts.rankable + artifacts.undersampled,
            tierNames: tierNames
        )

        let tierCount = artifacts.tierNames.count
        let computation = makeRefinementComputation(
            artifacts: artifacts,
            records: records,
            tierCount: tierCount,
            requiredComparisons: artifacts.warmUpComparisons
        )

        logRefinementDetails(computation.logContext(required: artifacts.warmUpComparisons))

        let quantMap = tierMapForCuts(ordered: computation.ordered, cuts: computation.quantCuts, tierCount: tierCount)
        let refinedMap = tierMapForCuts(
            ordered: computation.ordered,
            cuts: computation.refinedCuts,
            tierCount: tierCount
        )
        let churn = churnFraction(old: quantMap, new: refinedMap, universe: computation.ordered)

        let cuts = selectRefinedCuts(
            computation.cutContext(
                churn: churn,
                requiredComparisons: artifacts.warmUpComparisons
            )
        )

        assignByCuts(ordered: computation.ordered, cuts: cuts, tierNames: artifacts.tierNames, into: &tiers)
        sortTierMembers(&tiers, metrics: computation.metrics, tierNames: artifacts.tierNames)

        if !artifacts.undersampled.isEmpty {
            let unrankedKey = TierIdentifier.unranked.rawValue
            let undersampledMetrics = metricsDictionary(for: artifacts.undersampled, records: records, z: Tun.zStd)
            tiers[unrankedKey, default: []] = orderedItems(artifacts.undersampled, metrics: undersampledMetrics)
        }

        let updated = makeRefinedArtifacts(
            artifacts: artifacts,
            ordered: computation.ordered,
            cuts: cuts,
            metrics: computation.metrics
        )

        return (tiers, updated)
    }

    @available(*, deprecated, message: "Use quickTierPass / finalizeTiers for two-phase tiering")
    public static func rebuildTiers(
        from pool: [Item],
        records: [String: HeadToHeadRecord],
        tierOrder: [String],
        baseTiers: Items
    ) -> Items {
        let quick = quickTierPass(from: pool, records: records, tierOrder: tierOrder, baseTiers: baseTiers)
        guard let artifacts = quick.artifacts else {
            return quick.tiers
        }
        return finalizeTiers(artifacts: artifacts, records: records, tierOrder: tierOrder, baseTiers: baseTiers).tiers
    }
}

// MARK: - Public support types

public struct HeadToHeadQuickResult: Sendable {
    public let tiers: Items
    public let artifacts: HeadToHeadArtifacts?
    public let suggestedPairs: [(Item, Item)]
}

public struct HeadToHeadArtifacts: Sendable {
    public enum Mode: Sendable { case quick, done }

    public let tierNames: [String]
    public let rankable: [Item]
    public let undersampled: [Item]
    public let provisionalCuts: [Int]
    public let frontier: [HeadToHeadFrontier]
    public let warmUpComparisons: Int
    public let mode: Mode
    fileprivate let metrics: [String: HeadToHeadLogic.HeadToHeadMetrics]

    internal init(
        tierNames: [String],
        rankable: [Item],
        undersampled: [Item],
        provisionalCuts: [Int],
        frontier: [HeadToHeadFrontier],
        warmUpComparisons: Int,
        mode: Mode,
        metrics: [String: HeadToHeadLogic.HeadToHeadMetrics]
    ) {
        self.tierNames = tierNames
        self.rankable = rankable
        self.undersampled = undersampled
        self.provisionalCuts = provisionalCuts
        self.frontier = frontier
        self.warmUpComparisons = warmUpComparisons
        self.mode = mode
        self.metrics = metrics
    }
}

public struct HeadToHeadFrontier: Sendable {
    public let index: Int
    public let upperRange: Range<Int>
    public let lowerRange: Range<Int>
}
