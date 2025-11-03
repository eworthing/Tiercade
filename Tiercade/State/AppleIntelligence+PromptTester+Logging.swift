import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Logging & Reporting

@MainActor
extension SystemPromptTester {
static func logTestHeader(testQuery: String, onProgress: @MainActor @escaping (String) -> Void) {
    onProgress("🧪 Starting automated test of \(prompts.count) system prompts...")
    onProgress("Test query: '\(testQuery)'")
    print("\n🧪 ========== SYSTEM PROMPT TESTING ==========")
    print("🧪 Test query: \(testQuery)")
    print("🧪 Testing \(prompts.count) different system prompts...\n")
}

static func logPromptStart(
    index: Int,
    prompt: String,
    onProgress: @MainActor @escaping (String) -> Void
) {
    onProgress("\n[\(index + 1)/\(prompts.count)] Testing prompt variant \(index + 1)...")
    print("🧪 [\(index + 1)/\(prompts.count)] Testing prompt variant...")
    print("🧪 Prompt preview: \(String(prompt.prefix(100)))...")
}

static func savePartialResults(results: [TestResult]) {
    let partialPath = "/tmp/tiercade_prompt_test_PARTIAL.txt"
    writeDetailedLog(results: results, to: partialPath)
    print("🧪 💾 Saved partial results (\(results.count) tests) to: \(partialPath)")
}

static func buildTestStatus(result: TestResult) -> String {
    if !result.hasDuplicates && !result.insufficient {
        return "✅ PASSED"
    } else if result.insufficient && !result.hasDuplicates {
        return "⚠️ INSUFFICIENT"
    } else if result.hasDuplicates && !result.insufficient {
        return "❌ DUPLICATES"
    } else {
        return "❌ BOTH"
    }
}

static func reportTestResult(
    result: TestResult,
    status: String,
    onProgress: @MainActor @escaping (String) -> Void
) {
    // Show raw response (no truncation)
    onProgress("\n📝 RAW RESPONSE:")
    onProgress(result.response)

    // Show parsed items (all of them)
    if !result.parsedItems.isEmpty {
        onProgress("\n📋 PARSED ITEMS (\(result.parsedItems.count)):")
        for (index, item) in result.parsedItems.enumerated() {
            onProgress("\(index + 1). \(item)")
        }
    }

    // Show normalized items (all of them)
    if !result.normalizedItems.isEmpty {
        onProgress("\n🔍 NORMALIZED ITEMS (\(result.normalizedItems.count) unique):")
        for (index, item) in result.normalizedItems.enumerated() {
            onProgress("\(index + 1). \(item)")
        }
    }

    // Show analysis results
    let summaryMessage = """

    📊 ANALYSIS:
    • Status: \(status)
    • Format: \(result.wasJsonParsed ? "JSON" : "Text")
    • Total items: \(result.totalItems)
    • Unique items: \(result.uniqueItems)
    • Duplicates: \(result.duplicateCount)
    \(result.insufficient ? "• ⚠️ Insufficient items (needed 20+)" : "")
    """
    onProgress(summaryMessage)

    print("🧪 Result: \(status)")
    print("🧪   - Total items: \(result.totalItems)")
    print("🧪   - Unique items: \(result.uniqueItems)")
    print("🧪   - Duplicates: \(result.duplicateCount)")
    if result.insufficient {
        print("🧪   ⚠️ Insufficient items (needed 20+)")
    }
    print("")
}

static func printTestSummary(results: [TestResult], onProgress: @MainActor @escaping (String) -> Void) {
    print("\n🧪 ========== TEST SUMMARY ==========")
    let successful = results.filter { !$0.hasDuplicates && !$0.insufficient }
    let onlyDuplicates = results.filter { $0.hasDuplicates && !$0.insufficient }
    let onlyInsufficient = results.filter { !$0.hasDuplicates && $0.insufficient }
    let bothFailures = results.filter { $0.hasDuplicates && $0.insufficient }

    print("🧪 Successful prompts: \(successful.count)/\(results.count)")
    print("🧪 Only duplicates: \(onlyDuplicates.count)")
    print("🧪 Only insufficient: \(onlyInsufficient.count)")
    print("🧪 Both failures: \(bothFailures.count)")

    let summaryMessage = """

    📊 RESULTS: \(successful.count) of \(results.count) prompts fully passed
    • ✅ Passed: \(successful.count) (no duplicates, sufficient items)
    • ❌ Duplicates only: \(onlyDuplicates.count)
    • ⚠️ Insufficient only: \(onlyInsufficient.count)
    • ❌ Both issues: \(bothFailures.count)
    """
    onProgress(summaryMessage)

    if !successful.isEmpty {
        print("\n✅ WORKING PROMPTS:")
        onProgress("\n✅ WORKING PROMPTS:")
        for result in successful {
            let msg = "  • Prompt #\(result.promptNumber): \(result.uniqueItems) unique items"
            onProgress(msg)
            print("   Prompt #\(result.promptNumber): \(result.uniqueItems) unique items")
        }
    } else {
        onProgress("\n❌ No prompts fully passed both checks.")
    }
}

static func saveCompleteLogs(results: [TestResult], onProgress: @MainActor @escaping (String) -> Void) {
    let sandboxTemp = FileManager.default.temporaryDirectory
    let logPath = sandboxTemp.appendingPathComponent("tiercade_prompt_test_results.txt").path
    let outputLogPath = sandboxTemp.appendingPathComponent("tiercade_test_output.log").path
    writeDetailedLog(results: results, to: logPath)
    onProgress("\n📁 Detailed results saved to: \(logPath)")
    onProgress("📁 Output log at: \(outputLogPath)")
    print("🧪 Detailed log saved to: \(logPath)")
    print("🧪 Output log at: \(outputLogPath)")
}
}
#endif
