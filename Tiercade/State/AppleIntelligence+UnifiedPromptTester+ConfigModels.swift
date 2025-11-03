import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Configuration Models (JSON → Swift)

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
internal extension UnifiedPromptTester {

// MARK: - System Prompt Configuration

/// Configuration for a system prompt loaded from SystemPrompts.json
internal struct SystemPromptConfig: Codable, Identifiable, Sendable {
    /// Unique identifier (e.g., "G0-Minimal", "S01-UltraSimple")
    internal let id: String

    /// Human-readable name
    internal let name: String

    /// Category for grouping (e.g., "basic", "backfill", "advanced")
    internal let category: String

    /// Brief description of the prompt's purpose
    internal let description: String

    /// The actual prompt text (may contain {QUERY}, {DELTA}, {AVOID_LIST} placeholders)
    internal let text: String

    /// Optional metadata
    internal let metadata: PromptMetadata?

    /// Metadata associated with a system prompt
    internal struct PromptMetadata: Codable, Sendable {
        internal let expectedDupRate: String?
        internal let recommendedFor: [String]?
        internal let requiresVariables: [String]?
        internal let dateAdded: String?
        internal let notes: String?
        internal let author: String?
        internal let tags: [String]?
        internal let source: String?
    }
}

/// Container for SystemPrompts.json
internal struct SystemPromptsLibrary: Codable, Sendable {
    internal let version: String
    internal let prompts: [SystemPromptConfig]
    internal let metadata: LibraryMetadata?

    internal struct LibraryMetadata: Codable, Sendable {
        internal let description: String?
        internal let lastUpdated: String?
        internal let totalPrompts: Int?
    }
}

// MARK: - Test Query Configuration

/// Configuration for a test query loaded from TestQueries.json
internal struct TestQueryConfig: Codable, Identifiable, Sendable {
    /// Unique identifier (e.g., "animated-series-25")
    internal let id: String

    /// The actual query text to send to the model
    internal let query: String

    /// Target count (null for open-ended queries, treated as 40)
    internal let targetCount: Int?

    /// Domain category (e.g., "entertainment", "food")
    internal let domain: String

    /// Difficulty level: "easy", "medium", "hard"
    internal let difficulty: String

    /// Optional metadata
    internal let metadata: QueryMetadata?

    /// Metadata associated with a test query
    internal struct QueryMetadata: Codable, Sendable {
        internal let expectedUniqueness: Double?
        internal let notes: String?
        internal let dateAdded: String?
        internal let knownIssues: [String]?
        internal let relatedQueries: [String]?
        internal let tags: [String]?
        internal let source: String?
    }
}

/// Container for TestQueries.json
internal struct TestQueriesLibrary: Codable, Sendable {
    internal let version: String
    internal let queries: [TestQueryConfig]
    internal let metadata: LibraryMetadata?

    internal struct LibraryMetadata: Codable, Sendable {
        internal let description: String?
        internal let lastUpdated: String?
        internal let totalQueries: Int?
    }
}

// MARK: - Decoding Configuration

/// Configuration for decoding/sampling settings loaded from DecodingConfigs.json
internal struct DecodingConfigDef: Codable, Identifiable, Sendable {
    /// Unique identifier (e.g., "greedy", "topk50-t08")
    internal let id: String

    /// Human-readable name
    internal let name: String

    /// Sampling configuration
    internal let sampling: SamplingConfig

    /// Temperature (0.0 to 2.0)
    internal let temperature: Double

    /// Optional metadata
    internal let metadata: DecodingMetadata?

    /// Sampling configuration
    internal struct SamplingConfig: Codable, Sendable {
        /// Sampling mode: "greedy", "topK", "topP"
        internal let mode: String

        /// For topK: k value
        internal let k: Int?

        /// For topP: probability threshold
        internal let threshold: Double?
    }

    /// Metadata associated with a decoding config
    internal struct DecodingMetadata: Codable, Sendable {
        internal let description: String?
        internal let recommendedFor: [String]?
        internal let expectedDiversity: String?
        internal let requiresOS: String?
        internal let dateAdded: String?
        internal let tags: [String]?
    }

    #if canImport(FoundationModels)
    /// Convert to GenerationOptions for use with FoundationModels
    internal func toGenerationOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
        switch sampling.mode {
        internal case "greedy":
            return GenerationOptions(
                sampling: .greedy,
                temperature: 0.0,
                maximumResponseTokens: maxTokens
            )
        internal case "topK":
            guard let k = sampling.k else {
                fatalError("topK mode requires 'k' parameter")
            }
            return GenerationOptions(
                sampling: .random(top: k, seed: seed),
                temperature: temperature,
                maximumResponseTokens: maxTokens
            )
        internal case "topP":
            guard let threshold = sampling.threshold else {
                fatalError("topP mode requires 'threshold' parameter")
            }
            return GenerationOptions(
                sampling: .random(probabilityThreshold: threshold, seed: seed),
                temperature: temperature,
                maximumResponseTokens: maxTokens
            )
        default:
            fatalError("Unknown sampling mode: \(sampling.mode)")
        }
    }
    #endif
}

/// Container for DecodingConfigs.json
internal struct DecodingConfigsLibrary: Codable, Sendable {
    internal let version: String
    internal let configs: [DecodingConfigDef]
    internal let metadata: LibraryMetadata?

    internal struct LibraryMetadata: Codable, Sendable {
        internal let description: String?
        internal let lastUpdated: String?
        internal let totalConfigs: Int?
    }
}

// MARK: - Test Suite Configuration

/// Configuration for a test suite loaded from TestSuites.json
internal struct TestSuiteConfig: Codable, Identifiable, Sendable {
    /// Unique identifier (e.g., "quick-smoke")
    internal let id: String

    /// Human-readable name
    internal let name: String

    /// Description of what this suite tests
    internal let description: String

    /// Test configuration
    internal let config: SuiteTestConfig

    /// Optional metadata
    internal let metadata: SuiteMetadata?

    /// Configuration for what to test
    internal struct SuiteTestConfig: Codable, Sendable {
        /// Prompt IDs to test (use ["*"] for all)
        internal let promptIds: [String]

        /// Query IDs to test (use ["*"] for all)
        internal let queryIds: [String]

        /// Decoder IDs to test (use ["*"] for all)
        internal let decoderIds: [String]

        /// Seeds to use for reproducibility
        internal let seeds: [UInt64]

        /// Whether to test with guided schema
        internal let guidedModes: [Bool]

        /// Optional: Override max tokens per run
        internal let maxTokensOverride: Int?

        /// Optional: Timeout per run (seconds)
        internal let timeoutSeconds: Int?
    }

    /// Metadata about the test suite
    internal struct SuiteMetadata: Codable, Sendable {
        internal let estimatedDuration: Int?
        internal let totalRuns: Int?
        internal let purpose: String?
        internal let runWhen: String?
        internal let dateAdded: String?
        internal let tags: [String]?
        internal let notes: String?
    }
}

/// Container for TestSuites.json
internal struct TestSuitesLibrary: Codable, Sendable {
    internal let version: String
    internal let suites: [TestSuiteConfig]
    internal let metadata: LibraryMetadata?

    internal struct LibraryMetadata: Codable, Sendable {
        internal let description: String?
        internal let lastUpdated: String?
        internal let totalSuites: Int?
    }
}

}
#endif
