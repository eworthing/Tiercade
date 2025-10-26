import SwiftUI

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension AIChatOverlay {
    func startAcceptanceTests() {
        aiService.messages.append(AIChatMessage(
            content: "🧪 Starting acceptance test suite...",
            isUser: false
        ))

        Task {
            do {
                let report = try await AcceptanceTestSuite.runAll { print("🧪 \($0)") }
                handleAcceptanceTestResults(report)
            } catch {
                aiService.messages.append(AIChatMessage(
                    content: "❌ Test suite error: \(error.localizedDescription)",
                    isUser: false
                ))
            }
        }
    }

    func handleAcceptanceTestResults(_ report: AcceptanceTestSuite.TestReport) {
        let summary = buildAcceptanceTestSummary(report)
        aiService.messages.append(AIChatMessage(content: summary, isUser: false))

        saveAcceptanceTestReport(report)
        showAcceptanceTestToast(report)
    }

    func buildAcceptanceTestSummary(_ report: AcceptanceTestSuite.TestReport) -> String {
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

    func saveAcceptanceTestReport(_ report: AcceptanceTestSuite.TestReport) {
        let reportPath = "/tmp/tiercade_acceptance_test_report.json"
        do {
            try AcceptanceTestSuite.saveReport(report, to: reportPath)
            aiService.messages.append(AIChatMessage(
                content: "📄 Detailed report saved to: \(reportPath)",
                isUser: false
            ))
        } catch {
            print("❌ Failed to save report: \(error)")
        }
    }

    func showAcceptanceTestToast(_ report: AcceptanceTestSuite.TestReport) {
        if report.passRate == 1.0 {
            app.showSuccessToast("All Tests Passed!", message: "\(report.totalTests)/\(report.totalTests)")
        } else {
            app.showInfoToast("Tests Complete", message: "\(report.passed)/\(report.totalTests) passed")
        }
    }

    func startPilotTests() {
        aiService.messages.append(AIChatMessage(
            content: "🧪 Starting pilot test grid (this will take several minutes)...",
            isUser: false
        ))

        Task {
            let runner = PilotTestRunner { print("🧪 \($0)") }
            let report = await runner.runPilot()
            handlePilotTestResults(report, runner: runner)
        }
    }

    func handlePilotTestResults(_ report: PilotTestReport, runner: PilotTestRunner) {
        let summary = buildPilotTestSummary(report)
        aiService.messages.append(AIChatMessage(content: summary, isUser: false))

        savePilotTestReports(report, runner: runner)
        app.showSuccessToast("Pilot Tests Complete", message: "\(report.completedRuns) runs")
    }

    func buildPilotTestSummary(_ report: PilotTestReport) -> String {
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

    func savePilotTestReports(_ report: PilotTestReport, runner: PilotTestRunner) {
        let jsonPath = "/tmp/tiercade_pilot_test_report.json"
        let txtPath = "/tmp/tiercade_pilot_test_report.txt"

        do {
            try runner.saveReport(report, to: jsonPath)
            let textReport = runner.generateTextReport(report)
            try textReport.write(toFile: txtPath, atomically: true, encoding: .utf8)

            aiService.messages.append(AIChatMessage(
                content: "📄 Reports saved:\n• \(jsonPath)\n• \(txtPath)",
                isUser: false
            ))
        } catch {
            print("❌ Failed to save reports: \(error)")
        }
    }
}
#endif
