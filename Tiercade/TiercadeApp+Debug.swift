//
//  TiercadeApp+Debug.swift
//  Tiercade
//
//  DEBUG-only test runner functions extracted from TiercadeApp
//

import SwiftUI

#if DEBUG && canImport(FoundationModels)
import FoundationModels

extension TiercadeApp {
    func checkForAutomatedTesting() {
        let testHandlers: [(String, () -> Void)] = [
            ("-runUnifiedTests", runUnifiedTests),
            ("-runEnhancedPromptTests", runEnhancedPromptTests),
            ("-runPromptTests", runPromptTests),
            ("-runAcceptanceTests-legacy", runAcceptanceTestsLegacy),
            ("-runCoordinatorExperiments", runCoordinatorExperiments),
            ("-runCoordinatorHybrid", runCoordinatorHybrid),
            ("-runCoordinatorMediumGrid", runCoordinatorMediumGrid),
            ("-runPilotTests", runPilotTests),
            ("-runDiagnostics", runDiagnostics)
        ]

        for (argument, handler) in testHandlers where CommandLine.arguments.contains(argument) {
            handler()
            return
        }
    }

    private func runUnifiedTests() {
        print("🧪 Detected -runUnifiedTests launch argument")

        let args = CommandLine.arguments
        var suiteId = "quick-smoke"

        if let flagIndex = args.firstIndex(of: "-runUnifiedTests"),
           flagIndex + 1 < args.count {
            let nextArg = args[flagIndex + 1]
            if !nextArg.hasPrefix("-") {
                suiteId = nextArg
                print("🧪 Using suite: \(suiteId)")
            }
        }

        print("🧪 Starting unified test suite '\(suiteId)'...")

        Task { @MainActor in
            if !appState.aiGeneration.showAIChat {
                appState.aiGeneration.showAIChat = true
                print("🤖 Auto-opened AI Chat for test progress")
            }

            try? await Task.sleep(for: .milliseconds(500))

            if #available(iOS 26.0, macOS 26.0, *) {
                await executeUnifiedTests(suiteId: suiteId)
            } else {
                print("❌ Unified tests require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func executeUnifiedTests(suiteId: String) async {
        do {
            let report = try await UnifiedPromptTester.runSuite(suiteId: suiteId) { message in
                print("🧪 \(message)")
                Task { @MainActor in
                    self.appState.appendTestMessage(message)
                }
            }

            printUnifiedTestResults(report)

            let reportURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("tiercade_unified_test_report.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: reportURL)

            let rate = Double(report.successfulRuns) / Double(max(1, report.totalRuns)) * 100
            let summaryMessage = """
            📊 UNIFIED TESTS COMPLETE!
            Suite: \(report.suiteName)
            Success rate: \(String(format: "%.1f%%", rate))
            Report saved: \(reportURL.path)
            """

            print("🧪 ========================================")
            print(summaryMessage)
            print("🧪 ========================================")

            await MainActor.run {
                appState.appendTestMessage(summaryMessage)
            }

            let allPassed = report.successfulRuns == report.totalRuns
            try? await Task.sleep(for: .seconds(2))
            exit(allPassed ? 0 : 1)
        } catch {
            let errorMsg = "❌ Unified test error: \(error)"
            print(errorMsg)
            print("❌ Error details: \(String(describing: error))")

            await MainActor.run {
                appState.appendTestMessage(errorMsg)
            }
            exit(2)
        }
    }

    private func printUnifiedTestResults(_ report: UnifiedPromptTester.TestReport) {
        let passRate = Double(report.successfulRuns) / Double(max(1, report.totalRuns)) * 100
        let topPrompt = report.rankings.byPassRate.first

        print("\n📊 RESULTS:")
        print("  • Total runs: \(report.totalRuns)")
        print("  • Successful: \(report.successfulRuns)")
        print("  • Success rate: \(String(format: "%.1f%%", passRate))")
        print("  • Duration: \(String(format: "%.1f", report.totalDuration))s")

        var byBucket: [String: (ok: Int, total: Int)] = [:]
        for r in report.allResults {
            var v = byBucket[r.nBucket] ?? (0, 0)
            v.total += 1
            if r.passAtN { v.ok += 1 }
            byBucket[r.nBucket] = v
        }
        if !byBucket.isEmpty {
            print("\n📈 N‑bucket success rates:")
            for bucket in ["small", "medium", "large"] {
                if let v = byBucket[bucket] {
                    let rate = Double(v.ok) / Double(max(1, v.total)) * 100
                    print("  • \(bucket): \(String(format: "%.1f%%", rate)) (")
                }
            }
        }

        if let top = topPrompt {
            print("\n🏆 TOP PROMPT:")
            print("  • #1: \(top.promptName)")
            print("  • Score: \(String(format: "%.3f", top.score))")
            print("  • Metric: \(top.metric)")
        }

        print("\n🖥️  ENVIRONMENT:")
        print("  • OS: \(report.environment.osVersion)")
        print("  • Top-P: \(report.environment.hasTopP ? "Available" : "N/A")")
    }

    private func runCoordinatorExperiments() {
        print("🔧 Detected -runCoordinatorExperiments launch argument")
        print("🔧 Starting coordinator experiments (baseline)…")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                if !appState.aiGeneration.showAIChat {
                    appState.aiGeneration.showAIChat = true
                    print("🤖 Auto-opened AI Chat for experiment progress")
                }
                try? await Task.sleep(for: .milliseconds(400))

                let runner = CoordinatorExperimentRunner { print("🔧 \($0)") }
                let report = await runner.runDefaultSuite()

                print("🔧 ========================================")
                print("🔧 COORDINATOR EXPERIMENTS COMPLETE!")
                print("🔧 Results: \(report.successfulRuns)/\(report.totalRuns) runs passed")
                print("🔧 Report saved: \(NSTemporaryDirectory())coordinator_experiments_report.json")
                print("🔧 ========================================")

                let ok = report.successfulRuns == report.totalRuns
                try? await Task.sleep(for: .seconds(2))
                exit(ok ? 0 : 1)
            } else {
                print("❌ Coordinator experiments require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    private func runCoordinatorHybrid() {
        print("🔧 Detected -runCoordinatorHybrid launch argument")
        print("🔧 Starting coordinator HYBRID comparison…")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                if !appState.aiGeneration.showAIChat {
                    appState.aiGeneration.showAIChat = true
                    print("🤖 Auto-opened AI Chat for experiment progress")
                }
                try? await Task.sleep(for: .milliseconds(400))

                let runner = CoordinatorExperimentRunner { print("🔧 \($0)") }
                let report = await runner.runHybridComparisonSuite()

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("coordinator_experiments_hybrid_report.json")
                if let data = try? encoder.encode(report) { try? data.write(to: url) }

                print("🔧 ========================================")
                print("🔧 COORDINATOR HYBRID COMPARISON COMPLETE!")
                print("🔧 Results: \(report.successfulRuns)/\(report.totalRuns) runs passed")
                print("🔧 Report saved: \(url.path)")
                print("🔧 ========================================")

                let ok = report.successfulRuns == report.totalRuns
                try? await Task.sleep(for: .seconds(2))
                exit(ok ? 0 : 1)
            } else {
                print("❌ Coordinator experiments require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    private func runCoordinatorMediumGrid() {
        print("🔧 Detected -runCoordinatorMediumGrid launch argument")
        print("🔧 Starting coordinator medium‑N micro‑grid…")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                if !appState.aiGeneration.showAIChat {
                    appState.aiGeneration.showAIChat = true
                    print("🤖 Auto-opened AI Chat for experiment progress")
                }
                try? await Task.sleep(for: .milliseconds(400))

                let runner = CoordinatorExperimentRunner { print("🔧 \($0)") }
                let report = await runner.runMediumNMicroGrid()

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("coordinator_experiments_medium_grid_report.json")
                if let data = try? encoder.encode(report) { try? data.write(to: url) }

                print("🔧 ========================================")
                print("🔧 COORDINATOR MEDIUM‑N GRID COMPLETE!")
                print("🔧 Results: \(report.successfulRuns)/\(report.totalRuns) runs passed")
                print("🔧 Report saved: \(url.path)")
                print("🔧 ========================================")

                try? await Task.sleep(for: .seconds(2))
                exit(0)
            } else {
                print("❌ Coordinator experiments require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    private func runEnhancedPromptTests() {
        print("🧪 Detected -runEnhancedPromptTests launch argument")
        print("🧪 Starting ENHANCED multi-run prompt testing...")

        Task { @MainActor in
            let results = await EnhancedPromptTester.testPrompts { print("🧪 \($0)") }
            printEnhancedTestResults(results)
            try? await Task.sleep(for: .seconds(2))
            exit(0)
        }
    }

    private func printEnhancedTestResults(_ results: [EnhancedPromptTester.AggregateResult]) {
        print("🧪 ========================================")
        print("🧪 ENHANCED TESTING COMPLETE!")
        print("🧪 Total prompts tested: \(results.count)")
        print("🧪 Total runs: \(results.reduce(0) { $0 + $1.totalRuns })")

        let sorted = results.sorted { $0.meanDupRate < $1.meanDupRate }
        print("\n🏆 TOP 3 PROMPTS:")
        for (idx, result) in sorted.prefix(3).enumerated() {
            print("  \(idx + 1). Prompt #\(result.promptNumber)")
            let dupRate = String(format: "%.1f±%.1f%%", result.meanDupRate * 100, result.stdevDupRate * 100)
            print("     DupRate: \(dupRate)")
            print("     Insufficient: \(String(format: "%.1f%%", result.insufficientRate * 100))")
        }

        print("\n📁 Results: /tmp/tiercade_enhanced_test_results.json")
        print("🧪 ========================================")
    }

    private func runPromptTests() {
        print("🧪 Detected -runPromptTests launch argument")
        print("🧪 Starting automated prompt testing...")

        Task { @MainActor in
            let results = await SystemPromptTester.testPrompts { print("🧪 \($0)") }

            print("🧪 ========================================")
            print("🧪 Testing complete!")
            print("🧪 Total tests: \(results.count)")
            print("🧪 Passed: \(results.filter { !$0.hasDuplicates && !$0.insufficient }.count)")
            print("🧪 Log file: /tmp/tiercade_prompt_test_results.txt")
            print("🧪 ========================================")

            try? await Task.sleep(for: .seconds(2))
            exit(0)
        }
    }

    private func runAcceptanceTestsLegacy() {
        print("🧪 Detected -runAcceptanceTests-legacy (deprecated, use -runAcceptanceTests)")
        print("🧪 Starting acceptance tests...")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                await executeAcceptanceTests()
            } else {
                print("❌ Acceptance tests require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func executeAcceptanceTests() async {
        do {
            let report = try await AcceptanceTestSuite.runAll { print("🧪 \($0)") }
            try? AcceptanceTestSuite.saveReport(report, to: "/tmp/tiercade_acceptance_test_report.json")

            print("🧪 ========================================")
            print("🧪 ACCEPTANCE TESTS COMPLETE!")
            print("🧪 Results: \(report.passed)/\(report.totalTests) tests passed")
            print("🧪 Report saved: /tmp/tiercade_acceptance_test_report.json")
            print("🧪 ========================================")

            try? await Task.sleep(for: .seconds(2))
            exit(report.passed == report.totalTests ? 0 : 1)
        } catch {
            print("❌ Test suite error: \(error)")
            exit(2)
        }
    }

    private func runPilotTests() {
        print("🧪 Detected -runPilotTests launch argument")
        print("🧪 Starting pilot tests (this will take 5-15 minutes)...")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                await executePilotTests()
            } else {
                print("❌ Pilot tests require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func executePilotTests() async {
        let runner = PilotTestRunner { print("🧪 \($0)") }
        let report = await runner.runPilot()

        let textReport = runner.generateTextReport(report)
        try? textReport.write(toFile: "/tmp/tiercade_pilot_test_report.txt", atomically: true, encoding: .utf8)

        print("🧪 ========================================")
        print("🧪 PILOT TESTS COMPLETE!")
        print("🧪 Pass@N: \(String(format: "%.1f%%", report.summary.overallPassRate * 100))")
        print("🧪 Reports saved:")
        print("🧪   - /tmp/tiercade_pilot_test_report.json")
        print("🧪   - /tmp/tiercade_pilot_test_report.txt")
        print("🧪 ========================================")

        try? await Task.sleep(for: .seconds(2))
        exit(0)
    }

    private func runDiagnostics() {
        print("🔬 Detected -runDiagnostics launch argument")
        print("🔬 Starting model output diagnostics...")

        Task { @MainActor in
            if #available(iOS 26.0, macOS 26.0, *) {
                await executeDiagnostics()
            } else {
                print("❌ Diagnostics require iOS 26.0+ or macOS 26.0+")
                exit(1)
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private func executeDiagnostics() async {
        let diagnostics = ModelDiagnostics { print("🔬 \($0)") }
        let report = await diagnostics.runAll()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/tiercade_diagnostics_report.json"))
        }

        print("🔬 ========================================")
        print("🔬 DIAGNOSTICS COMPLETE!")
        print("🔬 Successful tests: \(report.results.filter { $0.success }.count)/\(report.results.count)")
        print("🔬 Report saved: /tmp/tiercade_diagnostics_report.json")
        print("🔬 ========================================")

        try? await Task.sleep(for: .seconds(2))
        exit(0)
    }
}
#else
extension TiercadeApp {
    func checkForAutomatedTesting() {
        // No-op on release builds or when FoundationModels unavailable
    }
}
#endif
