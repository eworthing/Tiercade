import Foundation
import Testing
@testable import TiercadeCore

/// Comprehensive simulation framework for validating and optimizing HeadToHead ranking algorithm.
///
/// This test suite generates ground-truth rankings with known properties, simulates pairwise
/// comparisons with realistic noise, and measures algorithm performance across multiple dimensions:
/// - Ranking accuracy (Kendall's Tau correlation)
/// - Tier assignment accuracy
/// - Distribution quality (avoiding clustering)
/// - Stability (churn between phases)
///
/// Scenarios tested:
/// - Uniform: Items have similar strength (stress test for false distinctions)
/// - Clustered: Clear skill groups that should map to tiers
/// - Zipf: Power-law distribution (most realistic for real-world data)
/// - Bimodal: Two distinct populations (tests for over-splitting)
@Suite("HeadToHead Simulation & Validation")
struct HeadToHeadSimulations {

    // MARK: - Simulation Configuration

    /// Parameters for a single simulation run
    struct SimulationConfig: Sendable {
        let poolSize: Int
        let comparisonsPerItem: Int
        let tierCount: Int
        let noiseLevel: Double // 0.0 = perfect comparisons, 0.3 = 30% noise
        let scenario: GroundTruthScenario

        var totalComparisons: Int {
            poolSize * comparisonsPerItem
        }
    }

    /// Different ground-truth ranking scenarios
    enum GroundTruthScenario: Sendable {
        case uniform // All items similar strength
        case clustered(Int) // N distinct skill groups
        case zipf // Power-law distribution
        case bimodal // Two populations
    }

    // MARK: - Simulation Metrics

    /// Comprehensive metrics for evaluating algorithm performance
    struct SimulationMetrics: Sendable {
        // Ranking Quality
        let kendallsTau: Double // Correlation with ground truth (-1 to 1)
        let tierAccuracy: Double // % items in correct tier
        let adjacentTierAccuracy: Double // % items within ±1 tier

        // Distribution Quality
        let tierSizeVariance: Double // Variance in tier sizes
        let maxTierFraction: Double // Largest tier as % of total
        let emptyTierCount: Int // Number of empty tiers

        // Stability
        let quickToFinalChurn: Double // % items that changed tiers

        // Efficiency
        let comparisonsUsed: Int // Total comparisons performed
        let comparisonsPerItem: Double // Average per item

        // Additional Diagnostics
        let intransitiveCycles: Int // Count of A>B>C>A loops (not enforced, just measured)
        let averageWilsonInterval: Double // Mean interval width (measure of confidence)
    }

    // MARK: - Ground Truth Generation

    /// Generate ground-truth ranking with known properties
    static func generateGroundTruth(config: SimulationConfig) -> [Item: Double] {
        var strengths: [Double] = []

        switch config.scenario {
        case .uniform:
            // All items clustered around 0.5 with small variance
            strengths = (0 ..< config.poolSize).map { _ in
                0.5 + Double.random(in: -0.1 ... 0.1)
            }

        case let .clustered(clusterCount):
            // Distinct skill groups with clear separation
            let itemsPerCluster = config.poolSize / clusterCount
            for clusterIdx in 0 ..< clusterCount {
                let clusterMean = 1.0 - Double(clusterIdx) / Double(clusterCount - 1)
                for _ in 0 ..< itemsPerCluster {
                    strengths.append(clusterMean + Double.random(in: -0.05 ... 0.05))
                }
            }
            // Handle remainder
            while strengths.count < config.poolSize {
                strengths.append(Double.random(in: 0.3 ... 0.7))
            }

        case .zipf:
            // Power-law distribution: few strong, many weak
            for rank in 1 ... config.poolSize {
                let strength = 1.0 / Double(rank)
                strengths.append(strength)
            }
            // Normalize to [0, 1]
            let maxStrength = strengths.max() ?? 1.0
            strengths = strengths.map { $0 / maxStrength }

        case .bimodal:
            // Two distinct populations
            let splitPoint = config.poolSize / 2
            for idx in 0 ..< config.poolSize {
                if idx < splitPoint {
                    strengths.append(0.75 + Double.random(in: -0.1 ... 0.1))
                } else {
                    strengths.append(0.25 + Double.random(in: -0.1 ... 0.1))
                }
            }
        }

        // Create items with ground-truth strengths
        var result: [Item: Double] = [:]
        for (idx, strength) in strengths.enumerated() {
            let item = Item(id: "item_\(idx)", name: "Item \(idx)")
            result[item] = strength
        }

        return result
    }

    /// Simulate a pairwise comparison with noise
    static func simulateComparison(
        _ item1: Item,
        _ item2: Item,
        groundTruth: [Item: Double],
        noiseLevel: Double,
    )
    -> Item {
        let strength1 = groundTruth[item1] ?? 0.5
        let strength2 = groundTruth[item2] ?? 0.5

        // Calculate true win probability using logistic function
        let delta = strength1 - strength2
        let trueWinProb = 1.0 / (1.0 + exp(-10.0 * delta))

        // Apply noise: random chance of incorrect outcome
        let noisyWinProb = (1.0 - noiseLevel) * trueWinProb + noiseLevel * 0.5

        return Double.random(in: 0 ... 1) < noisyWinProb ? item1 : item2
    }

    // MARK: - Simulation Execution

    /// Run a complete HeadToHead simulation
    static func runSimulation(config: SimulationConfig) -> SimulationMetrics {
        // Generate ground truth
        let groundTruth = generateGroundTruth(config: config)
        let pool = Array(groundTruth.keys).sorted { $0.id < $1.id }

        // Generate tier order (S, A, B, C, D, F or custom)
        let tierOrder = generateTierOrder(count: config.tierCount)

        // Create empty base tiers
        var baseTiers: Items = [:]
        for tier in tierOrder {
            baseTiers[tier] = []
        }
        baseTiers[TierIdentifier.unranked.rawValue] = pool

        // Simulate warm-start pair generation
        let targetComparisons = config.comparisonsPerItem
        let initialPairs = HeadToHeadLogic.initialComparisonQueueWarmStart(
            from: pool,
            records: [:],
            tierOrder: tierOrder,
            currentTiers: baseTiers,
            targetComparisonsPerItem: targetComparisons,
        )

        // Perform comparisons and record results
        var records: [String: HeadToHeadRecord] = [:]
        var comparisonCount = 0

        for (item1, item2) in initialPairs {
            let winner = simulateComparison(item1, item2, groundTruth: groundTruth, noiseLevel: config.noiseLevel)
            HeadToHeadLogic.vote(item1, item2, winner: winner, records: &records)
            comparisonCount += 1
        }

        // Run quick phase
        let quickResult = HeadToHeadLogic.quickTierPass(
            from: pool,
            records: records,
            tierOrder: tierOrder,
            baseTiers: baseTiers,
        )

        let quickTiers = quickResult.tiers

        // Run refinement if suggested pairs exist
        var finalTiers = quickTiers
        var refinementComparisons = 0

        if let artifacts = quickResult.artifacts, !quickResult.suggestedPairs.isEmpty {
            // Perform refinement comparisons
            for (item1, item2) in quickResult.suggestedPairs {
                let winner = simulateComparison(item1, item2, groundTruth: groundTruth, noiseLevel: config.noiseLevel)
                HeadToHeadLogic.vote(item1, item2, winner: winner, records: &records)
                refinementComparisons += 1
            }

            // Finalize tiers
            let finalResult = HeadToHeadLogic.finalizeTiers(
                artifacts: artifacts,
                records: records,
                tierOrder: tierOrder,
                baseTiers: quickTiers,
            )
            finalTiers = finalResult.tiers
        }

        comparisonCount += refinementComparisons

        // Calculate metrics
        return calculateMetrics(
            groundTruth: groundTruth,
            quickTiers: quickTiers,
            finalTiers: finalTiers,
            tierOrder: tierOrder,
            comparisonsUsed: comparisonCount,
            records: records,
        )
    }

    // MARK: - Metrics Calculation

    /// Calculate Kendall's Tau correlation between two rankings
    static func kendallsTau(
        groundTruth: [Item: Double],
        finalRanking: [Item],
    )
    -> Double {
        let items = Array(groundTruth.keys)
        guard items.count >= 2 else {
            return 1.0
        }

        var concordant = 0
        var discordant = 0

        for i in 0 ..< items.count {
            for j in (i + 1) ..< items.count {
                let item1 = items[i]
                let item2 = items[j]

                let trueOrder = (groundTruth[item1] ?? 0) > (groundTruth[item2] ?? 0)
                guard
                    let idx1 = finalRanking.firstIndex(of: item1),
                    let idx2 = finalRanking.firstIndex(of: item2)
                else {
                    continue
                }
                let inferredOrder = idx1 < idx2

                if trueOrder == inferredOrder {
                    concordant += 1
                } else {
                    discordant += 1
                }
            }
        }

        let totalPairs = concordant + discordant
        guard totalPairs > 0 else {
            return 0.0
        }

        return Double(concordant - discordant) / Double(totalPairs)
    }

    /// Calculate tier assignment accuracy
    static func tierAccuracy(
        groundTruth: [Item: Double],
        tiers: Items,
        tierOrder: [String],
    )
    -> (exact: Double, adjacent: Double) {
        // Map ground truth to ideal tier assignments
        let sortedItems = groundTruth.sorted { $0.value > $1.value }
        let itemsPerTier = Double(sortedItems.count) / Double(tierOrder.count)

        var idealTiers: [Item: Int] = [:]
        for (idx, (item, _)) in sortedItems.enumerated() {
            let tierIdx = min(Int(Double(idx) / itemsPerTier), tierOrder.count - 1)
            idealTiers[item] = tierIdx
        }

        // Map actual tier assignments
        var actualTiers: [Item: Int] = [:]
        for (tierIdx, tierName) in tierOrder.enumerated() {
            for item in tiers[tierName] ?? [] {
                actualTiers[item] = tierIdx
            }
        }

        // Calculate accuracy
        var exactMatches = 0
        var adjacentMatches = 0
        let totalItems = groundTruth.count

        for item in groundTruth.keys {
            guard
                let ideal = idealTiers[item],
                let actual = actualTiers[item]
            else {
                continue
            }

            if ideal == actual {
                exactMatches += 1
                adjacentMatches += 1
            } else if abs(ideal - actual) <= 1 {
                adjacentMatches += 1
            }
        }

        return (
            exact: Double(exactMatches) / Double(totalItems),
            adjacent: Double(adjacentMatches) / Double(totalItems),
        )
    }

    /// Calculate churn between quick and final tiers
    static func calculateChurn(
        quickTiers: Items,
        finalTiers: Items,
        tierOrder: [String],
    )
    -> Double {
        var quickAssignments: [String: String] = [:]
        var finalAssignments: [String: String] = [:]

        for tierName in tierOrder {
            for item in quickTiers[tierName] ?? [] {
                quickAssignments[item.id] = tierName
            }
            for item in finalTiers[tierName] ?? [] {
                finalAssignments[item.id] = tierName
            }
        }

        let allItems = Set(quickAssignments.keys).union(finalAssignments.keys)
        let moved = allItems.filter { itemId in
            quickAssignments[itemId] != finalAssignments[itemId]
        }

        guard !allItems.isEmpty else {
            return 0.0
        }
        return Double(moved.count) / Double(allItems.count)
    }

    /// Detect intransitive cycles in comparison records
    static func countIntransitiveCycles(
        records: [String: HeadToHeadRecord],
        pool: [Item],
    )
    -> Int {
        // Simplified cycle detection: check for A>B>C>A patterns
        // This is a heuristic count, not exhaustive
        var cycles = 0

        for i in 0 ..< pool.count {
            for j in (i + 1) ..< pool.count {
                for k in (j + 1) ..< pool.count {
                    let a = pool[i]
                    let b = pool[j]
                    let c = pool[k]

                    let aWins = records[a.id]?.wins ?? 0
                    let bWins = records[b.id]?.wins ?? 0
                    let cWins = records[c.id]?.wins ?? 0

                    // Simple heuristic: if A>B, B>C, but C>A, count as cycle
                    if aWins > bWins, bWins > cWins, cWins > aWins {
                        cycles += 1
                    }
                }
            }
        }

        return cycles
    }

    /// Comprehensive metrics calculation
    static func calculateMetrics(
        groundTruth: [Item: Double],
        quickTiers: Items,
        finalTiers: Items,
        tierOrder: [String],
        comparisonsUsed: Int,
        records: [String: HeadToHeadRecord],
    )
    -> SimulationMetrics {
        // Create final ranking order
        var finalRanking: [Item] = []
        for tierName in tierOrder {
            finalRanking.append(contentsOf: finalTiers[tierName] ?? [])
        }

        let tau = kendallsTau(groundTruth: groundTruth, finalRanking: finalRanking)
        let (exact, adjacent) = tierAccuracy(groundTruth: groundTruth, tiers: finalTiers, tierOrder: tierOrder)
        let churn = calculateChurn(quickTiers: quickTiers, finalTiers: finalTiers, tierOrder: tierOrder)

        // Distribution metrics
        let tierSizes = tierOrder.map { Double(finalTiers[$0]?.count ?? 0) }
        let meanSize = tierSizes.reduce(0, +) / Double(tierSizes.count)
        let variance = tierSizes.map { pow($0 - meanSize, 2) }.reduce(0, +) / Double(tierSizes.count)
        let maxFraction = (tierSizes.max() ?? 0) / Double(groundTruth.count)
        let emptyCount = tierSizes.count(where: { $0 == 0 })

        // Confidence metrics
        let totalComparisons = records.values.reduce(0) { $0 + $1.total }
        let avgComparisonsPerItem = Double(totalComparisons) / Double(groundTruth.count)

        // Estimate average Wilson interval width (using z=1.0 for consistency)
        let avgInterval = records.values.map { record -> Double in
            let lb = HeadToHeadLogic.wilsonLowerBound(wins: record.wins, total: record.total, z: 1.0)
            let ub = HeadToHeadLogic.wilsonUpperBound(wins: record.wins, total: record.total, z: 1.0)
            return ub - lb
        }.reduce(0, +) / Double(max(records.count, 1))

        let cycles = countIntransitiveCycles(records: records, pool: Array(groundTruth.keys))

        return SimulationMetrics(
            kendallsTau: tau,
            tierAccuracy: exact,
            adjacentTierAccuracy: adjacent,
            tierSizeVariance: variance,
            maxTierFraction: maxFraction,
            emptyTierCount: emptyCount,
            quickToFinalChurn: churn,
            comparisonsUsed: comparisonsUsed,
            comparisonsPerItem: avgComparisonsPerItem,
            intransitiveCycles: cycles,
            averageWilsonInterval: avgInterval,
        )
    }

    // MARK: - Helper Functions

    static func generateTierOrder(count: Int) -> [String] {
        let standardTiers = ["S", "A", "B", "C", "D", "F"]
        if count <= standardTiers.count {
            return Array(standardTiers.prefix(count))
        }
        // For more than 6 tiers, add numbered tiers
        var tiers = standardTiers
        for i in 1 ... (count - standardTiers.count) {
            tiers.append("T\(i)")
        }
        return tiers
    }

    // MARK: - Baseline Tests

    @Test("Baseline: Small Pool (10 items, 3 comp/item, Zipf distribution)")
    func baselineSmallPoolZipf() {
        let config = SimulationConfig(
            poolSize: 10,
            comparisonsPerItem: 3,
            tierCount: 5,
            noiseLevel: 0.1,
            scenario: .zipf,
        )

        let metrics = Self.runSimulation(config: config)

        // Log baseline metrics
        print("Small Pool Zipf Baseline:")
        print("  Kendall's Tau: \(String(format: "%.3f", metrics.kendallsTau))")
        print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
        print("  Adjacent Accuracy: \(String(format: "%.1f%%", metrics.adjacentTierAccuracy * 100))")
        print("  Max Tier Fraction: \(String(format: "%.1f%%", metrics.maxTierFraction * 100))")
        print("  Churn: \(String(format: "%.1f%%", metrics.quickToFinalChurn * 100))")

        // Sanity checks (not strict requirements yet)
        #expect(metrics.kendallsTau > 0.5, "Tau should be positive")
        #expect(metrics.tierAccuracy > 0.3, "Should place >30% correctly")
    }

    @Test("Baseline: Medium Pool (30 items, 3 comp/item, Clustered)")
    func baselineMediumPoolClustered() {
        let config = SimulationConfig(
            poolSize: 30,
            comparisonsPerItem: 3,
            tierCount: 6,
            noiseLevel: 0.1,
            scenario: .clustered(4),
        )

        let metrics = Self.runSimulation(config: config)

        print("Medium Pool Clustered Baseline:")
        print("  Kendall's Tau: \(String(format: "%.3f", metrics.kendallsTau))")
        print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
        print("  Churn: \(String(format: "%.1f%%", metrics.quickToFinalChurn * 100))")

        #expect(metrics.kendallsTau > 0.6, "Clustered should achieve decent correlation")
    }

    @Test("Baseline: Uniform Distribution (stress test)")
    func baselineUniform() {
        let config = SimulationConfig(
            poolSize: 20,
            comparisonsPerItem: 3,
            tierCount: 5,
            noiseLevel: 0.2,
            scenario: .uniform,
        )

        let metrics = Self.runSimulation(config: config)

        print("Uniform Distribution Baseline:")
        print("  Kendall's Tau: \(String(format: "%.3f", metrics.kendallsTau))")
        print("  Empty Tiers: \(metrics.emptyTierCount)")
        print("  Max Tier Fraction: \(String(format: "%.1f%%", metrics.maxTierFraction * 100))")

        // Uniform should show lower correlation (items are actually similar)
        // but shouldn't create degenerate tier distributions
        #expect(metrics.maxTierFraction < 0.6, "Should not cluster >60% in one tier")
    }
}
