import Foundation

extension HeadToHeadLogic {
    internal struct HeadToHeadMetrics: Sendable {
        let wins: Int
        let comparisons: Int
        let winRate: Double
        let wilsonLB: Double
        let wilsonUB: Double
        let nameKey: String
        let id: String
    }

    internal struct Prior: Sendable {
        let alpha: Double
        let beta: Double
    }

    internal struct PairKey: Hashable {
        let lhs: String
        let rhs: String

        internal init(_ a: Item, _ b: Item) {
            if a.id <= b.id {
                lhs = a.id
                rhs = b.id
            } else {
                lhs = b.id
                rhs = a.id
            }
        }
    }

    internal enum Tun {
        internal static let maximumTierCount = 20
        internal static let minimumComparisonsPerItem = 2
        internal static let frontierWidth = 2
        internal static let zQuick: Double = 1.0
        internal static let zStd: Double = 1.28
        internal static let zRefineEarly: Double = 1.0
        internal static let softOverlapEps: Double = 0.010
        internal static let confBonusBeta: Double = 0.10
        internal static let maxSuggestedPairs = 6
        internal static let hysteresisMaxChurnSoft: Double = 0.12
        internal static let hysteresisMaxChurnHard: Double = 0.25
        internal static let hysteresisRampBoost: Double = 0.50
        internal static let minWilsonRangeForSplit: Double = 0.015
        internal static let epsTieTop: Double = 0.012
        internal static let epsTieBottom: Double = 0.010
        internal static let maxBottomTieWidth: Int = 4
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

    internal static func normalizedTierNames(from tierOrder: [String]) -> [String] {
        tierOrder
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    internal static func clearedTiers(_ base: Items, removing pool: [Item], tierNames: [String]) -> Items {
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

    internal static func metricsDictionary(
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

    internal static func orderedItems(_ items: [Item], metrics: [String: HeadToHeadMetrics]) -> [Item] {
        items.sorted { lhs, rhs in
            guard let leftMetrics = metrics[lhs.id],
                  let rightMetrics = metrics[rhs.id] else { return lhs.id < rhs.id }
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
        var cuts: [Int] = []
        for i in 1..<k {
            let position = Int(round(Double(i) * Double(n) / Double(k)))
            if position > 0 && position < n {
                cuts.append(position)
            }
        }
        return Array(Set(cuts)).sorted()
    }

    internal static func buildAudits(orderedCount n: Int, cuts: [Int], width w: Int) -> [H2HFrontier] {
        cuts.map { cut in
            let upper = max(0, cut - w)..<cut
            let lower = cut..<min(n, cut + w)
            return H2HFrontier(index: cut, upperRange: upper, lowerRange: lower)
        }
    }

    internal static func slice<T>(_ array: [T], _ range: Range<Int>) -> [T] {
        guard !array.isEmpty else { return [] }
        let lower = max(0, range.lowerBound)
        let upper = min(array.count, range.upperBound)
        guard lower < upper else { return [] }
        return Array(array[lower..<upper])
    }

    internal static func assignByCuts(
        ordered: [Item],
        cuts: [Int],
        tierNames: [String],
        into tiers: inout Items
    ) {
        var tierIndex = 0
        var cursor = 0
        for (index, item) in ordered.enumerated() {
            while cursor < cuts.count && index >= cuts[cursor] {
                tierIndex += 1
                cursor += 1
            }
            let name = tierNames[min(tierIndex, tierNames.count - 1)]
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
        var scored: [(Int, Double)] = []
        for index in 0..<(ordered.count - 1) {
            guard let upper = metrics[ordered[index].id],
                  let lower = metrics[ordered[index + 1].id] else { continue }
            let raw = (upper.wilsonLB - lower.wilsonUB) + overlapEps
            let delta = max(0, raw)
            if delta <= 0 { continue }
            let minComparisons = Double(min(upper.comparisons, lower.comparisons))
            let maxComparisons = Double(max(upper.comparisons, lower.comparisons))
            let confidence = minComparisons + Tun.confBonusBeta * maxComparisons
            let score = delta * log1p(max(confidence, 0))
            if score > 0 {
                scored.append((index + 1, score))
            }
        }
        guard !scored.isEmpty else { return [] }
        let sorted = scored.sorted { $0.1 > $1.1 }
        return Array(sorted.prefix(tierCount - 1)).map { $0.0 }.sorted()
    }

    internal static func wilsonRange(
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

    internal static func fillMissingCutsWithGuards(
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
              let lastMetric = metrics[ordered.last!.id] else { return nil }

        let baseUB = lastMetric.wilsonUB
        let lowerBound = max(0, ordered.count - Tun.maxBottomTieWidth)
        var start = ordered.count - 1

        for index in stride(from: ordered.count - 2, through: lowerBound, by: -1) {
            guard let metric = metrics[ordered[index].id] else { break }
            let closeUpper = abs(metric.wilsonUB - baseUB) <= Tun.epsTieBottom
            let bothWeak = metric.wilsonUB <= Tun.ubBottomCeil && baseUB <= Tun.ubBottomCeil
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

    internal static func topBoundaryComparisons(
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

    internal static func bottomBoundaryComparisons(
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
            let closeUpper = abs(third.wilsonUB - last.wilsonUB) <= Tun.epsTieBottom
            let bothWeak = third.wilsonUB <= Tun.ubBottomCeil && last.wilsonUB <= Tun.ubBottomCeil
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

    internal static func churnFraction(
        old: [String: Int],
        new: [String: Int],
        universe: [Item]
    ) -> Double {
        guard !universe.isEmpty else { return 0 }
        var moved = 0
        for item in universe where (old[item.id] ?? 0) != (new[item.id] ?? 0) {
            moved += 1
        }
        return Double(moved) / Double(universe.count)
    }

    internal static func priorMeanForTier(_ name: String, index: Int, total: Int) -> Double {
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
        let top = 0.85
        let bottom = 0.35
        let denom = max(1, total - 1)
        return top - (top - bottom) * (Double(index) / Double(denom))
    }

    internal static func buildPriors(
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

    internal static func wilsonLowerBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else { return 0 }
        let p = Double(wins) / Double(total)
        let z2 = z * z
        let denominator = 1.0 + z2 / Double(total)
        let center = p + z2 / (2.0 * Double(total))
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return max(0, (center - margin) / denominator)
    }

    internal static func wilsonUpperBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else { return 0 }
        let p = Double(wins) / Double(total)
        let z2 = z * z
        let denominator = 1.0 + z2 / Double(total)
        let center = p + z2 / (2.0 * Double(total))
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return min(1, (center + margin) / denominator)
    }

    internal static func wilsonLowerBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else { return 0 }
        let p = wins / total
        let z2 = z * z
        let denominator = 1.0 + z2 / total
        let center = p + z2 / (2.0 * total)
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return max(0, (center - margin) / denominator)
    }

    internal static func wilsonUpperBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else { return 0 }
        let p = wins / total
        let z2 = z * z
        let denominator = 1.0 + z2 / total
        let center = p + z2 / (2.0 * total)
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return min(1, (center + margin) / denominator)
    }
}
