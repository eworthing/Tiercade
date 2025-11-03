import Foundation

#if DEBUG && canImport(FoundationModels)

// MARK: - Result Models (Output/Reporting)

@available(iOS 26.0, macOS 26.0, *)
extension UnifiedPromptTester {

// MARK: - Single Test Result

/// Result from a single test run
internal struct SingleTestResult: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date

    /// Test configuration
    let promptId: String
    let promptName: String
    let queryId: String
    let queryText: String
    let targetCount: Int?
    let domain: String
    let nBucket: String
    let decoderId: String
    let decoderName: String
    let seed: UInt64
    let guidedSchema: Bool

    /// Raw response
    let response: String

    /// Parsed items
    let parsedItems: [String]
    let normalizedItems: [String]

    /// Metrics
    let totalItems: Int
    let uniqueItems: Int
    let duplicateCount: Int
    let dupRate: Double
    let passAtN: Bool          // Did we get N unique items?
    let surplusAtN: Int        // max(0, unique - N)

    /// Format analysis
    let jsonStrict: Bool       // Parsed as JSON array (not fallback)
    let insufficient: Bool     // Generated fewer than target
    let formatError: Bool      // Response had format issues

    /// Generation metadata
    let finishReason: String?  // "stop", "truncated", "error"
    let wasTruncated: Bool
    let maxTokensUsed: Int

    /// Timing
    let duration: TimeInterval
    let timePerUnique: Double  // duration / max(1, unique)

    /// Success indicator
    var isSuccess: Bool {
        passAtN && jsonStrict && !formatError
    }

    /// Quality score (0.0 to 1.0)
    var qualityScore: Double {
        let effectiveTarget = Double(max(1, targetCount ?? 40))
        let uniquenessScore = Double(uniqueItems) / effectiveTarget
        let formatScore = jsonStrict ? 1.0 : 0.5
        let truncationPenalty = wasTruncated ? 0.8 : 1.0
        return min(1.0, uniquenessScore * formatScore * truncationPenalty)
    }
}

// MARK: - Aggregate Test Result

/// Aggregated results across multiple test runs
internal struct AggregateTestResult: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date

    /// Configuration
    let promptId: String
    let promptName: String
    let promptText: String
    let totalRuns: Int

    /// Stratification
    let byNBucket: [String: BucketStats]      // "small", "medium", "large"
    let byDomain: [String: BucketStats]       // "food", "entertainment", etc.
    let byDecoder: [String: BucketStats]      // "greedy", "topk50-t08", etc.

    /// Overall metrics
    let overallStats: OverallStats

    /// Best and worst runs
    let bestRun: SingleTestResult?
    let worstRun: SingleTestResult?

    /// Statistics for a bucket
    struct BucketStats: Codable, Sendable {
        let count: Int
        let passAtNRate: Double
        let meanUniqueItems: Double
        let meanDupRate: Double
        let stdevDupRate: Double
        let meanTimePerUnique: Double
        let jsonStrictRate: Double
    }

    /// Overall statistics
    struct OverallStats: Codable, Sendable {
        let passAtNRate: Double
        let meanUniqueItems: Double
        let stdevUniqueItems: Double
        let meanDupRate: Double
        let stdevDupRate: Double
        let meanTimePerUnique: Double
        let stdevTimePerUnique: Double
        let jsonStrictRate: Double
        let truncationRate: Double
        let insufficientRate: Double
        let formatErrorRate: Double
        let meanQualityScore: Double
        let seedVariance: Double  // Variance in results across different seeds
    }
}

// MARK: - Test Report

/// Comprehensive test report for a full test suite
internal struct TestReport: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date

    /// Suite information
    let suiteId: String
    let suiteName: String
    let suiteDescription: String

    /// Execution summary
    let totalRuns: Int
    let successfulRuns: Int
    let failedRuns: Int
    let totalDuration: TimeInterval

    /// Environment info
    let environment: EnvironmentInfo

    /// Results by prompt
    let aggregateResults: [AggregateTestResult]

    /// All individual results
    let allResults: [SingleTestResult]

    /// Rankings
    let rankings: Rankings

    /// Environment information
    struct EnvironmentInfo: Codable, Sendable {
        let osVersion: String
        let osVersionString: String
        let hasTopP: Bool
        let device: String?
        let buildDate: String?
    }

    /// Rankings of prompts by various metrics
    struct Rankings: Codable, Sendable {
        let byPassRate: [RankedPrompt]
        let byQuality: [RankedPrompt]
        let bySpeed: [RankedPrompt]
        let byConsistency: [RankedPrompt]

        struct RankedPrompt: Codable, Sendable {
            let rank: Int
            let promptId: String
            let promptName: String
            let score: Double
            let metric: String
        }
    }

    /// Generate summary text
    internal func summaryText() -> String {
        let passRate = Double(successfulRuns) / Double(max(1, totalRuns)) * 100
        return """
        Test Suite: \(suiteName)
        Total Runs: \(totalRuns)
        Success Rate: \(String(format: "%.1f%%", passRate))
        Duration: \(String(format: "%.1f", totalDuration))s
        Top Prompt: \(rankings.byPassRate.first?.promptName ?? "N/A")
        """
    }
}

}
#endif
