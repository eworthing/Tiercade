import Foundation
import Testing
@testable import TiercadeCore

@Suite("HeadToHead Internals")
struct HeadToHeadInternalsTests {

    // MARK: Lifecycle

    init() {
        HeadToHeadLogic.loggingEnabled = false
    }

    // MARK: Internal

    @Test("Quick tier pass produces artifacts and suggested pairs")
    func quickTierPassProducesArtifacts() throws {
        let dataset = sampleDataset()
        let quick = HeadToHeadLogic.quickTierPass(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )

        let tiers = quick.tiers
        #expect(tiers["S"]?.contains(where: { $0.id == "alpha" }) == true)
        #expect(tiers["A"]?.contains(where: { $0.id == "beta" }) == true)
        #expect(tiers["B"]?.contains(where: { $0.id == "gamma" }) == true)
        #expect(tiers["unranked"]?.map(\.id) == ["delta"])

        let artifacts = try #require(quick.artifacts)
        #expect(artifacts.tierNames == ["S", "A", "B", "C"])
        #expect(artifacts.rankable.map(\.id) == ["alpha", "beta", "gamma"])
        #expect(!artifacts.frontier.isEmpty)
        #expect(artifacts.mode == .quick)
        #expect(!quick.suggestedPairs.isEmpty)
    }

    @Test("Refinement pairs surface boundary contests without duplication")
    func refinementPairsSurfaceBoundaries() throws {
        let dataset = sampleDataset()
        let quick = HeadToHeadLogic.quickTierPass(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )
        let artifacts = try #require(quick.artifacts)

        let pairs = HeadToHeadLogic.refinementPairs(
            artifacts: artifacts,
            records: dataset.records,
            limit: 4,
        )

        #expect(!pairs.isEmpty)
        let unique = Set(pairs.map { Set([$0.0.id, $0.1.id]) })
        #expect(unique.count == pairs.count)
    }

    @Test("Finalize tiers locks in refined artifacts")
    func finalizeTiersProducesDoneArtifacts() throws {
        let dataset = sampleDataset()
        let quick = HeadToHeadLogic.quickTierPass(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )
        let artifacts = try #require(quick.artifacts)

        let result = HeadToHeadLogic.finalizeTiers(
            artifacts: artifacts,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )

        #expect(result.updatedArtifacts.mode == .done)
        #expect(result.updatedArtifacts.rankable.first?.id == "alpha")
        #expect(result.tiers["S"]?.contains(where: { $0.id == "alpha" }) == true)
        #expect(result.tiers["unranked"]?.map(\.id) == ["delta"])
    }

    @Test("Warm start queue prioritizes boundary comparisons")
    func warmStartQueueProvidesSeedPairs() {
        let dataset = sampleDataset()
        let quick = HeadToHeadLogic.quickTierPass(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )

        let queue = HeadToHeadLogic.initialComparisonQueueWarmStart(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            currentTiers: quick.tiers,
            targetComparisonsPerItem: 3,
        )

        #expect(!queue.isEmpty)
        for pair in queue {
            #expect(pair.0.id != pair.1.id)
        }
    }

    @Test("Quick support routes undersampled into unranked ordered by metrics")
    func quickSupportHandlesUndersampled() {
        let dataset = sampleDataset()
        let undersampled = [dataset.pool.last!]
        var tiers = dataset.baseTiers
        tiers["S"] = []
        tiers["A"] = []

        let result = HeadToHeadLogic.quickResultForUndersampled(
            tiers: tiers,
            undersampled: undersampled,
            baseTiers: dataset.baseTiers,
            tierOrder: dataset.tierOrder,
            records: dataset.records,
        )

        #expect(result.tiers["unranked"]?.first?.id == "delta")
        #expect(result.artifacts == nil)
    }

    @Test("Drop cuts produces gaps when Wilson intervals separate tiers")
    func dropCutsDetectsBoundaries() {
        let items = [Item(id: "alpha"), Item(id: "beta"), Item(id: "gamma")]
        let metrics: [String: HeadToHeadLogic.HeadToHeadMetrics] = [
            "alpha": .init(
                wins: 10,
                comparisons: 12,
                winRate: 0.8,
                wilsonLB: 0.7,
                wilsonUB: 0.9,
                nameKey: "alpha",
                id: "alpha",
            ),
            "beta": .init(
                wins: 4,
                comparisons: 10,
                winRate: 0.4,
                wilsonLB: 0.35,
                wilsonUB: 0.55,
                nameKey: "beta",
                id: "beta",
            ),
            "gamma": .init(
                wins: 1,
                comparisons: 5,
                winRate: 0.2,
                wilsonLB: 0.1,
                wilsonUB: 0.4,
                nameKey: "gamma",
                id: "gamma",
            ),
        ]

        let cuts = HeadToHeadLogic.dropCuts(
            for: items,
            metrics: metrics,
            tierCount: 3,
            overlapEps: 0.01,
        )

        #expect(!cuts.isEmpty)
        #expect(cuts.allSatisfy { $0 > 0 && $0 < items.count })
    }

    @Test("Select refined cuts honors churn guardrails")
    func selectRefinedCutsRespectsHysteresis() {
        let context = HeadToHeadLogic.RefinementCutContext(
            quantCuts: [1, 2],
            refinedCuts: [1, 2],
            primaryCuts: [1, 2],
            totalComparisons: 20,
            requiredComparisons: 10,
            churn: 0.05,
            itemCount: 6,
        )
        let refined = HeadToHeadLogic.selectRefinedCuts(context)
        #expect(refined == [1, 2])

        let highChurn = HeadToHeadLogic.RefinementCutContext(
            quantCuts: [1, 2],
            refinedCuts: [1, 2],
            primaryCuts: [1, 2],
            totalComparisons: 5,
            requiredComparisons: 10,
            churn: 0.5,
            itemCount: 6,
        )
        let fallback = HeadToHeadLogic.selectRefinedCuts(highChurn)
        #expect(fallback == [1, 2])
    }

    @Test("Frontier candidate pairs respects seen set and orders by closeness")
    func frontierCandidatePairsProducesSortedResults() throws {
        let dataset = sampleDataset()
        let quick = HeadToHeadLogic.quickTierPass(
            from: dataset.pool,
            records: dataset.records,
            tierOrder: dataset.tierOrder,
            baseTiers: dataset.baseTiers,
        )
        var artifacts = try #require(quick.artifacts)
        let metrics = HeadToHeadLogic.metricsDictionary(
            for: artifacts.rankable,
            records: dataset.records,
            z: 1.0,
        )

        // Trim frontier to a single boundary to force predictable pairs.
        artifacts = HeadToHeadArtifacts(
            tierNames: artifacts.tierNames,
            rankable: artifacts.rankable,
            undersampled: [],
            provisionalCuts: artifacts.provisionalCuts,
            frontier: [artifacts.frontier.first!],
            warmUpComparisons: artifacts.warmUpComparisons,
            mode: artifacts.mode,
            metrics: metrics,
        )

        var seen: Set<HeadToHeadLogic.PairKey> = []
        let candidates = HeadToHeadLogic.frontierCandidatePairs(
            artifacts: artifacts,
            metrics: metrics,
            seen: &seen,
        )

        #expect(!candidates.isEmpty)
        let sorted = candidates.sorted()
        #expect(sorted == candidates)
        #expect(Set(candidates.map { HeadToHeadLogic.PairKey($0.pair.0, $0.pair.1) }).count == candidates.count)
    }

    // MARK: Private

    private func sampleDataset()
    // swiftlint:disable:next large_tuple - Test helper returning multiple related values
    -> (pool: [Item], records: [String: HeadToHeadRecord], tierOrder: [String], baseTiers: Items) {
        let alpha = Item(id: "alpha", name: "Alpha")
        let beta = Item(id: "beta", name: "Beta")
        let gamma = Item(id: "gamma", name: "Gamma")
        let delta = Item(id: "delta", name: "Delta")

        var records: [String: HeadToHeadRecord] = [:]
        records["alpha"] = makeRecord(wins: 6, losses: 1)
        records["beta"] = makeRecord(wins: 4, losses: 3)
        records["gamma"] = makeRecord(wins: 2, losses: 1)
        records["delta"] = makeRecord(wins: 0, losses: 1)

        let baseTiers: Items = [
            "S": [alpha],
            "A": [beta],
            "B": [gamma],
            "C": [],
            "unranked": [delta],
        ]

        return (
            pool: [alpha, beta, gamma, delta],
            records: records,
            tierOrder: ["S", "A", "B", "C"],
            baseTiers: baseTiers,
        )
    }

    private func makeRecord(wins: Int, losses: Int) -> HeadToHeadRecord {
        var record = HeadToHeadRecord()
        record.wins = wins
        record.losses = losses
        return record
    }
}
