import Foundation
import Testing
@testable import TiercadeCore

/// Parameter sweep testing framework for optimizing HeadToHead algorithm.
///
/// This suite tests various parameter combinations to find optimal settings for:
/// - Z-scores (confidence intervals)
/// - Comparison budgets
/// - Frontier width
/// - Overlap epsilon
///
/// Results guide tuning of Tun constants in HeadToHead+Internals.swift
@Suite("HeadToHead Parameter Optimization")
struct HeadToHeadParameterSweep {

    // MARK: - Parameter Configurations

    struct ParameterSet: Sendable {
        let zQuick: Double
        let zStd: Double
        let frontierWidth: Int
        let comparisonsPerItem: Int

        static let current = ParameterSet(
            zQuick: 1.0,
            zStd: 1.28,
            frontierWidth: 2,
            comparisonsPerItem: 3,
        )

        static let proposedFromResearch = ParameterSet(
            zQuick: 1.5, // Higher confidence for quick phase
            zStd: 1.96, // 95% confidence (research recommendation)
            frontierWidth: 3, // Wider boundary sampling
            comparisonsPerItem: 4, // Slightly more comparisons
        )

        static let conservative = ParameterSet(
            zQuick: 1.96,
            zStd: 1.96,
            frontierWidth: 4,
            comparisonsPerItem: 5,
        )

        var description: String {
            "z=(\(zQuick),\(zStd)) fw=\(frontierWidth) comp=\(comparisonsPerItem)"
        }
    }

    // MARK: - Comparison Test

    @Test("Parameter Comparison: Current vs Research-Based vs Conservative")
    func compareParameterSets() {
        let paramSets = [
            ("Current", ParameterSet.current),
            ("Research", ParameterSet.proposedFromResearch),
            ("Conservative", ParameterSet.conservative),
        ]

        let config = HeadToHeadSimulations.SimulationConfig(
            poolSize: 30,
            comparisonsPerItem: 3, // Will be overridden per param set
            tierCount: 6,
            noiseLevel: 0.1,
            scenario: .clustered(4),
        )

        print("\n" + String(repeating: "=", count: 80))
        print("PARAMETER SWEEP: Medium Pool (30 items), Clustered Distribution")
        print(String(repeating: "=", count: 80))

        var results: [(String, HeadToHeadSimulations.SimulationMetrics)] = []

        for (name, params) in paramSets {
            // Note: Current implementation doesn't allow overriding z-scores at runtime
            // This test documents what we WOULD test once we make parameters configurable

            var testConfig = config
            testConfig = HeadToHeadSimulations.SimulationConfig(
                poolSize: config.poolSize,
                comparisonsPerItem: params.comparisonsPerItem,
                tierCount: config.tierCount,
                noiseLevel: config.noiseLevel,
                scenario: config.scenario,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: testConfig)
            results.append((name, metrics))

            print("\n\(name) Parameters: \(params.description)")
            print("  Kendall's Tau:       \(String(format: "%6.3f", metrics.kendallsTau))")
            print("  Tier Accuracy:       \(String(format: "%5.1f%%", metrics.tierAccuracy * 100))")
            print("  Adjacent Accuracy:   \(String(format: "%5.1f%%", metrics.adjacentTierAccuracy * 100))")
            print("  Max Tier Fraction:   \(String(format: "%5.1f%%", metrics.maxTierFraction * 100))")
            print("  Churn:               \(String(format: "%5.1f%%", metrics.quickToFinalChurn * 100))")
            print("  Comparisons Used:    \(metrics.comparisonsUsed)")
            print("  Avg Wilson Interval: \(String(format: "%6.3f", metrics.averageWilsonInterval))")
        }

        print("\n" + String(repeating: "=", count: 80))

        // Find best performer by weighted score
        let weighted = results.map { name, metrics -> (String, Double) in
            let score = metrics.kendallsTau * 0.5 + // 50% weight on correlation
                metrics.tierAccuracy * 0.3 + // 30% weight on tier placement
                (1.0 - metrics.quickToFinalChurn) * 0.2 // 20% weight on stability
            return (name, score)
        }

        if let best = weighted.max(by: { $0.1 < $1.1 }) {
            print("WINNER: \(best.0) with weighted score \(String(format: "%.3f", best.1))")
        }

        print(String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Comparison Budget Analysis

    @Test("Comparison Budget: Diminishing Returns Analysis")
    func comparisonBudgetAnalysis() {
        print("\n" + String(repeating: "=", count: 80))
        print("COMPARISON BUDGET ANALYSIS")
        print(String(repeating: "=", count: 80))

        let budgets = [2, 3, 4, 5, 8, 10]

        for budget in budgets {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: 20,
                comparisonsPerItem: budget,
                tierCount: 5,
                noiseLevel: 0.15,
                scenario: .zipf,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)

            let efficiency = metrics.kendallsTau / Double(budget)

            print("\nBudget: \(budget) comparisons/item")
            print("  Tau: \(String(format: "%.3f", metrics.kendallsTau))")
            print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
            print("  Efficiency (tau/budget): \(String(format: "%.3f", efficiency))")
        }

        print("\n" + String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Noise Sensitivity

    @Test("Noise Sensitivity: Algorithm Robustness")
    func noiseSensitivityAnalysis() {
        print("\n" + String(repeating: "=", count: 80))
        print("NOISE SENSITIVITY ANALYSIS")
        print(String(repeating: "=", count: 80))

        let noiseLevels = [0.0, 0.05, 0.10, 0.15, 0.20, 0.30]

        for noise in noiseLevels {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: 20,
                comparisonsPerItem: 3,
                tierCount: 5,
                noiseLevel: noise,
                scenario: .zipf,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)

            print("\nNoise Level: \(String(format: "%.0f%%", noise * 100))")
            print("  Tau: \(String(format: "%.3f", metrics.kendallsTau))")
            print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
            print("  Churn: \(String(format: "%.1f%%", metrics.quickToFinalChurn * 100))")
        }

        print("\n" + String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Scale Analysis

    @Test("Scale Analysis: Performance Across Pool Sizes")
    func scaleAnalysis() {
        print("\n" + String(repeating: "=", count: 80))
        print("SCALE ANALYSIS: Algorithm Performance by Pool Size")
        print(String(repeating: "=", count: 80))

        let poolSizes = [5, 10, 20, 30, 50]

        for poolSize in poolSizes {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: poolSize,
                comparisonsPerItem: 3,
                tierCount: min(6, poolSize / 2), // Adaptive tier count
                noiseLevel: 0.1,
                scenario: .zipf,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)

            print("\nPool Size: \(poolSize) items")
            print("  Tau: \(String(format: "%.3f", metrics.kendallsTau))")
            print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
            print("  Max Tier Fraction: \(String(format: "%.1f%%", metrics.maxTierFraction * 100))")
            print("  Total Comparisons: \(metrics.comparisonsUsed)")
        }

        print("\n" + String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Scenario Comparison

    @Test("Scenario Comparison: Different Skill Distributions")
    func scenarioComparison() {
        print("\n" + String(repeating: "=", count: 80))
        print("SCENARIO COMPARISON: Algorithm Performance by Distribution Type")
        print(String(repeating: "=", count: 80))

        let scenarios: [(String, HeadToHeadSimulations.GroundTruthScenario)] = [
            ("Uniform", .uniform),
            ("Zipf (Power-law)", .zipf),
            ("2 Clusters", .clustered(2)),
            ("4 Clusters", .clustered(4)),
            ("Bimodal", .bimodal),
        ]

        for (name, scenario) in scenarios {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: 24,
                comparisonsPerItem: 3,
                tierCount: 6,
                noiseLevel: 0.1,
                scenario: scenario,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)

            print("\nScenario: \(name)")
            print("  Tau: \(String(format: "%.3f", metrics.kendallsTau))")
            print("  Tier Accuracy: \(String(format: "%.1f%%", metrics.tierAccuracy * 100))")
            print("  Max Tier Fraction: \(String(format: "%.1f%%", metrics.maxTierFraction * 100))")
            print("  Empty Tiers: \(metrics.emptyTierCount)")
            print("  Tier Size Variance: \(String(format: "%.2f", metrics.tierSizeVariance))")
        }

        print("\n" + String(repeating: "=", count: 80) + "\n")
    }

    // MARK: - Monte Carlo Stability Test

    @Test("Monte Carlo: Statistical Stability (100 runs)")
    func monteCarloStability() {
        print("\n" + String(repeating: "=", count: 80))
        print("MONTE CARLO STABILITY TEST: 100 Runs")
        print(String(repeating: "=", count: 80))

        let runs = 100
        var tauValues: [Double] = []
        var tierAccuracyValues: [Double] = []
        var churnValues: [Double] = []

        for _ in 0 ..< runs {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: 20,
                comparisonsPerItem: 3,
                tierCount: 5,
                noiseLevel: 0.1,
                scenario: .zipf,
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)
            tauValues.append(metrics.kendallsTau)
            tierAccuracyValues.append(metrics.tierAccuracy)
            churnValues.append(metrics.quickToFinalChurn)
        }

        // Calculate statistics
        let tauMean = tauValues.reduce(0, +) / Double(tauValues.count)
        let tauStd = sqrt(tauValues.map { pow($0 - tauMean, 2) }.reduce(0, +) / Double(tauValues.count))

        let accMean = tierAccuracyValues.reduce(0, +) / Double(tierAccuracyValues.count)
        let accStd = sqrt(tierAccuracyValues.map { pow($0 - accMean, 2) }
            .reduce(0, +) / Double(tierAccuracyValues.count))

        let churnMean = churnValues.reduce(0, +) / Double(churnValues.count)
        let churnStd = sqrt(churnValues.map { pow($0 - churnMean, 2) }.reduce(0, +) / Double(churnValues.count))

        print("\nKendall's Tau:")
        print("  Mean: \(String(format: "%.3f", tauMean)) ± \(String(format: "%.3f", tauStd))")
        print(
            "  Range: [\(String(format: "%.3f", tauValues.min() ?? 0)), \(String(format: "%.3f", tauValues.max() ?? 0))]",
        )

        print("\nTier Accuracy:")
        print("  Mean: \(String(format: "%.1f%%", accMean * 100)) ± \(String(format: "%.1f%%", accStd * 100))")

        print("\nChurn:")
        print("  Mean: \(String(format: "%.1f%%", churnMean * 100)) ± \(String(format: "%.1f%%", churnStd * 100))")

        print("\n" + String(repeating: "=", count: 80) + "\n")

        // Verify stability (standard deviation should be reasonable)
        #expect(tauStd < 0.15, "Tau variance should be < 0.15")
        #expect(accStd < 0.20, "Accuracy variance should be < 0.20")
    }
}
