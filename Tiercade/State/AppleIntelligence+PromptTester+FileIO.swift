import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - File I/O

@MainActor
extension SystemPromptTester {
static func writeDetailedLog(results: [TestResult], to path: String) {
    let log = buildLogContent(results: results)
    writeLogToFile(log: log, path: path)
}

static func buildLogContent(results: [TestResult]) -> String {
    var log = buildLogHeader(results: results)
    log += buildLogResultEntries(results: results)
    log += buildLogSummary(results: results)
    return log
}

static func buildLogHeader(results: [TestResult]) -> String {
    """
    ================================================================================
    TIERCADE PROMPT TESTING - DETAILED RESULTS
    ================================================================================
    Date: \(Date())
    Test Query: "What are the top 25 most popular animated series"
    Total Prompts Tested: \(results.count)


    """
}

static func buildLogResultEntries(results: [TestResult]) -> String {
    var entries = ""
    for result in results {
        let status = !result.hasDuplicates && !result.insufficient ? "PASSED"
            : result.insufficient && !result.hasDuplicates ? "INSUFFICIENT"
            : result.hasDuplicates && !result.insufficient ? "DUPLICATES"
            : "BOTH_FAILURES"

        entries += """
        ================================================================================
        PROMPT #\(result.promptNumber)
        ================================================================================
        Status: \(status)
        Format: \(result.wasJsonParsed ? "JSON" : "Text")
        Total Items: \(result.totalItems)
        Unique Items: \(result.uniqueItems)
        Duplicates: \(result.duplicateCount)
        Insufficient: \(result.insufficient)

        SYSTEM PROMPT:
        --------------------------------------------------------------------------------
        \(result.promptText)

        RAW RESPONSE:
        --------------------------------------------------------------------------------
        \(result.response)

        PARSED ITEMS (\(result.parsedItems.count)):
        --------------------------------------------------------------------------------
        \(result.parsedItems.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        NORMALIZED ITEMS (\(result.normalizedItems.count) unique):
        --------------------------------------------------------------------------------
        \(result.normalizedItems.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))


        """
    }
    return entries
}

static func buildLogSummary(results: [TestResult]) -> String {
    """
    ================================================================================
    SUMMARY
    ================================================================================
    Total Prompts: \(results.count)
    Passed: \(results.filter { !$0.hasDuplicates && !$0.insufficient }.count)
    Duplicates Only: \(results.filter { $0.hasDuplicates && !$0.insufficient }.count)
    Insufficient Only: \(results.filter { !$0.hasDuplicates && $0.insufficient }.count)
    Both Failures: \(results.filter { $0.hasDuplicates && $0.insufficient }.count)
    ================================================================================
    """
}

static func writeLogToFile(log: String, path: String) {
    do {
        // Ensure the directory exists
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Write the log file
        try log.write(toFile: path, atomically: true, encoding: .utf8)
        print("🧪 ✅ Log file written successfully to: \(path)")
        print("🧪 📁 File size: \(log.count) characters")

        // Mirror to the legacy aggregated log path for automation consumers
        let legacyPath = "/tmp/tiercade_test_output.log"
        try log.write(toFile: legacyPath, atomically: true, encoding: .utf8)
        print("🧪 ✅ Legacy log mirrored to: \(legacyPath)")
    } catch {
        handleLogWriteError(log: log, path: path, error: error)
    }
}

static func handleLogWriteError(log: String, path: String, error: Error) {
    print("🧪 ❌ ERROR writing log file to \(path)")
    print("🧪 ❌ Error: \(error)")
    print("🧪 ❌ Error description: \(error.localizedDescription)")

    // Fallback: try writing to Documents directory
    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fallbackPath = documentsPath.appendingPathComponent("tiercade_prompt_test_results.txt").path
        do {
            try log.write(toFile: fallbackPath, atomically: true, encoding: .utf8)
            print("🧪 ✅ Fallback: Log written to \(fallbackPath)")
        } catch {
            print("🧪 ❌ Fallback also failed: \(error)")
        }
    }
}
}
#endif
