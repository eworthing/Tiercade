import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Analysis & Parsing

@MainActor
internal extension SystemPromptTester {
static func normalize(_ text: String) -> String {
    // Unicode folding (handles diacritics and case)
    internal var normalized = text.folding(
        options: [.diacriticInsensitive, .caseInsensitive],
        locale: .current
    )

    // Remove leading articles (the/a/an)
    if let range = normalized.range(
        of: #"^(the|a|an)\s+"#,
        options: .regularExpression
    ) {
        normalized.removeSubrange(range)
    }

    // Remove content in parentheses/brackets
    normalized = normalized.replacingOccurrences(
        of: #"\s*[\(\[\{].*?[\)\]\}]"#,
        with: "",
        options: .regularExpression
    )

    // Strip punctuation (except apostrophes in words)
    normalized = normalized.replacingOccurrences(
        of: #"[^\w\s']"#,
        with: "",
        options: .regularExpression
    )

    // Collapse whitespace
    normalized = normalized.replacingOccurrences(
        of: #"\s+"#,
        with: " ",
        options: .regularExpression
    )

    return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
}

internal struct DuplicateAnalysisResult {
    internal let hasDuplicates: Bool
    internal let duplicateCount: Int
    internal let uniqueItems: Int
    internal let totalItems: Int
    internal let insufficient: Bool
    internal let wasJsonParsed: Bool
    internal let parsedItems: [String]
    internal let normalizedItems: [String]
}

internal struct ParsedItems {
    internal let items: [String]
    internal let wasJsonParsed: Bool
}

internal struct DuplicateDetectionResult {
    internal let seenNormalized: Set<String>
    internal let normalizedList: [String]
    internal let duplicateCount: Int
}

internal struct AnalysisMetrics {
    internal let totalItems: Int
    internal let uniqueItems: Int
    internal let insufficient: Bool
}

static func analyzeDuplicates(
    _ text: String,
    expectedCount: Int = 25
) -> DuplicateAnalysisResult {
    internal let parsed = parseItems(from: text)
    internal let duplicates = detectDuplicates(in: parsed.items)
    internal let metrics = calculateMetrics(
        itemCount: parsed.items.count,
        uniqueCount: duplicates.seenNormalized.count,
        expectedCount: expectedCount
    )

    return DuplicateAnalysisResult(
        hasDuplicates: duplicates.duplicateCount > 0,
        duplicateCount: duplicates.duplicateCount,
        uniqueItems: metrics.uniqueItems,
        totalItems: metrics.totalItems,
        insufficient: metrics.insufficient,
        wasJsonParsed: parsed.wasJsonParsed,
        parsedItems: parsed.items,
        normalizedItems: duplicates.normalizedList
    )
}

static func parseItems(from text: String) -> ParsedItems {
    if let items = tryParseAsJson(text) {
        return ParsedItems(items: items, wasJsonParsed: true)
    }
    return ParsedItems(items: parseAsText(text), wasJsonParsed: false)
}

static func tryParseAsJson(_ text: String) -> [String]? {
    guard let jsonData = text.data(using: .utf8),
          internal let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
        return nil
    }
    print("🧪   Parsed as JSON array")
    return jsonArray
}

static func parseAsText(_ text: String) -> [String] {
    internal let lines = text.components(separatedBy: .newlines)
    if let numberedItems = tryParseNumberedList(lines), !numberedItems.isEmpty {
        return numberedItems
    }
    return parseOnePerLine(lines)
}

static func tryParseNumberedList(_ lines: [String]) -> [String]? {
    internal var items: [String] = []
    for line in lines {
        internal let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let range = trimmed.range(of: #"^\d+[\.)]\s*"#, options: .regularExpression) {
            internal let content = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            items.append(content)
        }
    }
    return items.isEmpty ? nil : items
}

static func parseOnePerLine(_ lines: [String]) -> [String] {
    internal var items: [String] = []
    internal var lineCount = 0
    for line in lines {
        internal let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Skip empty lines and lines that look like commentary or prose
        if !trimmed.isEmpty
            && !trimmed.hasPrefix("//")
            && !trimmed.hasPrefix("#")
            && trimmed.count < 100 {  // Avoid prose paragraphs
            items.append(trimmed)
            lineCount += 1
            if lineCount > 50 { break }  // Cap to avoid runaway parsing
        }
    }
    return items
}

static func detectDuplicates(in items: [String]) -> DuplicateDetectionResult {
    internal var seenNormalized = Set<String>()
    internal var normalizedList: [String] = []
    internal var duplicateCount = 0

    for item in items {
        internal let normalized = normalize(item)
        if seenNormalized.contains(normalized) {
            duplicateCount += 1
            print("🧪   Duplicate detected: '\(item)' (normalized: '\(normalized)')")
        } else {
            seenNormalized.insert(normalized)
            normalizedList.append(normalized)
        }
    }

    return DuplicateDetectionResult(
        seenNormalized: seenNormalized,
        normalizedList: normalizedList,
        duplicateCount: duplicateCount
    )
}

static func calculateMetrics(
    itemCount: Int,
    uniqueCount: Int,
    expectedCount: Int
) -> AnalysisMetrics {
    internal let minimumRequired = Int(Double(expectedCount) * 0.8)
    internal let insufficient = itemCount < minimumRequired
    return AnalysisMetrics(
        totalItems: itemCount,
        uniqueItems: uniqueCount,
        insufficient: insufficient
    )
}

// Different system prompt variations to test
}
#endif
