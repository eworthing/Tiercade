import Foundation

public struct H2HRecord: Sendable {
    public var wins: Int = 0
    public var losses: Int = 0
    public var total: Int { wins + losses }
    public var winRate: Double { total == 0 ? 0 : Double(wins) / Double(total) }
}

public enum HeadToHeadLogic {
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

    public static func vote(_ a: Item, _ b: Item, winner: Item, records: inout [String: H2HRecord]) {
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
        records: [String: H2HRecord],
        tierOrder: [String],
        baseTiers: Items
    ) -> H2HQuickResult {
        guard !pool.isEmpty else {
            return H2HQuickResult(tiers: baseTiers, artifacts: nil, suggestedPairs: [])
        }

        let tierNames = normalizedTierNames(from: tierOrder)
        guard !tierNames.isEmpty else {
            return H2HQuickResult(tiers: baseTiers, artifacts: nil, suggestedPairs: [])
        }

        let (rankable, undersampled) = partitionByComparisons(
            pool,
            records: records,
            minimumComparisons: Tun.minimumComparisonsPerItem
        )

        var tiers = clearedTiers(baseTiers, removing: pool, tierNames: tierNames)
        guard !rankable.isEmpty else {
            if !undersampled.isEmpty {
                let priors = buildPriors(from: baseTiers, tierOrder: tierOrder)
                let metrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
                tiers["unranked", default: []] = orderedItems(undersampled, metrics: metrics)
            }
            return H2HQuickResult(tiers: tiers, artifacts: nil, suggestedPairs: [])
        }

        let priors = buildPriors(from: baseTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: rankable, records: records, z: Tun.zQuick, priors: priors)
        let ordered = orderedItems(rankable, metrics: metrics)
        let operativeNames = operativeTierNames(from: tierNames)
        let tierCount = operativeNames.count

        let cuts = quantileCuts(count: ordered.count, tierCount: tierCount)
        assignByCuts(ordered: ordered, cuts: cuts, tierNames: operativeNames, into: &tiers)
        sortTierMembers(&tiers, metrics: metrics, tierNames: operativeNames)

        if !undersampled.isEmpty {
            let undersampledMetrics = metricsDictionary(for: undersampled, records: records, z: Tun.zQuick, priors: priors)
            tiers["unranked", default: []] = orderedItems(undersampled, metrics: undersampledMetrics)
        }

        let audits = buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth)
        let artifacts = H2HArtifacts(
            tierNames: operativeNames,
            rankable: ordered,
            undersampled: undersampled,
            provisionalCuts: cuts,
            frontier: audits,
            warmUpComparisons: warmUpComparisons(rankableCount: ordered.count, tierCount: tierCount),
            mode: .quick,
            metrics: metrics
        )

        let suggested = refinementPairs(
            artifacts: artifacts,
            records: records,
            limit: suggestedPairLimit(for: artifacts)
        )

        return H2HQuickResult(tiers: tiers, artifacts: artifacts, suggestedPairs: suggested)
    }

    public static func refinementPairs(
        artifacts: H2HArtifacts,
        records: [String: H2HRecord],
        limit: Int
    ) -> [(Item, Item)] {
        guard artifacts.mode != .done,
              !artifacts.rankable.isEmpty,
              !artifacts.frontier.isEmpty,
              limit > 0 else { return [] }

        let metrics = metricsDictionary(for: artifacts.rankable, records: records, z: Tun.zQuick)
        var forced: [(Item, Item)] = []
        var seen: Set<String> = []

        func pairKey(_ a: Item, _ b: Item) -> String {
            let ids = [a.id, b.id].sorted()
            return ids[0] + "#" + ids[1]
        }

        for pair in topBoundaryComparisons(ordered: artifacts.rankable, metrics: metrics, epsilon: Tun.epsTieTop) {
            let key = pairKey(pair.0, pair.1)
            guard seen.insert(key).inserted else { continue }
            forced.append(pair)
            if forced.count >= limit { return forced }
        }

        for pair in bottomBoundaryComparisons(ordered: artifacts.rankable, metrics: metrics, epsilon: Tun.epsTieBottom) {
            let key = pairKey(pair.0, pair.1)
            guard seen.insert(key).inserted else { continue }
            forced.append(pair)
            if forced.count >= limit { return forced }
        }

        var pairs: [(Item, Item, Double, Int)] = []

        for boundary in artifacts.frontier {
            let upperBand = slice(artifacts.rankable, boundary.upperRange)
            let lowerBand = slice(artifacts.rankable, boundary.lowerRange)
            guard !upperBand.isEmpty, !lowerBand.isEmpty else { continue }
            for u in upperBand {
                for l in lowerBand where u.id != l.id {
                    guard let mu = metrics[u.id], let ml = metrics[l.id] else { continue }
                    let closeness = abs(mu.wilsonLB - ml.wilsonUB)
                    let minComparisons = min(mu.comparisons, ml.comparisons)
                    let key = pairKey(u, l)
                    guard seen.insert(key).inserted else { continue }
                    pairs.append((u, l, closeness, minComparisons))
                }
            }
        }

        let sorted = pairs.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 < rhs.2 }
            return lhs.3 < rhs.3
        }

        var output = forced
        for candidate in sorted {
            guard output.count < limit else { break }
            output.append((candidate.0, candidate.1))
        }

        return output
    }

    public static func initialComparisonQueueWarmStart(
        from pool: [Item],
        records: [String: H2HRecord],
        tierOrder: [String],
        currentTiers: Items,
        targetComparisonsPerItem: Int
    ) -> [(Item, Item)] {
        guard pool.count >= 2, targetComparisonsPerItem > 0 else { return [] }

        let poolById = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        let priors = buildPriors(from: currentTiers, tierOrder: tierOrder)
        let metrics = metricsDictionary(for: pool, records: records, z: Tun.zQuick, priors: priors)

        var tiersByName: [String: [Item]] = [:]
        var accounted: Set<String> = []
        for name in tierOrder {
            let members = (currentTiers[name] ?? []).compactMap { poolById[$0.id] }
            let orderedMembers = orderedItems(members, metrics: metrics)
            tiersByName[name] = orderedMembers
            accounted.formUnion(orderedMembers.map(\.id))
        }

        var unranked = (currentTiers["unranked"] ?? []).compactMap { poolById[$0.id] }
        accounted.formUnion(unranked.map(\.id))
        let loose = pool.filter { !accounted.contains($0.id) }
        unranked.append(contentsOf: loose)

        var counts: [String: Int] = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, 0) })
        var seen: Set<String> = []
        var queue: [(Item, Item)] = []

        func pairKey(_ a: Item, _ b: Item) -> String {
            let ids = [a.id, b.id].sorted()
            return ids[0] + "#" + ids[1]
        }

        func needsMore(_ item: Item) -> Bool {
            counts[item.id, default: 0] < targetComparisonsPerItem
        }

        func canPush(_ a: Item, _ b: Item) -> Bool {
            guard a.id != b.id else { return false }
            let key = pairKey(a, b)
            guard !seen.contains(key) else { return false }
            return needsMore(a) || needsMore(b)
        }

        func push(_ a: Item, _ b: Item) {
            guard canPush(a, b) else { return }
            queue.append((a, b))
            seen.insert(pairKey(a, b))
            counts[a.id, default: 0] += 1
            counts[b.id, default: 0] += 1
        }

        func allSatisfied() -> Bool {
            counts.values.allSatisfy { $0 >= targetComparisonsPerItem }
        }

        let frontierWidth = max(1, Tun.frontierWidth)

        for index in 0..<(tierOrder.count - 1) {
            guard let upper = tiersByName[tierOrder[index]],
                  let lower = tiersByName[tierOrder[index + 1]],
                  !upper.isEmpty, !lower.isEmpty else { continue }

            let upperTail = Array(upper.suffix(min(frontierWidth, upper.count)))
            let lowerHead = Array(lower.prefix(min(frontierWidth, lower.count)))
            for u in upperTail {
                for l in lowerHead {
                    push(u, l)
                    if allSatisfied() { return queue }
                }
            }
        }

        var anchors: [Item] = []
        for index in 0..<(tierOrder.count - 1) {
            guard let upper = tiersByName[tierOrder[index]],
                  let lower = tiersByName[tierOrder[index + 1]],
                  !upper.isEmpty, !lower.isEmpty else { continue }
            anchors.append(contentsOf: upper.suffix(min(frontierWidth, upper.count)))
            anchors.append(contentsOf: lower.prefix(min(frontierWidth, lower.count)))
        }
        if anchors.isEmpty {
            anchors = pool
        }

        for item in unranked {
            var added = 0
            for anchor in anchors {
                push(item, anchor)
                if allSatisfied() { return queue }
                added += 1
                if added >= 2 { break }
            }
        }

        for name in tierOrder {
            guard let items = tiersByName[name], items.count >= 2 else { continue }
            for idx in 0..<(items.count - 1) {
                push(items[idx], items[idx + 1])
                if allSatisfied() { return queue }
            }
        }

        let fallbackPairs = pairings(from: pool, rng: { Double.random(in: 0...1) })
        for pair in fallbackPairs {
            push(pair.0, pair.1)
            if allSatisfied() { break }
        }

        return queue
    }

    /// Chooses how many refinement pairs to surface, ensuring we can touch every active boundary at least once.
    private static func suggestedPairLimit(for artifacts: H2HArtifacts) -> Int {
        let cutsNeeded = max(artifacts.tierNames.count - 1, 1)
        return max(Tun.maxSuggestedPairs, cutsNeeded)
    }

    public static func finalizeTiers(
        artifacts: H2HArtifacts,
        records: [String: H2HRecord],
        tierOrder: [String],
        baseTiers: Items
    ) -> (tiers: Items, updatedArtifacts: H2HArtifacts) {
        guard !artifacts.rankable.isEmpty else {
            return (baseTiers, artifacts)
        }

        let tierNames = normalizedTierNames(from: tierOrder)
        var tiers = clearedTiers(baseTiers, removing: artifacts.rankable + artifacts.undersampled, tierNames: tierNames)

        let totalComparisonSum = artifacts.rankable.reduce(into: 0) { partial, item in
            partial += records[item.id]?.total ?? 0
        }
        let averageComparisons = Double(totalComparisonSum) / Double(max(artifacts.rankable.count, 1))
        let zRefine = averageComparisons < 3.0 ? Tun.zRefineEarly : Tun.zStd

        let metrics = metricsDictionary(for: artifacts.rankable, records: records, z: zRefine)
        let ordered = orderedItems(artifacts.rankable, metrics: metrics)

        let totalComparisons = ordered.reduce(into: 0) { partial, item in
            partial += metrics[item.id]?.comparisons ?? 0
        }

        let tierCount = artifacts.tierNames.count
        let quantCuts = quantileCuts(count: ordered.count, tierCount: tierCount)
        let useOverlapEps = totalComparisons >= artifacts.warmUpComparisons ? Tun.softOverlapEps : 0.0
        let primaryCuts = dropCuts(
            for: ordered,
            metrics: metrics,
            tierCount: tierCount,
            overlapEps: useOverlapEps
        )
        var refinedCuts = mergeCutsPreferRefined(
            primary: primaryCuts,
            tierCount: tierCount,
            itemCount: ordered.count,
            metrics: metrics,
            ordered: ordered
        )

        if refinedCuts.count >= tierCount - 1,
           let start = bottomClusterStart(ordered: ordered, metrics: metrics) {
            let lastCutIndex = refinedCuts.count - 1
            let previousCut = lastCutIndex > 0 ? refinedCuts[lastCutIndex - 1] : 0
            if start > previousCut && start < ordered.count {
                refinedCuts[lastCutIndex] = start
                refinedCuts = Array(Set(refinedCuts)).sorted()
            }
        }

#if DEBUG
        if !primaryCuts.isEmpty && refinedCuts == quantCuts {
            NSLog("[Tiering] WARN refined == quantile cuts. primary=%@ quant=%@", String(describing: primaryCuts), String(describing: quantCuts))
        }

        NSLog(
            "[Tiering] finalize: N=%d required=%d total=%d avg=%.2f zRefine=%.2f useEps=%.3f",
            ordered.count,
            artifacts.warmUpComparisons,
            totalComparisons,
            averageComparisons,
            zRefine,
            useOverlapEps
        )
        for (index, item) in ordered.enumerated() {
            if let metric = metrics[item.id] {
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

        for index in 0..<(ordered.count - 1) {
            if let upper = metrics[ordered[index].id], let lower = metrics[ordered[index + 1].id] {
                let delta = max(0, upper.wilsonLB - lower.wilsonUB)
                guard delta > 0 else { continue }
                let minC = Double(min(upper.comparisons, lower.comparisons))
                let maxC = Double(max(upper.comparisons, lower.comparisons))
                let conf = minC + Tun.confBonusBeta * maxC
                let score = delta * log1p(max(conf, 0))
                NSLog("[Tiering] gap idx=%d delta=%.4f conf=%.2f score=%.4f", index + 1, delta, conf, score)
            }
        }
#endif

        let quantMap = tierMapForCuts(ordered: ordered, cuts: quantCuts, tierCount: tierCount)
        let refinedMap = tierMapForCuts(ordered: ordered, cuts: refinedCuts, tierCount: tierCount)
        let churn = churnFraction(old: quantMap, new: refinedMap, universe: ordered)

        let requiredComparisons = artifacts.warmUpComparisons
        let decisionsSoFar = Double(totalComparisons)
        let ramp = min(1.0, decisionsSoFar / Double(max(requiredComparisons, 1)))
        let softOK = churn <= Tun.hysteresisMaxChurnSoft
        let hardOK = churn <= Tun.hysteresisMaxChurnHard * ramp
        let smallN = ordered.count <= 16
        let canUseRefined = !primaryCuts.isEmpty && (smallN || softOK || hardOK)

        let cuts: [Int]
#if DEBUG
        NSLog("[Tiering] churn=%.3f decisions=%d required=%d useRefined=%@", churn, Int(decisionsSoFar), requiredComparisons, String(canUseRefined))
        NSLog(
            "[Tiering] quantCuts=%@ primaryCuts=%@ refinedCuts=%@",
            String(describing: quantCuts),
            String(describing: primaryCuts),
            String(describing: refinedCuts)
        )
#endif
        if decisionsSoFar < Double(requiredComparisons) {
            cuts = quantCuts
        } else {
            cuts = canUseRefined ? refinedCuts : quantCuts
        }

        assignByCuts(ordered: ordered, cuts: cuts, tierNames: artifacts.tierNames, into: &tiers)
        sortTierMembers(&tiers, metrics: metrics, tierNames: artifacts.tierNames)

        if !artifacts.undersampled.isEmpty {
            let undersampledMetrics = metricsDictionary(for: artifacts.undersampled, records: records, z: Tun.zStd)
            tiers["unranked", default: []] = orderedItems(artifacts.undersampled, metrics: undersampledMetrics)
        }

        let updated = H2HArtifacts(
            tierNames: artifacts.tierNames,
            rankable: ordered,
            undersampled: artifacts.undersampled,
            provisionalCuts: cuts,
            frontier: buildAudits(orderedCount: ordered.count, cuts: cuts, width: Tun.frontierWidth),
            warmUpComparisons: artifacts.warmUpComparisons,
            mode: .done,
            metrics: metrics
        )

        return (tiers, updated)
    }

    @available(*, deprecated, message: "Use quickTierPass / finalizeTiers for two-phase tiering")
    public static func rebuildTiers(
        from pool: [Item],
        records: [String: H2HRecord],
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

public struct H2HQuickResult: Sendable {
    public let tiers: Items
    public let artifacts: H2HArtifacts?
    public let suggestedPairs: [(Item, Item)]
}

public struct H2HArtifacts: Sendable {
    public enum Mode: Sendable { case quick, done }

    public let tierNames: [String]
    public let rankable: [Item]
    public let undersampled: [Item]
    public let provisionalCuts: [Int]
    public let frontier: [H2HFrontier]
    public let warmUpComparisons: Int
    public let mode: Mode
    fileprivate let metrics: [String: HeadToHeadMetrics]
}

public struct H2HFrontier: Sendable {
    public let index: Int
    public let upperRange: Range<Int>
    public let lowerRange: Range<Int>
}

// MARK: - Internal data & helpers

fileprivate enum Tun {
    /// Upper cap for tiers we actively maintain (kept in sync with UI design language).
    static let maximumTierCount = 20
    /// Minimum number of recorded matchups before an item participates in tier placement.
    static let minimumComparisonsPerItem = 2
    /// Number of neighbours sampled above/below a boundary when proposing refinement pairs.
    static let frontierWidth = 2
    /// Wilson z-score used during the quick pass (≈68% interval) to keep early rankings flexible.
    static let zQuick: Double = 1.0
    /// Wilson z-score used once head-to-head data becomes dense enough during refinement.
    static let zStd: Double = 1.28
    /// Wilson z-score used for refinement metrics when data is still sparse.
    static let zRefineEarly: Double = 1.0
    /// Allow tiny overlaps to count as separation once warm-up is satisfied.
    static let softOverlapEps: Double = 0.010
    /// Bonus used in gap scoring when one neighbour is highly sampled.
    static let confBonusBeta: Double = 0.10
    /// Baseline number of refinement pairs we request regardless of tier count.
    static let maxSuggestedPairs = 6
    /// Hysteresis thresholds for adopting refined tiers.
    static let hysteresisMaxChurnSoft: Double = 0.12
    static let hysteresisMaxChurnHard: Double = 0.25
    static let hysteresisRampBoost: Double = 0.50
    /// Don’t split very flat segments when backfilling refined cuts.
    static let minWilsonRangeForSplit: Double = 0.015
    /// Threshold for considering top-ranked items effectively tied on the Wilson lower bound.
    static let epsTieTop: Double = 0.012
    /// Threshold for treating bottom-ranked items as effectively tied (UB proximity).
    static let epsTieBottom: Double = 0.010
    /// Maximum number of items we allow in a bottom cluster when sliding the last cut.
    static let maxBottomTieWidth: Int = 4
    /// Consider items "clearly weak" when their upper bound falls below this ceiling.
    static let ubBottomCeil: Double = 0.20
}

fileprivate enum TieringGuard {
    /// Avoid micro-tiers produced by filler splits.
    static let minSegmentSizeToSplit: Int = 3
}

// MARK: - Warm-start priors

fileprivate struct Prior: Sendable {
    let alpha: Double
    let beta: Double
}

fileprivate func priorMeanForTier(_ name: String, index: Int, total: Int) -> Double {
    let defaults: [String: Double] = [
        "S": 0.85,
        "A": 0.75,
        "B": 0.65,
        "C": 0.55,
        "D": 0.45,
        "E": 0.40,
        "F": 0.35
    ]
    if let value = defaults[name] { return value }
    let top = 0.85, bottom = 0.35
    let denom = max(1, total - 1)
    return top - (top - bottom) * (Double(index) / Double(denom))
}

fileprivate func buildPriors(
    from currentTiers: Items,
    tierOrder: [String],
    strength: Double = 6.0
) -> [String: Prior] {
    var output: [String: Prior] = [:]
    for (index, name) in tierOrder.enumerated() {
        guard let members = currentTiers[name], !members.isEmpty else { continue }
        let mean = priorMeanForTier(name, index: index, total: tierOrder.count)
        let alpha = max(0, mean * strength)
        let beta = max(0, (1.0 - mean) * strength)
        for item in members {
            output[item.id] = Prior(alpha: alpha, beta: beta)
        }
    }
    return output
}

// MARK: - Wilson score helpers (Double counts)

fileprivate func wilsonLowerBoundD(wins: Double, total: Double, z: Double) -> Double {
    guard total > 0 else { return 0 }
    let p = wins / total
    let z2 = z * z
    let denom = 1.0 + z2 / total
    let center = p + z2 / (2.0 * total)
    let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
    return max(0, (center - margin) / denom)
}

fileprivate func wilsonUpperBoundD(wins: Double, total: Double, z: Double) -> Double {
    guard total > 0 else { return 0 }
    let p = wins / total
    let z2 = z * z
    let denom = 1.0 + z2 / total
    let center = p + z2 / (2.0 * total)
    let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
    return min(1, (center + margin) / denom)
}

fileprivate struct HeadToHeadMetrics: Sendable {
    let wins: Int
    let comparisons: Int
    let winRate: Double
    let wilsonLB: Double
    let wilsonUB: Double
    let nameKey: String
    let id: String
}

fileprivate func warmUpComparisons(rankableCount n: Int, tierCount k: Int) -> Int {
    max(Int(ceil(1.5 * Double(n))), 2 * k)
}

fileprivate func partitionByComparisons(
    _ pool: [Item],
    records: [String: H2HRecord],
    minimumComparisons: Int
) -> (rankable: [Item], undersampled: [Item]) {
    var rankable: [Item] = []
    var undersampled: [Item] = []
    for item in pool {
        if (records[item.id]?.total ?? 0) >= minimumComparisons {
            rankable.append(item)
        } else {
            undersampled.append(item)
        }
    }
    return (rankable, undersampled)
}

fileprivate func normalizedTierNames(from tierOrder: [String]) -> [String] {
    tierOrder
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

fileprivate func clearedTiers(_ base: Items, removing pool: [Item], tierNames: [String]) -> Items {
    var updated = base
    let poolIds = Set(pool.map(\.id))

    for name in tierNames {
        updated[name] = []
    }
    for key in updated.keys where key != "unranked" && !tierNames.contains(key) {
        updated[key]?.removeAll { poolIds.contains($0.id) }
    }
    if var unranked = updated["unranked"] {
        unranked.removeAll { poolIds.contains($0.id) }
        updated["unranked"] = unranked
    }
    return updated
}

fileprivate func operativeTierNames(from tierNames: [String]) -> [String] {
    guard tierNames.count >= 2 else { return tierNames }
    return Array(tierNames.prefix(Tun.maximumTierCount))
}

fileprivate func metricsDictionary(
    for items: [Item],
    records: [String: H2HRecord],
    z: Double,
    priors: [String: Prior]
) -> [String: HeadToHeadMetrics] {
    Dictionary(uniqueKeysWithValues: items.map { item in
        let record = records[item.id] ?? H2HRecord()
        let prior = priors[item.id] ?? Prior(alpha: 0, beta: 0)
        let effectiveWins = Double(record.wins) + prior.alpha
        let effectiveLosses = Double(record.losses) + prior.beta
        let effectiveTotal = effectiveWins + effectiveLosses
        let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keySource = (displayName?.isEmpty == false ? displayName! : item.id)
        return (
            item.id,
            HeadToHeadMetrics(
                wins: record.wins,
                comparisons: record.total,
                winRate: record.total == 0 ? 0 : Double(record.wins) / Double(record.total),
                wilsonLB: wilsonLowerBoundD(wins: effectiveWins, total: effectiveTotal, z: z),
                wilsonUB: wilsonUpperBoundD(wins: effectiveWins, total: effectiveTotal, z: z),
                nameKey: keySource.lowercased(),
                id: item.id
            )
        )
    })
}

fileprivate func metricsDictionary(
    for items: [Item],
    records: [String: H2HRecord],
    z: Double
) -> [String: HeadToHeadMetrics] {
    Dictionary(uniqueKeysWithValues: items.map { item in
        let record = records[item.id] ?? H2HRecord()
        let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keySource = (displayName?.isEmpty == false ? displayName! : item.id)
        return (
            item.id,
            HeadToHeadMetrics(
                wins: record.wins,
                comparisons: record.total,
                winRate: record.winRate,
                wilsonLB: wilsonLowerBound(wins: record.wins, total: record.total, z: z),
                wilsonUB: wilsonUpperBound(wins: record.wins, total: record.total, z: z),
                nameKey: keySource.lowercased(),
                id: item.id
            )
        )
    })
}

fileprivate func orderedItems(_ items: [Item], metrics: [String: HeadToHeadMetrics]) -> [Item] {
    items.sorted { lhs, rhs in
        guard let L = metrics[lhs.id], let R = metrics[rhs.id] else { return lhs.id < rhs.id }
        if L.wilsonLB != R.wilsonLB { return L.wilsonLB > R.wilsonLB }
        if L.comparisons != R.comparisons { return L.comparisons > R.comparisons }
        if L.wins != R.wins { return L.wins > R.wins }
        if L.nameKey != R.nameKey { return L.nameKey < R.nameKey }
        return L.id < R.id
    }
}

fileprivate func quantileCuts(count n: Int, tierCount k: Int) -> [Int] {
    guard k > 1, n > 1 else { return [] }
    var cuts: [Int] = []
    for i in 1..<k {
        let position = Int(round(Double(i) * Double(n) / Double(k)))
        if position > 0 && position < n {
            cuts.append(position)
        }
    }
    return Array(Set(cuts)).sorted()
}

fileprivate func buildAudits(orderedCount n: Int, cuts: [Int], width w: Int) -> [H2HFrontier] {
    cuts.map { cut in
        let upper = max(0, cut - w)..<cut
        let lower = cut..<min(n, cut + w)
        return H2HFrontier(index: cut, upperRange: upper, lowerRange: lower)
    }
}

fileprivate func slice<T>(_ array: [T], _ range: Range<Int>) -> [T] {
    guard !array.isEmpty else { return [] }
    let lower = max(0, range.lowerBound)
    let upper = min(array.count, range.upperBound)
    guard lower < upper else { return [] }
    return Array(array[lower..<upper])
}

fileprivate func assignByCuts(
    ordered: [Item],
    cuts: [Int],
    tierNames: [String],
    into tiers: inout Items
) {
    var tierIndex = 0
    var cursor = 0
    for (idx, item) in ordered.enumerated() {
        while cursor < cuts.count && idx >= cuts[cursor] {
            tierIndex += 1
            cursor += 1
        }
        let tierName = tierNames[min(tierIndex, tierNames.count - 1)]
        tiers[tierName, default: []].append(item)
    }
}

fileprivate func sortTierMembers(
    _ tiers: inout Items,
    metrics: [String: HeadToHeadMetrics],
    tierNames: [String]
) {
    for name in tierNames {
        if let members = tiers[name] {
            tiers[name] = orderedItems(members, metrics: metrics)
        }
    }
}

fileprivate func dropCuts(
    for ordered: [Item],
    metrics: [String: HeadToHeadMetrics],
    tierCount: Int,
    overlapEps: Double
) -> [Int] {
    guard tierCount > 1, ordered.count >= 2 else { return [] }
    var scored: [(Int, Double)] = []
    for idx in 0..<(ordered.count - 1) {
        guard let upper = metrics[ordered[idx].id],
              let lower = metrics[ordered[idx + 1].id] else { continue }
        let raw = (upper.wilsonLB - lower.wilsonUB) + overlapEps
        let delta = max(0, raw)
        if delta <= 0 { continue }
        let minC = Double(min(upper.comparisons, lower.comparisons))
        let maxC = Double(max(upper.comparisons, lower.comparisons))
        let conf = minC + Tun.confBonusBeta * maxC
        let score = delta * log1p(max(conf, 0))
        if score > 0 {
            scored.append((idx + 1, score))
        }
    }
    guard !scored.isEmpty else { return [] }
    let sorted = scored.sorted { $0.1 > $1.1 }
    return Array(sorted.prefix(tierCount - 1)).map { $0.0 }.sorted()
}

fileprivate func wilsonRange(
    ordered: [Item],
    range: Range<Int>,
    metrics: [String: HeadToHeadMetrics]
) -> Double {
    guard !ordered.isEmpty, !range.isEmpty else { return 0 }
    let lower = max(0, range.lowerBound)
    let upper = min(ordered.count, range.upperBound)
    guard lower < upper else { return 0 }
    var minValue = 1.0
    var maxValue = 0.0
    for index in lower..<upper {
        if let metric = metrics[ordered[index].id] {
            minValue = min(minValue, metric.wilsonLB)
            maxValue = max(maxValue, metric.wilsonLB)
        }
    }
    return maxValue - minValue
}

fileprivate func fillMissingCutsWithGuards(
    primary: [Int],
    tierCount: Int,
    itemCount: Int,
    metrics: [String: HeadToHeadMetrics],
    ordered: [Item]
) -> [Int] {
    guard tierCount > 1, itemCount > 1 else { return [] }
    var picks = Set(primary).filter { $0 > 0 && $0 < itemCount }

    while picks.count < tierCount - 1 {
        let segments = contiguousSegments(n: itemCount, cuts: Array(picks))
        guard let largestSegment = segments.max(by: { $0.count < $1.count }) else { break }
        if largestSegment.count < TieringGuard.minSegmentSizeToSplit { break }
        let spread = wilsonRange(ordered: ordered, range: largestSegment, metrics: metrics)
        if spread < Tun.minWilsonRangeForSplit { break }

        let midpoint = largestSegment.lowerBound + largestSegment.count / 2
        if midpoint > largestSegment.lowerBound && midpoint < largestSegment.upperBound {
            picks.insert(midpoint)
        } else {
            break
        }
    }

    return Array(picks).sorted()
}

fileprivate func mergeCutsPreferRefined(
    primary: [Int],
    tierCount: Int,
    itemCount: Int,
    metrics: [String: HeadToHeadMetrics],
    ordered: [Item]
) -> [Int] {
    fillMissingCutsWithGuards(
        primary: primary,
        tierCount: tierCount,
        itemCount: itemCount,
        metrics: metrics,
        ordered: ordered
    )
}

fileprivate func bottomClusterStart(
    ordered: [Item],
    metrics: [String: HeadToHeadMetrics]
) -> Int? {
    guard ordered.count >= 2,
          let lastMetric = metrics[ordered.last!.id] else { return nil }

    let baseUB = lastMetric.wilsonUB
    let lowerBound = max(0, ordered.count - Tun.maxBottomTieWidth)
    var start = ordered.count - 1

    for index in stride(from: ordered.count - 2, through: lowerBound, by: -1) {
        guard let metric = metrics[ordered[index].id] else { break }
        let closeUB = abs(metric.wilsonUB - baseUB) <= Tun.epsTieBottom
        let bothWeak = metric.wilsonUB <= Tun.ubBottomCeil && baseUB <= Tun.ubBottomCeil
        if closeUB || bothWeak {
            start = index
        } else {
            break
        }
    }

    return start == ordered.count - 1 ? nil : start
}

fileprivate func contiguousSegments(n: Int, cuts: [Int]) -> [Range<Int>] {
    guard n > 0 else { return [] }
    let sortedCuts = cuts.sorted()
    var segments: [Range<Int>] = []
    var start = 0
    for cut in sortedCuts {
        let clamped = min(max(cut, 0), n)
        segments.append(start..<clamped)
        start = clamped
    }
    segments.append(start..<n)
    return segments
}

fileprivate func topBoundaryComparisons(
    ordered: [Item],
    metrics: [String: HeadToHeadMetrics],
    epsilon: Double
) -> [(Item, Item)] {
    guard ordered.count >= 3, epsilon > 0 else { return [] }
    guard let second = metrics[ordered[1].id],
          let third = metrics[ordered[2].id] else { return [] }

    let delta23 = abs(second.wilsonLB - third.wilsonLB)
    guard delta23 <= epsilon else { return [] }

    var results: [(Item, Item)] = [(ordered[1], ordered[2])]

    if let first = metrics[ordered[0].id] {
        let delta13 = abs(first.wilsonLB - third.wilsonLB)
        if delta13 <= epsilon {
            results.append((ordered[0], ordered[2]))
        }
    }

    return results
}

fileprivate func bottomBoundaryComparisons(
    ordered: [Item],
    metrics: [String: HeadToHeadMetrics],
    epsilon: Double
) -> [(Item, Item)] {
    guard ordered.count >= 2 else { return [] }
    let lastIndex = ordered.count - 1
    guard let last = metrics[ordered[lastIndex].id],
          metrics[ordered[lastIndex - 1].id] != nil else { return [] }

    var results: [(Item, Item)] = [
        (ordered[lastIndex - 1], ordered[lastIndex])
    ]

    if ordered.count >= 3,
       let third = metrics[ordered[lastIndex - 2].id] {
        let closeUB = abs(third.wilsonUB - last.wilsonUB) <= epsilon
        let bothWeak = third.wilsonUB <= Tun.ubBottomCeil && last.wilsonUB <= Tun.ubBottomCeil
        if closeUB || bothWeak {
            results.append((ordered[lastIndex - 2], ordered[lastIndex]))
        }
    }

    return results
}

fileprivate func tierMapForCuts(
    ordered: [Item],
    cuts: [Int],
    tierCount: Int
) -> [String: Int] {
    var map: [String: Int] = [:]
    map.reserveCapacity(ordered.count)
    var tierIndex = 0
    var cursor = 0
    for (index, item) in ordered.enumerated() {
        while cursor < cuts.count && index >= cuts[cursor] {
            tierIndex += 1
            cursor += 1
        }
        map[item.id] = min(tierIndex + 1, tierCount)
    }
    return map
}

fileprivate func churnFraction(
    old: [String: Int],
    new: [String: Int],
    universe: [Item]
) -> Double {
    guard !universe.isEmpty else { return 0 }
    var moved = 0
    for item in universe {
        if (old[item.id] ?? 0) != (new[item.id] ?? 0) {
            moved += 1
        }
    }
    return Double(moved) / Double(universe.count)
}

fileprivate func wilsonLowerBound(wins: Int, total: Int, z: Double) -> Double {
    guard total > 0 else { return 0 }
    let p = Double(wins) / Double(total)
    let z2 = z * z
    let denom = 1.0 + z2 / Double(total)
    let center = p + z2 / (2.0 * Double(total))
    let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
    return max(0, (center - margin) / denom)
}

fileprivate func wilsonUpperBound(wins: Int, total: Int, z: Double) -> Double {
    guard total > 0 else { return 0 }
    let p = Double(wins) / Double(total)
    let z2 = z * z
    let denom = 1.0 + z2 / Double(total)
    let center = p + z2 / (2.0 * Double(total))
    let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
    return min(1, (center + margin) / denom)
}
