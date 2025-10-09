import Foundation

extension HeadToHeadLogic {
    struct WarmStartPreparation {
        let tiersByName: [String: [Item]]
        let unranked: [Item]
        let anchors: [Item]
    }

    struct WarmStartQueueBuilder {
        let target: Int
        private(set) var queue: [(Item, Item)] = []
        private var counts: [String: Int]
        private var seen: Set<PairKey> = []

        init(pool: [Item], target: Int) {
            self.target = target
            counts = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, 0) })
        }

        var isSatisfied: Bool {
            counts.values.allSatisfy { $0 >= target }
        }

        mutating func enqueue(_ first: Item, _ second: Item) {
            guard first.id != second.id else { return }
            let key = PairKey(first, second)
            guard !seen.contains(key) else { return }
            if needsMore(first) || needsMore(second) {
                queue.append((first, second))
                seen.insert(key)
                counts[first.id, default: 0] += 1
                counts[second.id, default: 0] += 1
            }
        }

        mutating func enqueueBoundaryPairs(
            tierOrder: [String],
            tiersByName: [String: [Item]],
            frontierWidth: Int
        ) -> Bool {
            guard tierOrder.count >= 2 else { return isSatisfied }
            for index in 0..<(tierOrder.count - 1) {
                guard let upper = tiersByName[tierOrder[index]],
                      let lower = tiersByName[tierOrder[index + 1]],
                      !upper.isEmpty, !lower.isEmpty else { continue }

                let upperTail = Array(upper.suffix(min(frontierWidth, upper.count)))
                let lowerHead = Array(lower.prefix(min(frontierWidth, lower.count)))
                for upperItem in upperTail {
                    for lowerItem in lowerHead {
                        enqueue(upperItem, lowerItem)
                        if isSatisfied { return true }
                    }
                }
            }
            return isSatisfied
        }

        mutating func enqueueUnranked(_ unranked: [Item], anchors: [Item]) -> Bool {
            guard !anchors.isEmpty else { return isSatisfied }
            for item in unranked {
                var added = 0
                for anchor in anchors {
                    enqueue(item, anchor)
                    if isSatisfied { return true }
                    added += 1
                    if added >= 2 { break }
                }
            }
            return isSatisfied
        }

        mutating func enqueueAdjacentPairs(in tiersByName: [String: [Item]]) -> Bool {
            for items in tiersByName.values where items.count >= 2 {
                for index in 0..<(items.count - 1) {
                    enqueue(items[index], items[index + 1])
                    if isSatisfied { return true }
                }
            }
            return isSatisfied
        }

        mutating func enqueueFallback(from pool: [Item]) {
            guard !isSatisfied else { return }
            let fallbackPairs = HeadToHeadLogic.pairings(from: pool, rng: { Double.random(in: 0...1) })
            for pair in fallbackPairs {
                enqueue(pair.0, pair.1)
                if isSatisfied { return }
            }
        }

        private func needsMore(_ item: Item) -> Bool {
            counts[item.id, default: 0] < target
        }
    }

    static func prepareWarmStart(
        pool: [Item],
        tierOrder: [String],
        currentTiers: Items,
        metrics: [String: HeadToHeadMetrics]
    ) -> WarmStartPreparation {
        let poolById = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
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

        let frontierWidth = max(1, Tun.frontierWidth)
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

        return WarmStartPreparation(
            tiersByName: tiersByName,
            unranked: unranked,
            anchors: anchors
        )
    }
}
