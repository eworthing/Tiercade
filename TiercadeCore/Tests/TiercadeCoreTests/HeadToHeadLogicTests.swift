import Foundation
import Testing
@testable import TiercadeCore

@Suite("HeadToHeadLogic")
struct HeadToHeadLogicTests {
    @Test("Random pair selection rerolls duplicate indices")
    func pickPairAvoidsDuplicates() {
        let pool = makePool()
        let sequence = SequenceRNG([0.0, 0.0])
        let pair = HeadToHeadLogic.pickPair(from: pool, rng: { sequence.next() })
        #expect(pair?.0.id == "alpha")
        #expect(pair?.1.id == "beta")
    }

    @Test("Pair selection returns nil when pool too small")
    func pickPairRequiresAtLeastTwo() {
        let single = [Item(id: "solo", name: "Solo")]
        let pair = HeadToHeadLogic.pickPair(from: single, rng: { 0.1 })
        #expect(pair == nil)
    }

    @Test("Pairings cover every unique combination")
    func pairingsProduceAllCombinations() {
        let pool = makePool()
        let sequence = SequenceRNG([0.3, 0.7, 0.2, 0.5])
        let results = HeadToHeadLogic.pairings(from: pool, rng: { sequence.next() })

        let keys = Set(results.map { pairKey(for: $0) })
        #expect(results.count == 3)
        #expect(keys == Set(["alpha|beta", "alpha|gamma", "beta|gamma"]))
    }

    @Test("Vote tallies wins and losses for both contenders")
    func voteTalliesResults() {
        let pool = makePool()
        var records: [String: H2HRecord] = [:]

        HeadToHeadLogic.vote(pool[0], pool[1], winner: pool[0], records: &records)
        HeadToHeadLogic.vote(pool[1], pool[2], winner: pool[2], records: &records)

        #expect(records[pool[0].id]?.wins == 1)
        #expect(records[pool[0].id]?.losses == 0)
        #expect(records[pool[1].id]?.wins == 0)
        #expect(records[pool[1].id]?.losses == 2)
        #expect(records[pool[2].id]?.wins == 1)
        #expect(records[pool[2].id]?.losses == 0)
    }
}

private extension HeadToHeadLogicTests {
    func makePool() -> [Item] {
        [
            Item(id: "alpha", name: "Alpha"),
            Item(id: "beta", name: "Beta"),
            Item(id: "gamma", name: "Gamma")
        ]
    }

    func pairKey(for pair: (Item, Item)) -> String {
        let ids = [pair.0.id, pair.1.id].sorted()
        return ids.joined(separator: "|")
    }
}

private final class SequenceRNG {
    private let values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        precondition(!values.isEmpty, "SequenceRNG requires at least one value")
        self.values = values
    }

    func next() -> Double {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}
