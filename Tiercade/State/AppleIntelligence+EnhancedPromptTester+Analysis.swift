import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Analysis & IO Helpers

@available(iOS 26.0, macOS 26.0, *)
internal extension EnhancedPromptTester {
// MARK: - Analysis

internal struct ResponseAnalysis {
    internal let parsedItems: [String]
    internal let normalizedItems: [String]
    internal let totalItems: Int
    internal let uniqueItems: Int
    internal let duplicateCount: Int
    internal let dupRate: Double
    internal let passAtN: Bool
    internal let insufficient: Bool
    internal let formatError: Bool
    internal let wasJsonParsed: Bool
}

static func analyzeResponse(_ text: String, targetCount: Int) -> ResponseAnalysis {
    internal let (items, wasJsonParsed) = parseResponseItems(text)
    internal let (normalizedList, duplicateCount) = deduplicateItems(items)

    internal let totalItems = items.count
    internal let uniqueItems = normalizedList.count
    internal let dupRate = totalItems > 0 ? Double(duplicateCount) / Double(totalItems) : 0.0
    internal let passAtN = uniqueItems >= targetCount
    internal let insufficient = uniqueItems < Int(Double(targetCount) * 0.8)
    internal let formatError = items.isEmpty && !text.isEmpty

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
    internal var items: [String] = []
    internal var wasJsonParsed = false

    if let jsonData = text.data(using: .utf8),
       internal let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
        items = jsonArray
        wasJsonParsed = true
    } else if let jsonData = text.data(using: .utf8),
              internal let jsonDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              internal let itemsArray = jsonDict["items"] as? [String] {
        items = itemsArray
        wasJsonParsed = true
    } else {
        items = parseFallbackFormat(text)
    }

    return (items, wasJsonParsed)
}

static func parseFallbackFormat(_ text: String) -> [String] {
    internal var items: [String] = []
    internal let lines = text.components(separatedBy: .newlines)

    for line in lines {
        internal let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: #"^\d+[\.):\s]+"#, options: .regularExpression) {
            internal let content = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !content.isEmpty {
                items.append(content)
            }
        }
    }

    if items.isEmpty {
        for line in lines {
            internal let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count < 100 {
                items.append(trimmed)
            }
        }
    }

    return items
}

static func deduplicateItems(_ items: [String]) -> (normalizedList: [String], duplicateCount: Int) {
    internal var seenNormalized = Set<String>()
    internal var normalizedList: [String] = []
    internal var duplicateCount = 0

    for item in items {
        internal let normalized = normalizeForComparison(item)
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
    internal var normalized = text.lowercased()
    normalized = normalized.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

    internal let articles = ["the ", "a ", "an "]
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
    internal let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    internal let logURL = documentsURL.appendingPathComponent(filename)

    internal let timestamp = ISO8601DateFormatter().string(from: Date())
    internal let logLine = "[\(timestamp)] \(message)\n"

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
    internal let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    internal let logURL = documentsURL.appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: logURL)
}

// MARK: - Save Results

static func saveFinalResults(_ results: [AggregateResult], to filename: String) async {
    internal let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    internal let outputURL = documentsURL.appendingPathComponent(filename)

    // Convert to JSON-serializable dict
    internal var jsonResults: [[String: Any]] = []
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
    internal let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    internal let outputURL = documentsURL.appendingPathComponent(filename)

    internal var report = """
    ================================================================================
    TIERCADE PILOT TEST - STRATIFIED REPORT
    ================================================================================
    Metric Priority: pass@N → jsonStrict% → timePerUnique → dupRate (diagnostic)
    ================================================================================

    """

    // By N-bucket
    internal let buckets = ["small", "medium", "large", "open"]
    for bucket in buckets {
        internal let bucketResults = results.filter { $0.nBucket == bucket }
        if bucketResults.isEmpty { continue }

        report += "\n### N-BUCKET: \(bucket.uppercased())\n"
        report += String(repeating: "─", count: 80) + "\n"

        internal let sorted = bucketResults.sorted { lhs, rhs in
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
    internal let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    internal let outputURL = documentsURL.appendingPathComponent(filename)

    internal var rec = """
    ================================================================================
    PRODUCTION RECOMMENDATIONS
    ================================================================================

    """

    internal let sortedByPass = results.sorted { $0.passAtNRate > $1.passAtNRate }
    if let best = sortedByPass.first {
        rec += "DEFAULT PROMPT: \(best.promptName)\n"
        rec += "  pass@N: \(String(format: "%.1f", best.passAtNRate * 100))%\n"
        rec += "  jsonStrict: \(String(format: "%.1f", best.jsonStrictRate * 100))%\n\n"
    }

    internal let avgJsonStrict = results.map { $0.jsonStrictRate }.reduce(0, +) / Double(results.count)
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
        internal let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
}
#endif
