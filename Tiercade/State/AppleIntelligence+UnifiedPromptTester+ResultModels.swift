import Foundation

#if DEBUG && canImport(FoundationModels)

// MARK: - Result Models (Output/Reporting)

@available(iOS 26.0, macOS 26.0, *)
internal extension UnifiedPromptTester {

// MARK: - Single Test Result

/// Result from a single test run
internal struct SingleTestResult: Codable, Identifiable, Sendable {
    internal let id: UUID
    internal let timestamp: Date

    /// Test configuration
    internal let promptId: String
    internal let promptName: String
    internal let queryId: String
    internal let queryText: String
    internal let targetCount: Int?
    internal let domain: String
    internal let nBucket: String
    internal let decoderId: String
    internal let decoderName: String
    internal let seed: UInt64
    internal let guidedSchema: Bool

    /// Raw response
    internal let response: String

    /// Parsed items
    internal let parsedItems: [String]
    internal let normalizedItems: [String]

    /// Metrics
    internal let totalItems: Int
    internal let uniqueItems: Int
    internal let duplicateCount: Int
    internal let dupRate: Double
    internal let passAtN: Bool          // Did we get N unique items?
    internal let surplusAtN: Int        // max(0, unique - N)

    /// Format analysis
    internal let jsonStrict: Bool       // Parsed as JSON array (not fallback)
    internal let insufficient: Bool     // Generated fewer than target
    internal let formatError: Bool      // Response had format issues

    /// Generation metadata
    internal let finishReason: String?  // "stop", "truncated", "error"
    internal let wasTruncated: Bool
    internal let maxTokensUsed: Int

    /// Timing
    internal let duration: TimeInterval
    internal let timePerUnique: Double  // duration / max(1, unique)

    /// Success indicator
    internal var isSuccess: Bool {
        passAtN && jsonStrict && !formatError
    }

    /// Quality score (0.0 to 1.0)
    internal var qualityScore: Double {
        internal let effectiveTarget = Double(max(1, targetCount ?? 40))
        internal let uniquenessScore = Double(uniqueItems) / effectiveTarget
        internal let formatScore = jsonStrict ? 1.0 : 0.5
        internal let truncationPenalty = wasTruncated ? 0.8 : 1.0
        return min(1.0, uniquenessScore * formatScore * truncationPenalty)
    }
}

// MARK: - Aggregate Test Result

/// Aggregated results across multiple test runs
internal struct AggregateTestResult: Codable, Identifiable, Sendable {
    internal let id: UUID
    internal let timestamp: Date

    /// Configuration
    internal let promptId: String
    internal let promptName: String
    internal let promptText: String
    internal let totalRuns: Int

    /// Stratification
    internal let byNBucket: [String: BucketStats]      // "small", "medium", "large"
    internal let byDomain: [String: BucketStats]       // "food", "entertainment", etc.
    internal let byDecoder: [String: BucketStats]      // "greedy", "topk50-t08", etc.

    /// Overall metrics
    internal let overallStats: OverallStats

    /// Best and worst runs
    internal let bestRun: SingleTestResult?
    internal let worstRun: SingleTestResult?

    /// Statistics for a bucket
    internal struct BucketStats: Codable, Sendable {
        internal let count: Int
        internal let passAtNRate: Double
        internal let meanUniqueItems: Double
        internal let meanDupRate: Double
        internal let stdevDupRate: Double
        internal let meanTimePerUnique: Double
        internal let jsonStrictRate: Double
    }

    /// Overall statistics
    internal struct OverallStats: Codable, Sendable {
        internal let passAtNRate: Double
        internal let meanUniqueItems: Double
        internal let stdevUniqueItems: Double
        internal let meanDupRate: Double
        internal let stdevDupRate: Double
        internal let meanTimePerUnique: Double
        internal let stdevTimePerUnique: Double
        internal let jsonStrictRate: Double
        internal let truncationRate: Double
        internal let insufficientRate: Double
        internal let formatErrorRate: Double
        internal let meanQualityScore: Double
        internal let seedVariance: Double  // Variance in results across different seeds
    }
}

// MARK: - Test Report

/// Comprehensive test report for a full test suite
internal struct TestReport: Codable, Identifiable, Sendable {
    internal let id: UUID
    internal let timestamp: Date

    /// Suite information
    internal let suiteId: String
    internal let suiteName: String
    internal let suiteDescription: String

    /// Execution summary
    internal let totalRuns: Int
    internal let successfulRuns: Int
    internal let failedRuns: Int
    internal let totalDuration: TimeInterval

    /// Environment info
    internal let environment: EnvironmentInfo

    /// Results by prompt
    internal let aggregateResults: [AggregateTestResult]

    /// All individual results
    internal let allResults: [SingleTestResult]

    /// Rankings
    internal let rankings: Rankings

    /// Environment information
    internal struct EnvironmentInfo: Codable, Sendable {
        internal let osVersion: String
        internal let osVersionString: String
        internal let hasTopP: Bool
        internal let device: String?
        internal let buildDate: String?
    }

    /// Rankings of prompts by various metrics
    internal struct Rankings: Codable, Sendable {
        internal let byPassRate: [RankedPrompt]
        internal let byQuality: [RankedPrompt]
        internal let bySpeed: [RankedPrompt]
        internal let byConsistency: [RankedPrompt]

        internal struct RankedPrompt: Codable, Sendable {
            internal let rank: Int
            internal let promptId: String
            internal let promptName: String
            internal let score: Double
            internal let metric: String
        }
    }

    /// Generate summary text
    internal func summaryText() -> String {
        internal let passRate = Double(successfulRuns) / Double(max(1, totalRuns)) * 100
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
