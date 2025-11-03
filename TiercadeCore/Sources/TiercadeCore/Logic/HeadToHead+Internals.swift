import Foundation

internal extension HeadToHeadLogic {
    internal struct HeadToHeadMetrics: Sendable {
        internal let wins: Int
        internal let comparisons: Int
        internal let winRate: Double
        internal let wilsonLB: Double
        internal let wilsonUB: Double
        internal let nameKey: String
        internal let id: String
    }

    internal struct Prior: Sendable {
        internal let alpha: Double
        internal let beta: Double
    }

    /// Canonical representation of an unordered item pair for deduplication.
    ///
    /// INVARIANT: lhs <= rhs (lexicographically)
    ///
    /// This canonical ordering ensures (A, B) and (B, A) produce identical hash keys,
    /// preventing duplicate comparisons in the head-to-head queue. Without this,
    /// the algorithm would waste ~50% of comparisons on duplicate pairs.
    ///
    /// Example:
    /// ```swift
    /// PairKey(item1, item2) == PairKey(item2, item1)  // ✅ Always true
    /// ```
    internal struct PairKey: Hashable {
        /// Left-hand item ID (guaranteed lexicographically <= rhs)
        internal let lhs: String

        /// Right-hand item ID (guaranteed lexicographically >= lhs)
        internal let rhs: String

        /// Creates a canonical pair key ensuring lhs <= rhs invariant.
        ///
        /// - Parameters:
        ///   - a: First item in the pair
        ///   - b: Second item in the pair
        /// - Postcondition: lhs <= rhs (lexicographically)
        internal init(_ a: Item, _ b: Item) {
            if a.id <= b.id {
                lhs = a.id
                rhs = b.id
            } else {
                lhs = b.id
                rhs = a.id
            }

            assert(lhs <= rhs, "PairKey invariant violated: lhs must be <= rhs")
        }
    }

    /// Statistical and algorithmic parameters for the Wilson score ranking system.
    ///
    /// These constants control confidence intervals, overlap thresholds, and tie-breaking
    /// behavior in the head-to-head comparison algorithm. Derived from empirical testing
    /// across pool sizes from 5-100 items.
    internal enum Tun {
        // MARK: - Capacity Limits

        /// Maximum number of tiers supported (prevents pathological tier proliferation)
        internal static let maximumTierCount = 20

        /// Minimum comparisons required per item for reliable ranking
        internal static let minimumComparisonsPerItem = 2

        /// Width of frontier region for boundary pair detection
        internal static let frontierWidth = 2

        // MARK: - Z-scores (Standard Deviations for Confidence Intervals)

        /// Z-score for quick-phase confidence intervals (68% confidence, ±1σ).
        /// Lower confidence allows faster initial sorting with fewer comparisons.
        internal static let zQuick: Double = 1.0

        /// Z-score for standard confidence intervals (80% confidence, ±1.28σ).
        /// Higher confidence for final tier assignments after refinement.
        internal static let zStd: Double = 1.28

        /// Z-score for early refinement decisions (68% confidence, ±1σ)
        internal static let zRefineEarly: Double = 1.0

        // MARK: - Overlap & Epsilon Thresholds

        /// Soft overlap epsilon (1.0%) - minimum Wilson interval gap to consider distinct ranks.
        /// Items closer than this threshold are treated as statistical ties.
        internal static let softOverlapEps: Double = 0.010

        /// Confidence bonus beta weight (10%) - prior strength adjustment for existing tier positions
        internal static let confBonusBeta: Double = 0.10

        /// Maximum suggested refinement pairs per cycle
        internal static let maxSuggestedPairs = 6

        // MARK: - Hysteresis Parameters

        /// Soft churn threshold (12%) - minor tier reassignments allowed
        internal static let hysteresisMaxChurnSoft: Double = 0.12

        /// Hard churn threshold (25%) - maximum tier movement before fallback
        internal static let hysteresisMaxChurnHard: Double = 0.25

        /// Ramp boost factor (50%) - amplifies confidence for items with many comparisons
        internal static let hysteresisRampBoost: Double = 0.50

        // MARK: - Tie Detection & Splitting

        /// Minimum Wilson range (1.5%) to consider splitting a segment
        internal static let minWilsonRangeForSplit: Double = 0.015

        /// Top-tier tie epsilon (1.2%) - items within this range at top are grouped together
        internal static let epsTieTop: Double = 0.012

        /// Bottom-tier tie epsilon (1.0%) - items within this range at bottom are grouped
        internal static let epsTieBottom: Double = 0.010

        /// Maximum items in bottom tie group before forcing split
        internal static let maxBottomTieWidth: Int = 4

        /// Upper bound ceiling (20%) for bottom-tier detection
        internal static let ubBottomCeil: Double = 0.20
    }

    internal enum TieringGuard {
        internal static let minSegmentSizeToSplit: Int = 3
    }

    internal static func warmUpComparisons(rankableCount n: Int, tierCount k: Int) -> Int {
        max(Int(ceil(1.5 * Double(n))), 2 * k)
    }

    internal static func partitionByComparisons(
        _ pool: [Item],
        records: [String: H2HRecord],
        minimumComparisons: Int
    ) -> (rankable: [Item], undersampled: [Item]) {
        internal var rankable: [Item] = []
        internal var undersampled: [Item] = []
        for item in pool {
            if (records[item.id]?.total ?? 0) >= minimumComparisons {
                rankable.append(item)
            } else {
                undersampled.append(item)
            }
        }
        return (rankable, undersampled)
    }

    internal static func normalizedTierNames(from tierOrder: [String]) -> [String] {
        tierOrder
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    internal static func clearedTiers(_ base: Items, removing pool: [Item], tierNames: [String]) -> Items {
        internal var updated = base
        internal let poolIds = Set(pool.map(\.id))
        internal let unrankedKey = TierIdentifier.unranked.rawValue

        for name in tierNames {
            updated[name] = []
        }
        for key in updated.keys where key != unrankedKey && !tierNames.contains(key) {
            updated[key]?.removeAll { poolIds.contains($0.id) }
        }
        if var unranked = updated[unrankedKey] {
            unranked.removeAll { poolIds.contains($0.id) }
            updated[unrankedKey] = unranked
        }
        return updated
    }

    internal static func operativeTierNames(from tierNames: [String]) -> [String] {
        guard tierNames.count >= 2 else { return tierNames }
        return Array(tierNames.prefix(Tun.maximumTierCount))
    }

    internal static func metricsDictionary(
        for items: [Item],
        records: [String: H2HRecord],
        z: Double,
        priors: [String: Prior]
    ) -> [String: HeadToHeadMetrics] {
        Dictionary(uniqueKeysWithValues: items.map { item in
            internal let record = records[item.id] ?? H2HRecord()
            internal let prior = priors[item.id] ?? Prior(alpha: 0, beta: 0)
            internal let effectiveWins = Double(record.wins) + prior.alpha
            internal let effectiveLosses = Double(record.losses) + prior.beta
            internal let effectiveTotal = effectiveWins + effectiveLosses
            internal let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            internal let keySource = (displayName?.isEmpty == false ? displayName! : item.id)
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

    internal static func metricsDictionary(
        for items: [Item],
        records: [String: H2HRecord],
        z: Double
    ) -> [String: HeadToHeadMetrics] {
        Dictionary(uniqueKeysWithValues: items.map { item in
            internal let record = records[item.id] ?? H2HRecord()
            internal let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            internal let keySource = (displayName?.isEmpty == false ? displayName! : item.id)
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

    internal static func orderedItems(_ items: [Item], metrics: [String: HeadToHeadMetrics]) -> [Item] {
        items.sorted { lhs, rhs in
            guard let leftMetrics = metrics[lhs.id],
                  internal let rightMetrics = metrics[rhs.id] else { return lhs.id < rhs.id }
            if leftMetrics.wilsonLB != rightMetrics.wilsonLB {
                return leftMetrics.wilsonLB > rightMetrics.wilsonLB
            }
            if leftMetrics.comparisons != rightMetrics.comparisons {
                return leftMetrics.comparisons > rightMetrics.comparisons
            }
            if leftMetrics.wins != rightMetrics.wins {
                return leftMetrics.wins > rightMetrics.wins
            }
            if leftMetrics.nameKey != rightMetrics.nameKey {
                return leftMetrics.nameKey < rightMetrics.nameKey
            }
            return leftMetrics.id < rightMetrics.id
        }
    }

    internal static func quantileCuts(count n: Int, tierCount k: Int) -> [Int] {
        guard k > 1, n > 1 else { return [] }
        internal var cuts: [Int] = []
        for i in 1..<k {
            internal let position = Int(round(Double(i) * Double(n) / Double(k)))
            if position > 0 && position < n {
                cuts.append(position)
            }
        }
        return Array(Set(cuts)).sorted()
    }

    internal static func buildAudits(orderedCount n: Int, cuts: [Int], width w: Int) -> [H2HFrontier] {
        cuts.map { cut in
            internal let upper = max(0, cut - w)..<cut
            internal let lower = cut..<min(n, cut + w)
            return H2HFrontier(index: cut, upperRange: upper, lowerRange: lower)
        }
    }

    internal static func slice<T>(_ array: [T], _ range: Range<Int>) -> [T] {
        guard !array.isEmpty else { return [] }
        internal let lower = max(0, range.lowerBound)
        internal let upper = min(array.count, range.upperBound)
        guard lower < upper else { return [] }
        return Array(array[lower..<upper])
    }

    internal static func assignByCuts(
        ordered: [Item],
        cuts: [Int],
        tierNames: [String],
        into tiers: inout Items
    ) {
        internal var tierIndex = 0
        internal var cursor = 0
        for (index, item) in ordered.enumerated() {
            while cursor < cuts.count && index >= cuts[cursor] {
                tierIndex += 1
                cursor += 1
            }
            internal let name = tierNames[min(tierIndex, tierNames.count - 1)]
            tiers[name, default: []].append(item)
        }
    }

    internal static func sortTierMembers(
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

    internal static func dropCuts(
        for ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
        tierCount: Int,
        overlapEps: Double
    ) -> [Int] {
        guard tierCount > 1, ordered.count >= 2 else { return [] }
        internal var scored: [(Int, Double)] = []
        for index in 0..<(ordered.count - 1) {
            guard let upper = metrics[ordered[index].id],
                  internal let lower = metrics[ordered[index + 1].id] else { continue }
            internal let raw = (upper.wilsonLB - lower.wilsonUB) + overlapEps
            internal let delta = max(0, raw)
            if delta <= 0 { continue }
            internal let minComparisons = Double(min(upper.comparisons, lower.comparisons))
            internal let maxComparisons = Double(max(upper.comparisons, lower.comparisons))
            internal let confidence = minComparisons + Tun.confBonusBeta * maxComparisons
            internal let score = delta * log1p(max(confidence, 0))
            if score > 0 {
                scored.append((index + 1, score))
            }
        }
        guard !scored.isEmpty else { return [] }
        internal let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(tierCount - 1)).map { $0.0 }.sorted()
    }

    internal static func wilsonRange(
        ordered: [Item],
        range: Range<Int>,
        metrics: [String: HeadToHeadMetrics]
    ) -> Double {
        guard !ordered.isEmpty, !range.isEmpty else { return 0 }
        internal let lower = max(0, range.lowerBound)
        internal let upper = min(ordered.count, range.upperBound)
        guard lower < upper else { return 0 }
        internal var minValue = 1.0
        internal var maxValue = 0.0
        for index in lower..<upper {
            if let metric = metrics[ordered[index].id] {
                minValue = min(minValue, metric.wilsonLB)
                maxValue = max(maxValue, metric.wilsonLB)
            }
        }
        return maxValue - minValue
    }

    internal static func fillMissingCutsWithGuards(
        primary: [Int],
        tierCount: Int,
        itemCount: Int,
        metrics: [String: HeadToHeadMetrics],
        ordered: [Item]
    ) -> [Int] {
        guard tierCount > 1, itemCount > 1 else { return [] }
        internal var picks = Set(primary).filter { $0 > 0 && $0 < itemCount }

        while picks.count < tierCount - 1 {
            internal let segments = contiguousSegments(n: itemCount, cuts: Array(picks))
            guard let largestSegment = segments.max(by: { $0.count < $1.count }) else { break }
            if largestSegment.count < TieringGuard.minSegmentSizeToSplit { break }
            internal let spread = wilsonRange(ordered: ordered, range: largestSegment, metrics: metrics)
            if spread < Tun.minWilsonRangeForSplit { break }

            internal let midpoint = largestSegment.lowerBound + largestSegment.count / 2
            if midpoint > largestSegment.lowerBound && midpoint < largestSegment.upperBound {
                picks.insert(midpoint)
            } else {
                break
            }
        }

        return Array(picks).sorted()
    }

    internal static func mergeCutsPreferRefined(
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

    internal static func bottomClusterStart(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics]
    ) -> Int? {
        guard ordered.count >= 2,
              internal let lastMetric = metrics[ordered.last!.id] else { return nil }

        internal let baseUB = lastMetric.wilsonUB
        internal let lowerBound = max(0, ordered.count - Tun.maxBottomTieWidth)
        internal var start = ordered.count - 1

        for index in stride(from: ordered.count - 2, through: lowerBound, by: -1) {
            guard let metric = metrics[ordered[index].id] else { break }
            internal let closeUpper = abs(metric.wilsonUB - baseUB) <= Tun.epsTieBottom
            internal let bothWeak = metric.wilsonUB <= Tun.ubBottomCeil && baseUB <= Tun.ubBottomCeil
            if closeUpper || bothWeak {
                start = index
            } else {
                break
            }
        }

        return start == ordered.count - 1 ? nil : start
    }

    internal static func contiguousSegments(n: Int, cuts: [Int]) -> [Range<Int>] {
        guard n > 0 else { return [] }
        internal let sortedCuts = cuts.sorted()
        internal var segments: [Range<Int>] = []
        internal var start = 0
        for cut in sortedCuts {
            internal let clamped = min(max(cut, 0), n)
            segments.append(start..<clamped)
            start = clamped
        }
        segments.append(start..<n)
        return segments
    }

    internal static func topBoundaryComparisons(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
        epsilon: Double
    ) -> [(Item, Item)] {
        guard ordered.count >= 3, epsilon > 0 else { return [] }
        guard let second = metrics[ordered[1].id],
              internal let third = metrics[ordered[2].id] else { return [] }

        internal let delta23 = abs(second.wilsonLB - third.wilsonLB)
        guard delta23 <= epsilon else { return [] }

        internal var results: [(Item, Item)] = [(ordered[1], ordered[2])]

        if let first = metrics[ordered[0].id] {
            internal let delta13 = abs(first.wilsonLB - third.wilsonLB)
            if delta13 <= epsilon {
                results.append((ordered[0], ordered[2]))
            }
        }

        return results
    }

    internal static func bottomBoundaryComparisons(
        ordered: [Item],
        metrics: [String: HeadToHeadMetrics],
        epsilon: Double
    ) -> [(Item, Item)] {
        guard ordered.count >= 2 else { return [] }
        internal let lastIndex = ordered.count - 1
        guard let last = metrics[ordered[lastIndex].id],
              metrics[ordered[lastIndex - 1].id] != nil else { return [] }

        internal var results: [(Item, Item)] = [
            (ordered[lastIndex - 1], ordered[lastIndex])
        ]

        if ordered.count >= 3,
           internal let third = metrics[ordered[lastIndex - 2].id] {
            internal let closeUpper = abs(third.wilsonUB - last.wilsonUB) <= Tun.epsTieBottom
            internal let bothWeak = third.wilsonUB <= Tun.ubBottomCeil && last.wilsonUB <= Tun.ubBottomCeil
            if closeUpper || bothWeak {
                results.append((ordered[lastIndex - 2], ordered[lastIndex]))
            }
        }

        return results
    }

    internal static func tierMapForCuts(
        ordered: [Item],
        cuts: [Int],
        tierCount: Int
    ) -> [String: Int] {
        internal var map: [String: Int] = [:]
        map.reserveCapacity(ordered.count)
        internal var tierIndex = 0
        internal var cursor = 0
        for (index, item) in ordered.enumerated() {
            while cursor < cuts.count && index >= cuts[cursor] {
                tierIndex += 1
                cursor += 1
            }
            map[item.id] = min(tierIndex + 1, tierCount)
        }
        return map
    }

    internal static func churnFraction(
        old: [String: Int],
        new: [String: Int],
        universe: [Item]
    ) -> Double {
        guard !universe.isEmpty else { return 0 }
        internal var moved = 0
        for item in universe where (old[item.id] ?? 0) != (new[item.id] ?? 0) {
            moved += 1
        }
        return Double(moved) / Double(universe.count)
    }

    /// Determines the expected win-rate prior for a given tier.
    ///
    /// Uses hardcoded priors for standard letter grades, falling back to linear
    /// interpolation for custom tier names based on tier index position.
    ///
    /// - Parameters:
    ///   - name: Tier name (e.g., "S", "A", "MyCustomTier")
    ///   - index: Zero-based position in tier order (0 = top tier)
    ///   - total: Total number of tiers
    /// - Returns: Expected win-rate for items in this tier [0.0, 1.0]
    internal static func priorMeanForTier(_ name: String, index: Int, total: Int) -> Double {
        /// Standard letter-grade tier win-rate priors
        /// (same values as buildPriors for consistency)
        internal let defaults: [String: Double] = [
            "S": 0.85,
            "A": 0.75,
            "B": 0.65,
            "C": 0.55,
            "D": 0.45,
            "E": 0.40,
            "F": 0.35
        ]
        if let value = defaults[name] { return value }
        internal let top = 0.85
        internal let bottom = 0.35
        internal let denom = max(1, total - 1)
        return top - (top - bottom) * (Double(index) / Double(denom))
    }

    internal static func buildPriors(
        from currentTiers: Items,
        tierOrder: [String],
        strength: Double = 6.0
    ) -> [String: Prior] {
        internal var output: [String: Prior] = [:]
        for (index, name) in tierOrder.enumerated() {
            guard let members = currentTiers[name], !members.isEmpty else { continue }
            internal let mean = priorMeanForTier(name, index: index, total: tierOrder.count)
            internal let alpha = max(0, mean * strength)
            internal let beta = max(0, (1.0 - mean) * strength)
            for item in members {
                output[item.id] = Prior(alpha: alpha, beta: beta)
            }
        }
        return output
    }

    internal static func wilsonLowerBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else { return 0 }
        internal let p = Double(wins) / Double(total)
        internal let z2 = z * z
        internal let denominator = 1.0 + z2 / Double(total)
        internal let center = p + z2 / (2.0 * Double(total))
        internal let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return max(0, (center - margin) / denominator)
    }

    internal static func wilsonUpperBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else { return 0 }
        internal let p = Double(wins) / Double(total)
        internal let z2 = z * z
        internal let denominator = 1.0 + z2 / Double(total)
        internal let center = p + z2 / (2.0 * Double(total))
        internal let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return min(1, (center + margin) / denominator)
    }

    internal static func wilsonLowerBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else { return 0 }
        internal let p = wins / total
        internal let z2 = z * z
        internal let denominator = 1.0 + z2 / total
        internal let center = p + z2 / (2.0 * total)
        internal let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return max(0, (center - margin) / denominator)
    }

    internal static func wilsonUpperBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else { return 0 }
        internal let p = wins / total
        internal let z2 = z * z
        internal let denominator = 1.0 + z2 / total
        internal let center = p + z2 / (2.0 * total)
        internal let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return min(1, (center + margin) / denominator)
    }
}
