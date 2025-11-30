import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Configuration Models (JSON → Swift)

// swiftlint:disable nesting - Nested types namespace related Codable models for JSON decoding

#if DEBUG && canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension UnifiedPromptTester {

    // MARK: - System Prompt Configuration

    /// Configuration for a system prompt loaded from SystemPrompts.json
    struct SystemPromptConfig: Codable, Identifiable, Sendable {
        /// Unique identifier (e.g., "G0-Minimal", "S01-UltraSimple")
        let id: String

        /// Human-readable name
        let name: String

        /// Category for grouping (e.g., "basic", "backfill", "advanced")
        let category: String

        /// Brief description of the prompt's purpose
        let description: String

        /// The actual prompt text (may contain {QUERY}, {DELTA}, {AVOID_LIST} placeholders)
        let text: String

        /// Optional metadata
        let metadata: PromptMetadata?

        /// Metadata associated with a system prompt
        struct PromptMetadata: Codable, Sendable {
            let expectedDupRate: String?
            let recommendedFor: [String]?
            let requiresVariables: [String]?
            let dateAdded: String?
            let notes: String?
            let author: String?
            let tags: [String]?
            let source: String?
        }
    }

    /// Container for SystemPrompts.json
    struct SystemPromptsLibrary: Codable, Sendable {
        let version: String
        let prompts: [SystemPromptConfig]
        let metadata: LibraryMetadata?

        struct LibraryMetadata: Codable, Sendable {
            let description: String?
            let lastUpdated: String?
            let totalPrompts: Int?
        }
    }

    // MARK: - Test Query Configuration

    /// Configuration for a test query loaded from TestQueries.json
    struct TestQueryConfig: Codable, Identifiable, Sendable {
        /// Unique identifier (e.g., "animated-series-25")
        let id: String

        /// The actual query text to send to the model
        let query: String

        /// Target count (null for open-ended queries, treated as 40)
        let targetCount: Int?

        /// Domain category (e.g., "entertainment", "food")
        let domain: String

        /// Difficulty level: "easy", "medium", "hard"
        let difficulty: String

        /// Optional metadata
        let metadata: QueryMetadata?

        /// Metadata associated with a test query
        struct QueryMetadata: Codable, Sendable {
            let expectedUniqueness: Double?
            let notes: String?
            let dateAdded: String?
            let knownIssues: [String]?
            let relatedQueries: [String]?
            let tags: [String]?
            let source: String?
        }
    }

    /// Container for TestQueries.json
    struct TestQueriesLibrary: Codable, Sendable {
        let version: String
        let queries: [TestQueryConfig]
        let metadata: LibraryMetadata?

        struct LibraryMetadata: Codable, Sendable {
            let description: String?
            let lastUpdated: String?
            let totalQueries: Int?
        }
    }

    // MARK: - Decoding Configuration

    /// Configuration for decoding/sampling settings loaded from DecodingConfigs.json
    struct DecodingConfigDef: Codable, Identifiable, Sendable {
        /// Sampling configuration
        struct SamplingConfig: Codable, Sendable {
            /// Sampling mode: "greedy", "topK", "topP"
            let mode: String

            /// For topK: k value
            let k: Int?

            /// For topP: probability threshold
            let threshold: Double?
        }

        /// Metadata associated with a decoding config
        struct DecodingMetadata: Codable, Sendable {
            let description: String?
            let recommendedFor: [String]?
            let expectedDiversity: String?
            let requiresOS: String?
            let dateAdded: String?
            let tags: [String]?
        }

        /// Unique identifier (e.g., "greedy", "topk50-t08")
        let id: String

        /// Human-readable name
        let name: String

        /// Sampling configuration
        let sampling: SamplingConfig

        /// Temperature (0.0 to 2.0)
        let temperature: Double

        /// Optional metadata
        let metadata: DecodingMetadata?

        #if canImport(FoundationModels)
        /// Convert to GenerationOptions for use with FoundationModels
        func toGenerationOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
            switch sampling.mode {
            case "greedy":
                return GenerationOptions(
                    sampling: .greedy,
                    temperature: 0.0,
                    maximumResponseTokens: maxTokens,
                )
            case "topK":
                guard let k = sampling.k else {
                    fatalError("topK mode requires 'k' parameter")
                }
                return GenerationOptions(
                    sampling: .random(top: k, seed: seed),
                    temperature: temperature,
                    maximumResponseTokens: maxTokens,
                )
            case "topP":
                guard let threshold = sampling.threshold else {
                    fatalError("topP mode requires 'threshold' parameter")
                }
                return GenerationOptions(
                    sampling: .random(probabilityThreshold: threshold, seed: seed),
                    temperature: temperature,
                    maximumResponseTokens: maxTokens,
                )
            default:
                fatalError("Unknown sampling mode: \(sampling.mode)")
            }
        }
        #endif
    }

    /// Container for DecodingConfigs.json
    struct DecodingConfigsLibrary: Codable, Sendable {
        let version: String
        let configs: [DecodingConfigDef]
        let metadata: LibraryMetadata?

        struct LibraryMetadata: Codable, Sendable {
            let description: String?
            let lastUpdated: String?
            let totalConfigs: Int?
        }
    }

    // MARK: - Test Suite Configuration

    /// Configuration for a test suite loaded from TestSuites.json
    struct TestSuiteConfig: Codable, Identifiable, Sendable {
        /// Configuration for what to test
        struct SuiteTestConfig: Codable, Sendable {
            /// Prompt IDs to test (use ["*"] for all)
            let promptIds: [String]

            /// Query IDs to test (use ["*"] for all)
            let queryIds: [String]

            /// Decoder IDs to test (use ["*"] for all)
            let decoderIds: [String]

            /// Seeds to use for reproducibility
            let seeds: [UInt64]

            /// Whether to test with guided schema
            let guidedModes: [Bool]

            /// Optional: Override max tokens per run
            let maxTokensOverride: Int?

            /// Optional: Timeout per run (seconds)
            let timeoutSeconds: Int?
        }

        /// Metadata about the test suite
        struct SuiteMetadata: Codable, Sendable {
            let estimatedDuration: Int?
            let totalRuns: Int?
            let purpose: String?
            let runWhen: String?
            let dateAdded: String?
            let tags: [String]?
            let notes: String?
        }

        /// Unique identifier (e.g., "quick-smoke")
        let id: String

        /// Human-readable name
        let name: String

        /// Description of what this suite tests
        let description: String

        /// Test configuration
        let config: SuiteTestConfig

        /// Optional metadata
        let metadata: SuiteMetadata?

    }

    /// Container for TestSuites.json
    struct TestSuitesLibrary: Codable, Sendable {
        let version: String
        let suites: [TestSuiteConfig]
        let metadata: LibraryMetadata?

        struct LibraryMetadata: Codable, Sendable {
            let description: String?
            let lastUpdated: String?
            let totalSuites: Int?
        }
    }

}
// swiftlint:enable nesting
#endif
