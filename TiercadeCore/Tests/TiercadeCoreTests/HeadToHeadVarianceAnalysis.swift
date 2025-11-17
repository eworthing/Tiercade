import Foundation
import Testing
@testable import TiercadeCore

/// Comprehensive variance analysis to validate adaptive budget recommendations.
///
/// Tests the impact of:
/// - Comparison budgets (2, 3, 4, 5, 6 comp/item)
/// - Noise levels (0%, 5%, 10%, 15%)
/// - Pool sizes (10, 20, 30, 50 items)
///
/// Each scenario runs 100 Monte Carlo iterations to measure:
/// - Mean performance (Kendall's Tau, tier accuracy)
/// - Variance (std deviation)
/// - Stability (churn)
@Suite("HeadToHead Variance Analysis")
struct HeadToHeadVarianceAnalysis {

    // MARK: - Monte Carlo Runner

    struct MonteCarloResults {
        let scenario: String
        let meanTau: Double
        let stdTau: Double
        let minTau: Double
        let maxTau: Double
        let meanAccuracy: Double
        let stdAccuracy: Double
        let meanChurn: Double
        let iterations: Int

        var summary: String {
            """
            \(scenario):
              Tau: \(String(format: "%.3f", meanTau)) ± \(String(format: "%.3f", stdTau)) [\(String(format: "%.3f", minTau)), \(String(format: "%.3f", maxTau))]
              Accuracy: \(String(format: "%.1f%%", meanAccuracy * 100)) ± \(String(format: "%.1f%%", stdAccuracy * 100))
              Churn: \(String(format: "%.1f%%", meanChurn * 100))
            """
        }
    }

    static func runMonteCarloSuite(
        scenario: String,
        poolSize: Int,
        comparisonsPerItem: Int,
        tierCount: Int,
        noiseLevel: Double,
        iterations: Int = 100
    ) -> MonteCarloResults {
        var tauValues: [Double] = []
        var accuracyValues: [Double] = []
        var churnValues: [Double] = []

        for _ in 0..<iterations {
            let config = HeadToHeadSimulations.SimulationConfig(
                poolSize: poolSize,
                comparisonsPerItem: comparisonsPerItem,
                tierCount: tierCount,
                noiseLevel: noiseLevel,
                scenario: .zipf
            )

            let metrics = HeadToHeadSimulations.runSimulation(config: config)
            tauValues.append(metrics.kendallsTau)
            accuracyValues.append(metrics.tierAccuracy)
            churnValues.append(metrics.quickToFinalChurn)
        }

        let meanTau = tauValues.reduce(0, +) / Double(tauValues.count)
        let stdTau = sqrt(tauValues.map { pow($0 - meanTau, 2) }.reduce(0, +) / Double(tauValues.count))

        let meanAcc = accuracyValues.reduce(0, +) / Double(accuracyValues.count)
        let stdAcc = sqrt(accuracyValues.map { pow($0 - meanAcc, 2) }.reduce(0, +) / Double(accuracyValues.count))

        let meanChurn = churnValues.reduce(0, +) / Double(churnValues.count)

        return MonteCarloResults(
            scenario: scenario,
            meanTau: meanTau,
            stdTau: stdTau,
            minTau: tauValues.min() ?? 0,
            maxTau: tauValues.max() ?? 0,
            meanAccuracy: meanAcc,
            stdAccuracy: stdAcc,
            meanChurn: meanChurn,
            iterations: iterations
        )
    }

    // MARK: - Test 1: Comparison Budget Impact

    @Test("Impact of Comparison Budget (2-6 comp/item)")
    func comparisonBudgetImpact() {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST 1: COMPARISON BUDGET IMPACT (100 iterations each)")
        print("Pool: 20 items, Noise: 10%, Distribution: Zipf")
        print(String(repeating: "=", count: 80))

        let budgets = [2, 3, 4, 5, 6]
        var results: [MonteCarloResults] = []

        for budget in budgets {
            print("\nRunning Monte Carlo for \(budget) comp/item...")
            let result = Self.runMonteCarloSuite(
                scenario: "\(budget) comp/item",
                poolSize: 20,
                comparisonsPerItem: budget,
                tierCount: 5,
                noiseLevel: 0.10,
                iterations: 100
            )
            results.append(result)
            print(result.summary)
        }

        print("\n" + String(repeating: "-", count: 80))
        print("BUDGET ANALYSIS SUMMARY")
        print(String(repeating: "-", count: 80))
        print(String(format: "%-12s %10s %10s %10s %10s", "Budget", "Mean Tau", "Std Tau", "Accuracy", "Efficiency"))
        print(String(repeating: "-", count: 80))

        for (idx, result) in results.enumerated() {
            let budget = budgets[idx]
            let efficiency = result.meanTau / Double(budget)
            print(String(format: "%-12s %10.3f %10.3f %9.1f%% %10.3f",
                result.scenario,
                result.meanTau,
                result.stdTau,
                result.meanAccuracy * 100,
                efficiency
            ))
        }

        print(String(repeating: "=", count: 80) + "\n")

        // Find optimal budget
        if let best = results.max(by: { $0.meanTau < $1.meanTau }) {
            print("🏆 WINNER: \(best.scenario) with mean tau = \(String(format: "%.3f", best.meanTau))")
        }

        // Validate that higher budgets reduce variance
        let baseline = results[1] // 3 comp/item
        let improved = results[3] // 5 comp/item
        #expect(improved.stdTau < baseline.stdTau, "5 comp/item should reduce variance vs 3 comp/item")
        #expect(improved.meanTau > baseline.meanTau, "5 comp/item should improve mean tau vs 3 comp/item")
    }

    // MARK: - Test 2: Noise Sensitivity

    @Test("Impact of Noise Level (0%-15%)")
    func noiseSensitivity() {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST 2: NOISE SENSITIVITY (100 iterations each)")
        print("Pool: 20 items, Budget: 4 comp/item, Distribution: Zipf")
        print(String(repeating: "=", count: 80))

        let noiseLevels = [0.0, 0.05, 0.10, 0.15]
        var results: [MonteCarloResults] = []

        for noise in noiseLevels {
            print("\nRunning Monte Carlo for \(String(format: "%.0f%%", noise * 100)) noise...")
            let result = Self.runMonteCarloSuite(
                scenario: "\(String(format: "%.0f%%", noise * 100)) noise",
                poolSize: 20,
                comparisonsPerItem: 4,
                tierCount: 5,
                noiseLevel: noise,
                iterations: 100
            )
            results.append(result)
            print(result.summary)
        }

        print("\n" + String(repeating: "-", count: 80))
        print("NOISE ANALYSIS SUMMARY")
        print(String(repeating: "-", count: 80))
        print(String(format: "%-12s %10s %10s %10s %10s", "Noise", "Mean Tau", "Std Tau", "Accuracy", "Churn"))
        print(String(repeating: "-", count: 80))

        for result in results {
            print(String(format: "%-12s %10.3f %10.3f %9.1f%% %9.1f%%",
                result.scenario,
                result.meanTau,
                result.stdTau,
                result.meanAccuracy * 100,
                result.meanChurn * 100
            ))
        }

        print(String(repeating: "=", count: 80) + "\n")

        // Validate that lower noise improves performance
        let noNoise = results[0]
        let lowNoise = results[1]
        let medNoise = results[2]

        #expect(noNoise.meanTau > lowNoise.meanTau, "0% noise should outperform 5% noise")
        #expect(lowNoise.meanTau > medNoise.meanTau, "5% noise should outperform 10% noise")
    }

    // MARK: - Test 3: Pool Size Scaling

    @Test("Impact of Pool Size (10-50 items)")
    func poolSizeScaling() {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST 3: POOL SIZE SCALING (100 iterations each)")
        print("Budget: 4 comp/item, Noise: 10%, Distribution: Zipf")
        print(String(repeating: "=", count: 80))

        let poolSizes = [10, 20, 30, 50]
        var results: [MonteCarloResults] = []

        for poolSize in poolSizes {
            let tierCount = min(6, poolSize / 3) // Adaptive tier count
            print("\nRunning Monte Carlo for \(poolSize) items...")
            let result = Self.runMonteCarloSuite(
                scenario: "\(poolSize) items",
                poolSize: poolSize,
                comparisonsPerItem: 4,
                tierCount: tierCount,
                noiseLevel: 0.10,
                iterations: 100
            )
            results.append(result)
            print(result.summary)
        }

        print("\n" + String(repeating: "-", count: 80))
        print("SCALE ANALYSIS SUMMARY")
        print(String(repeating: "-", count: 80))
        print(String(format: "%-12s %10s %10s %10s %12s", "Pool Size", "Mean Tau", "Std Tau", "Accuracy", "Total Comp"))
        print(String(repeating: "-", count: 80))

        for (idx, result) in results.enumerated() {
            let poolSize = poolSizes[idx]
            let totalComp = poolSize * 4
            print(String(format: "%-12s %10.3f %10.3f %9.1f%% %12d",
                result.scenario,
                result.meanTau,
                result.stdTau,
                result.meanAccuracy * 100,
                totalComp
            ))
        }

        print(String(repeating: "=", count: 80) + "\n")

        // Validate performance remains acceptable across scales
        for result in results {
            #expect(result.meanTau > 0.40, "\(result.scenario) should achieve tau > 0.40")
            #expect(result.stdTau < 0.15, "\(result.scenario) should have variance < 0.15")
        }
    }

    // MARK: - Test 4: Optimal Configuration Validation

    @Test("Optimal Configuration: 20 items, 5 comp/item, 5% noise")
    func optimalConfiguration() {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST 4: OPTIMAL CONFIGURATION (100 iterations)")
        print("Pool: 20 items, Budget: 5 comp/item, Noise: 5%, Distribution: Zipf")
        print(String(repeating: "=", count: 80))

        let result = Self.runMonteCarloSuite(
            scenario: "Optimal Config",
            poolSize: 20,
            comparisonsPerItem: 5,
            tierCount: 5,
            noiseLevel: 0.05,
            iterations: 100
        )

        print("\n" + result.summary)

        print("\n" + String(repeating: "-", count: 80))
        print("QUALITY ASSESSMENT")
        print(String(repeating: "-", count: 80))

        let tauGrade = result.meanTau >= 0.70 ? "✅ Excellent" :
                       result.meanTau >= 0.60 ? "✅ Good" :
                       result.meanTau >= 0.50 ? "⚠️ Acceptable" : "❌ Poor"

        let varianceGrade = result.stdTau < 0.10 ? "✅ Low variance" :
                           result.stdTau < 0.15 ? "✅ Acceptable variance" : "⚠️ High variance"

        let accuracyGrade = result.meanAccuracy >= 0.60 ? "✅ Excellent" :
                           result.meanAccuracy >= 0.50 ? "✅ Good" :
                           result.meanAccuracy >= 0.40 ? "⚠️ Acceptable" : "❌ Poor"

        print("Mean Tau: \(String(format: "%.3f", result.meanTau)) - \(tauGrade)")
        print("Variance: \(String(format: "%.3f", result.stdTau)) - \(varianceGrade)")
        print("Accuracy: \(String(format: "%.1f%%", result.meanAccuracy * 100)) - \(accuracyGrade)")
        print("Churn: \(String(format: "%.1f%%", result.meanChurn * 100))")

        print(String(repeating: "=", count: 80) + "\n")

        // Validate optimal configuration meets targets
        #expect(result.meanTau >= 0.60, "Optimal config should achieve tau ≥ 0.60")
        #expect(result.stdTau < 0.12, "Optimal config should have low variance")
        #expect(result.meanAccuracy >= 0.45, "Optimal config should achieve accuracy ≥ 45%")
    }

    // MARK: - Test 5: Adaptive Budget Validation

    @Test("Adaptive Budget Strategy Validation")
    func adaptiveBudgetValidation() {
        print("\n" + String(repeating: "=", count: 80))
        print("TEST 5: ADAPTIVE BUDGET STRATEGY (100 iterations each)")
        print("Comparing fixed 3 comp/item vs adaptive budgets")
        print(String(repeating: "=", count: 80))

        let scenarios: [(String, Int, Int)] = [
            ("Small pool (10 items)", 10, 3),
            ("Medium pool (20 items)", 20, 4),
            ("Large pool (30 items)", 30, 5),
            ("XL pool (50 items)", 50, 6)
        ]

        var adaptiveResults: [MonteCarloResults] = []
        var fixedResults: [MonteCarloResults] = []

        for (name, poolSize, adaptiveBudget) in scenarios {
            let tierCount = min(6, poolSize / 3)

            // Test adaptive budget
            print("\n\(name) - Adaptive (\(adaptiveBudget) comp/item)...")
            let adaptive = Self.runMonteCarloSuite(
                scenario: "\(name) (adaptive: \(adaptiveBudget))",
                poolSize: poolSize,
                comparisonsPerItem: adaptiveBudget,
                tierCount: tierCount,
                noiseLevel: 0.10,
                iterations: 100
            )
            adaptiveResults.append(adaptive)

            // Test fixed 3 comp/item
            print("\(name) - Fixed (3 comp/item)...")
            let fixed = Self.runMonteCarloSuite(
                scenario: "\(name) (fixed: 3)",
                poolSize: poolSize,
                comparisonsPerItem: 3,
                tierCount: tierCount,
                noiseLevel: 0.10,
                iterations: 100
            )
            fixedResults.append(fixed)
        }

        print("\n" + String(repeating: "-", count: 80))
        print("ADAPTIVE vs FIXED COMPARISON")
        print(String(repeating: "-", count: 80))
        print(String(format: "%-20s %12s %12s %12s", "Scenario", "Adaptive Tau", "Fixed Tau", "Improvement"))
        print(String(repeating: "-", count: 80))

        for (idx, (name, _, adaptiveBudget)) in scenarios.enumerated() {
            let adaptive = adaptiveResults[idx]
            let fixed = fixedResults[idx]
            let improvement = ((adaptive.meanTau - fixed.meanTau) / fixed.meanTau) * 100

            print(String(format: "%-20s %12.3f %12.3f %11.1f%%",
                String(name.prefix(20)),
                adaptive.meanTau,
                fixed.meanTau,
                improvement
            ))
        }

        print(String(repeating: "=", count: 80) + "\n")

        // Validate that adaptive budgets improve performance for larger pools
        // Medium pool (20 items): 4 comp/item should beat 3 comp/item
        #expect(adaptiveResults[1].meanTau > fixedResults[1].meanTau,
                "Adaptive budget (4) should outperform fixed (3) for 20-item pools")

        // Large pool (30 items): 5 comp/item should significantly beat 3 comp/item
        #expect(adaptiveResults[2].meanTau > fixedResults[2].meanTau,
                "Adaptive budget (5) should outperform fixed (3) for 30-item pools")

        print("✅ CONCLUSION: Adaptive budgets validated for medium and large pools")
    }
}
