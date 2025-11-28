import Foundation

// swiftlint:disable force_unwrapping - Prototype analysis code, URL/file force unwraps are intentional
#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Analysis & IO Helpers

@available(iOS 26.0, macOS 26.0, *)
extension EnhancedPromptTester {
// MARK: - Analysis

internal struct ResponseAnalysis {
    let parsedItems: [String]
    let normalizedItems: [String]
    let totalItems: Int
    let uniqueItems: Int
    let duplicateCount: Int
    let dupRate: Double
    let passAtN: Bool
    let insufficient: Bool
    let formatError: Bool
    let wasJsonParsed: Bool
}

static func analyzeResponse(_ text: String, targetCount: Int) -> ResponseAnalysis {
    let (items, wasJsonParsed) = parseResponseItems(text)
    let (normalizedList, duplicateCount) = deduplicateItems(items)

    let totalItems = items.count
    let uniqueItems = normalizedList.count
    let dupRate = totalItems > 0 ? Double(duplicateCount) / Double(totalItems) : 0.0
    let passAtN = uniqueItems >= targetCount
    let insufficient = uniqueItems < Int(Double(targetCount) * 0.8)
    let formatError = items.isEmpty && !text.isEmpty

    return ResponseAnalysis(
        parsedItems: items,
        normalizedItems: normalizedList,
        totalItems: totalItems,
        uniqueItems: uniqueItems,
        duplicateCount: duplicateCount,
        dupRate: dupRate,
        passAtN: passAtN,
        insufficient: insufficient,
        formatError: formatError,
        wasJsonParsed: wasJsonParsed
    )
}

static func parseResponseItems(_ text: String) -> (items: [String], wasJsonParsed: Bool) {
    var items: [String] = []
    var wasJsonParsed = false

    if let jsonData = text.data(using: .utf8),
       let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
        items = jsonArray
        wasJsonParsed = true
    } else if let jsonData = text.data(using: .utf8),
              let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let itemsArray = jsonDict["items"] as? [String] {
        items = itemsArray
        wasJsonParsed = true
    } else {
        items = parseFallbackFormat(text)
    }

    return (items, wasJsonParsed)
}

static func parseFallbackFormat(_ text: String) -> [String] {
    var items: [String] = []
    let lines = text.components(separatedBy: .newlines)

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: #"^\d+[\.):\s]+"#, options: .regularExpression) {
            let content = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !content.isEmpty {
                items.append(content)
            }
        }
    }

    if items.isEmpty {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count < 100 {
                items.append(trimmed)
            }
        }
    }

    return items
}

static func deduplicateItems(_ items: [String]) -> (normalizedList: [String], duplicateCount: Int) {
    var seenNormalized = Set<String>()
    var normalizedList: [String] = []
    var duplicateCount = 0

    for item in items {
        let normalized = normalizeForComparison(item)
        if !normalized.isEmpty {
            if seenNormalized.contains(normalized) {
                duplicateCount += 1
            } else {
                seenNormalized.insert(normalized)
                normalizedList.append(normalized)
            }
        }
    }

    return (normalizedList, duplicateCount)
}

static func normalizeForComparison(_ text: String) -> String {
    var normalized = text.lowercased()
    normalized = normalized.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

    let articles = ["the ", "a ", "an "]
    for article in articles where normalized.hasPrefix(article) {
        normalized = String(normalized.dropFirst(article.count))
    }

    normalized = normalized.replacingOccurrences(of: "™", with: "")
    normalized = normalized.replacingOccurrences(of: "®", with: "")
    normalized = normalized.replacingOccurrences(
        of: #"\s*[\(\[\{].*?[\)\]\}]"#,
        with: "",
        options: .regularExpression
    )
    normalized = normalized.replacingOccurrences(of: "&", with: "and")
    normalized = normalized.components(separatedBy: CharacterSet.punctuationCharacters).joined()
    normalized = normalized.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")

    return normalized.trimmingCharacters(in: .whitespaces)
}

// MARK: - Logging

static func logToFile(_ message: String, filename: String = "tiercade_test_detailed.log") {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let logURL = documentsURL.appendingPathComponent(filename)

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logLine = "[\(timestamp)] \(message)\n"

    if let data = logLine.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }

    // Also print to console
    print(message)
}

static func clearLogFile(filename: String = "tiercade_test_detailed.log") {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let logURL = documentsURL.appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: logURL)
}

// MARK: - Save Results

static func saveFinalResults(_ results: [AggregateResult], to filename: String) async {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let outputURL = documentsURL.appendingPathComponent(filename)

    // Convert to JSON-serializable dict
    var jsonResults: [[String: Any]] = []
    for result in results {
        jsonResults.append([
            "promptName": result.promptName,
            "passAtNRate": result.passAtNRate,
            "jsonStrictRate": result.jsonStrictRate,
            "meanUniqueItems": result.meanUniqueItems,
            "meanTimePerUnique": result.meanTimePerUnique,
            "nBucket": result.nBucket,
            "domain": result.domain
        ])
    }

    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonResults, options: .prettyPrinted) {
        try? jsonData.write(to: outputURL)
        logToFile("💾 Saved results: \(outputURL.path)")
    }
}

static func saveStratifiedReport(_ results: [AggregateResult], to filename: String) async {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let outputURL = documentsURL.appendingPathComponent(filename)

    var report = """
    ================================================================================
    TIERCADE PILOT TEST - STRATIFIED REPORT
    ================================================================================
    Metric Priority: pass@N → jsonStrict% → timePerUnique → dupRate (diagnostic)
    ================================================================================

    """

    // By N-bucket
    let buckets = ["small", "medium", "large", "open"]
    for bucket in buckets {
        let bucketResults = results.filter { $0.nBucket == bucket }
        if bucketResults.isEmpty { continue }

        report += "\n### N-BUCKET: \(bucket.uppercased())\n"
        report += String(repeating: "─", count: 80) + "\n"

        let sorted = bucketResults.sorted { lhs, rhs in
            if abs(lhs.passAtNRate - rhs.passAtNRate) > 0.01 { return lhs.passAtNRate > rhs.passAtNRate }
            if abs(lhs.jsonStrictRate - rhs.jsonStrictRate) > 0.01 {
                return lhs.jsonStrictRate > rhs.jsonStrictRate
            }
            return lhs.meanTimePerUnique < rhs.meanTimePerUnique
        }

        for result in sorted {
            report += String(
                format: "%-20s | pass@N=%5.1f%% | jsonS=%5.1f%% | unique=%5.1f | tpu=%4.2fs | dup=%4.1f%%\n",
                result.promptName,
                result.passAtNRate * 100,
                result.jsonStrictRate * 100,
                result.meanUniqueItems,
                result.meanTimePerUnique,
                result.meanDupRate * 100
            )
        }
    }

    try? report.write(to: outputURL, atomically: true, encoding: .utf8)
    logToFile("📄 Saved stratified report: \(outputURL.path)")
}

static func saveRecommendations(_ results: [AggregateResult], to filename: String) async {
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let outputURL = documentsURL.appendingPathComponent(filename)

    var rec = """
    ================================================================================
    PRODUCTION RECOMMENDATIONS
    ================================================================================

    """

    let sortedByPass = results.sorted { $0.passAtNRate > $1.passAtNRate }
    if let best = sortedByPass.first {
        rec += "DEFAULT PROMPT: \(best.promptName)\n"
        rec += "  pass@N: \(String(format: "%.1f", best.passAtNRate * 100))%\n"
        rec += "  jsonStrict: \(String(format: "%.1f", best.jsonStrictRate * 100))%\n\n"
    }

    let avgJsonStrict = results.map { $0.jsonStrictRate }.reduce(0, +) / Double(results.count)
    if avgJsonStrict < 0.90 {
        rec += "⚠️  FORCE GUIDED SCHEMA: Average jsonStrict is " +
               "\(String(format: "%.1f", avgJsonStrict * 100))% (< 90%)\n\n"
    }

    try? rec.write(to: outputURL, atomically: true, encoding: .utf8)
    logToFile("📋 Saved recommendations: \(outputURL.path)")
}

// MARK: - Timeout

internal struct TimeoutError: Error, Sendable {}

nonisolated static func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
}
#endif
// swiftlint:enable force_unwrapping
