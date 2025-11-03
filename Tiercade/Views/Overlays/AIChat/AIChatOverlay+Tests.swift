import SwiftUI

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension AIChatOverlay {
    // MARK: - Unified Prompt Tester (New)

    /// Run a unified test suite (new config-driven approach)
    internal func runUnifiedTestSuite(suiteId: String = "quick-smoke") {
        let debugLogPath = NSTemporaryDirectory().appending("tiercade_prompt_test_debug.log")

        ai.messages.append(AIChatMessage(
            content: "🚀 Starting unified test suite '\(suiteId)'...",
            isUser: false
        ))
        ai.messages.append(AIChatMessage(
            content: "🔍 Debug log: \(debugLogPath)",
            isUser: false
        ))

        Task {
            do {
                let report = try await UnifiedPromptTester.runSuite(suiteId: suiteId) { message in
                    Task { @MainActor in
                        ai.messages.append(AIChatMessage(content: message, isUser: false))
                    }
                }

                // Wrap post-processing in @MainActor to avoid data races
                await MainActor.run {
                    handleUnifiedTestReport(report)
                }
            } catch {
                await MainActor.run {
                    ai.messages.append(AIChatMessage(
                        content: "❌ Test error: \(error.localizedDescription)",
                        isUser: false
                    ))
                }
            }
        }
    }

    private func handleUnifiedTestReport(_ report: UnifiedPromptTester.TestReport) {
        let summary = buildUnifiedTestSummary(report)
        ai.messages.append(AIChatMessage(content: summary, isUser: false))

        saveUnifiedTestReport(report)
        showUnifiedTestToast(report)
    }

    private func buildUnifiedTestSummary(_ report: UnifiedPromptTester.TestReport) -> String {
        let passRate = Double(report.successfulRuns) / Double(max(1, report.totalRuns)) * 100
        let topPrompt = report.rankings.byPassRate.first

        return """
        ✅ \(report.suiteName) Complete

        Results:
        • Total runs: \(report.totalRuns)
        • Success rate: \(String(format: "%.1f%%", passRate))
        • Duration: \(String(format: "%.1f", report.totalDuration))s

        Top Prompt:
        • #1: \(topPrompt?.promptName ?? "N/A") (score: \(String(format: "%.3f", topPrompt?.score ?? 0)))

        Environment:
        • OS: \(report.environment.osVersion)
        • Top-P: \(report.environment.hasTopP ? "Available" : "N/A")

        📄 Full report saved to temp directory
        """
    }

    private func saveUnifiedTestReport(_ report: UnifiedPromptTester.TestReport) {
        // Use NSTemporaryDirectory for sandbox compatibility
        let reportPath = NSTemporaryDirectory()
            .appending("tiercade_unified_test_report.json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: URL(fileURLWithPath: reportPath))

            ai.messages.append(AIChatMessage(
                content: "📄 Detailed report: \(reportPath)",
                isUser: false
            ))
        } catch {
            print("❌ Failed to save report: \(error)")
            ai.messages.append(AIChatMessage(
                content: "⚠️ Could not save report file: \(error.localizedDescription)",
                isUser: false
            ))
        }
    }

    private func showUnifiedTestToast(_ report: UnifiedPromptTester.TestReport) {
        let passRate = Double(report.successfulRuns) / Double(max(1, report.totalRuns))

        if passRate == 1.0 {
            app.showSuccessToast("All Tests Passed!", message: "\(report.totalRuns)/\(report.totalRuns)")
        } else {
            app.showInfoToast("Tests Complete", message: "\(report.successfulRuns)/\(report.totalRuns) passed")
        }
    }

    // MARK: - Legacy Test Integrations (Deprecated)

    /// @deprecated Use runUnifiedTestSuite(suiteId:) instead
    internal func startAcceptanceTests() {
        ai.messages.append(AIChatMessage(
            content: "🧪 Starting acceptance test suite...",
            isUser: false
        ))

        Task {
            do {
                let report = try await AcceptanceTestSuite.runAll { print("🧪 \($0)") }
                handleAcceptanceTestResults(report)
            } catch {
                ai.messages.append(AIChatMessage(
                    content: "❌ Test suite error: \(error.localizedDescription)",
                    isUser: false
                ))
            }
        }
    }

    internal func handleAcceptanceTestResults(_ report: AcceptanceTestSuite.TestReport) {
        let summary = buildAcceptanceTestSummary(report)
        ai.messages.append(AIChatMessage(content: summary, isUser: false))

        saveAcceptanceTestReport(report)
        showAcceptanceTestToast(report)
    }

    internal func buildAcceptanceTestSummary(_ report: AcceptanceTestSuite.TestReport) -> String {
        let failedTests = report.results
            .filter { !$0.passed }
            .map { "• \($0.testName): \($0.message)" }
            .joined(separator: "\n")

        return """
            ✅ Test Results: \(report.passed)/\(report.totalTests) passed \
            (\(String(format: "%.1f", report.passRate * 100))%)

            Environment:
            • OS: \(report.environment.osVersion)
            • Top-P: \(report.environment.hasTopP ? "Available" : "Not available")

            Failed tests:
            \(failedTests)
            """
    }

    internal func saveAcceptanceTestReport(_ report: AcceptanceTestSuite.TestReport) {
        let reportPath = "/tmp/tiercade_acceptance_test_report.json"
        do {
            try AcceptanceTestSuite.saveReport(report, to: reportPath)
            ai.messages.append(AIChatMessage(
                content: "📄 Detailed report saved to: \(reportPath)",
                isUser: false
            ))
        } catch {
            print("❌ Failed to save report: \(error)")
        }
    }

    internal func showAcceptanceTestToast(_ report: AcceptanceTestSuite.TestReport) {
        if report.passRate == 1.0 {
            app.showSuccessToast("All Tests Passed!", message: "\(report.totalTests)/\(report.totalTests)")
        } else {
            app.showInfoToast("Tests Complete", message: "\(report.passed)/\(report.totalTests) passed")
        }
    }

    internal func startPilotTests() {
        ai.messages.append(AIChatMessage(
            content: "🧪 Starting pilot test grid (this will take several minutes)...",
            isUser: false
        ))

        Task {
            let runner = PilotTestRunner { print("🧪 \($0)") }
            let report = await runner.runPilot()
            handlePilotTestResults(report, runner: runner)
        }
    }

    internal func handlePilotTestResults(_ report: PilotTestReport, runner: PilotTestRunner) {
        let summary = buildPilotTestSummary(report)
        ai.messages.append(AIChatMessage(content: summary, isUser: false))

        savePilotTestReports(report, runner: runner)
        app.showSuccessToast("Pilot Tests Complete", message: "\(report.completedRuns) runs")
    }

    internal func buildPilotTestSummary(_ report: PilotTestReport) -> String {
        let passBySize = report.summary.passBySize
            .sorted { Int($0.key) ?? 0 < Int($1.key) ?? 0 }
            .map { "• N=\($0.key): \(String(format: "%.0f%%", $0.value * 100))" }
            .joined(separator: "\n")

        let topPerformers = report.summary.topPerformers
            .map { "• \($0)" }
            .joined(separator: "\n")

        let passRate = String(format: "%.1f%%", report.summary.overallPassRate * 100)
        let meanDup = String(format: "%.1f", report.summary.meanDupRate * 100)
        let stdevDup = String(format: "%.1f", report.summary.stdevDupRate * 100)
        let throughput = String(format: "%.1f", report.summary.meanItemsPerSecond)

        return """
            ✅ Pilot Test Complete

            Overall Metrics:
            • Pass@N rate: \(passRate)
            • Mean dup rate: \(meanDup)±\(stdevDup)%%
            • Throughput: \(throughput) items/sec

            Pass by Size:
            \(passBySize)

            Top Performers:
            \(topPerformers)
            """
    }

    internal func savePilotTestReports(_ report: PilotTestReport, runner: PilotTestRunner) {
        let jsonPath = "/tmp/tiercade_pilot_test_report.json"
        let txtPath = "/tmp/tiercade_pilot_test_report.txt"

        do {
            try runner.saveReport(report, to: jsonPath)
            let textReport = runner.generateTextReport(report)
            try textReport.write(toFile: txtPath, atomically: true, encoding: .utf8)

            ai.messages.append(AIChatMessage(
                content: "📄 Reports saved:\n• \(jsonPath)\n• \(txtPath)",
                isUser: false
            ))
        } catch {
            print("❌ Failed to save reports: \(error)")
        }
    }
}
#endif
