import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Models & Configuration

@available(iOS 26.0, macOS 26.0, *)
internal extension EnhancedPromptTester {
// MARK: - Configuration

internal enum SamplingMode {
    internal case greedy
    internal case topP(Double)
    internal case topK(Int)
}

internal struct DecodingConfig {
    internal let name: String
    internal let sampling: SamplingMode
    internal let temperature: Double

    internal func generationOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
        switch sampling {
        case .greedy:
            return GenerationOptions(
                sampling: .greedy,
                temperature: 0.0,
                maximumResponseTokens: maxTokens
            )
        case .topP(let threshold):
            return GenerationOptions(
                sampling: .random(probabilityThreshold: threshold, seed: seed),
                temperature: temperature,
                maximumResponseTokens: maxTokens
            )
        case .topK(let k):
            return GenerationOptions(
                sampling: .random(top: k, seed: seed),
                temperature: temperature,
                maximumResponseTokens: maxTokens
            )
        }
    }
}

internal struct TestQuery {
    internal let query: String
    internal let target: Int?
    internal let domain: String
}

internal struct TestConfig {
    // PILOT CONFIGURATION: Reduced grid for speed validation
    internal let seeds: [UInt64] = [42, 1337]  // 2 seeds

    internal let testQueries: [TestQuery] = [
        TestQuery(query: "top 15 most popular fruits", target: 15, domain: "food"),  // Small
        TestQuery(query: "best places to live in the United States", target: 50, domain: "geography"),  // Medium
        TestQuery(query: "best video games released in 2020-2023", target: 150, domain: "media"),  // Large
        // Open (treat as 40)
        TestQuery(query: "What are the most popular candy bars?", target: nil, domain: "food")
    ]

    internal let decodingConfigs: [DecodingConfig] = [
        // PILOT: 3 decoders
        DecodingConfig(name: "Greedy", sampling: .greedy, temperature: 0.0),
        DecodingConfig(name: "TopK50-T0.8", sampling: .topK(50), temperature: 0.8),
        DecodingConfig(name: "TopP92-T0.8", sampling: .topP(0.92), temperature: 0.8)
    ]

    internal let guidedModes: [Bool] = [false, true]

    // PILOT: Test 4 prompts only (G0, G2, G3, G6)
    // Full grid: 4 prompts × 4 queries × 3 decoders × 2 seeds × 2 guided = 192 runs (~15 min)

    // Dynamic token budget
    internal func dynamicMaxTokens(targetCount: Int, overgenFactor: Double) -> Int {
        internal let tokensPerItem = 6
        internal let calculated = Int(ceil(Double(targetCount) * overgenFactor * Double(tokensPerItem) * 1.3))
        return min(3000, calculated)
    }

    internal func overgenFactor(for targetCount: Int) -> Double {
        if targetCount <= 50 { return 1.4 }
        if targetCount <= 150 { return 1.6 }
        return 2.0
    }

    internal func nBucket(for targetCount: Int?) -> String {
        guard let n = targetCount else { return "open" }
        if n <= 25 { return "small" }
        if n <= 50 { return "medium" }
        return "large"
    }
}
// MARK: - Results

internal struct SingleRunResult: Sendable {
    internal let promptNumber: Int
    internal let promptName: String
    internal let runNumber: Int
    internal let seed: UInt64
    internal let query: String
    internal let targetCount: Int?
    internal let domain: String
    internal let nBucket: String
    internal let decodingName: String
    internal let guidedSchema: Bool
    internal let response: String
    internal let parsedItems: [String]
    internal let normalizedItems: [String]
    internal let totalItems: Int
    internal let uniqueItems: Int
    internal let duplicateCount: Int
    internal let dupRate: Double
    internal let passAtN: Bool
    internal let surplusAtN: Int  // max(0, unique - N)
    internal let jsonStrict: Bool  // Parsed as JSON array (not fallback)
    internal let insufficient: Bool
    internal let formatError: Bool
    internal let wasJsonParsed: Bool
    internal let finishReason: String?
    internal let wasTruncated: Bool
    internal let maxTokensUsed: Int
    internal let duration: TimeInterval
    internal let timePerUnique: Double  // duration / max(1, unique)
}

internal struct AggregateResult {
    internal let promptNumber: Int
    internal let promptName: String
    internal let promptText: String
    internal let totalRuns: Int
    internal let nBucket: String
    internal let domain: String

    // SORTED BY PRIORITY
    internal let passAtNRate: Double
    internal let meanUniqueItems: Double
    internal let jsonStrictRate: Double
    internal let meanTimePerUnique: Double
    internal let meanDupRate: Double
    internal let stdevDupRate: Double
    internal let meanSurplusAtN: Double
    internal let truncationRate: Double
    internal let seedVariance: Double  // stdev of unique@N across seeds
    internal let insufficientRate: Double
    internal let formatErrorRate: Double

    internal let bestRun: SingleRunResult?
    internal let worstRun: SingleRunResult?
    internal let allRuns: [SingleRunResult]
}

// MARK: - Guided Schema

@Generable
internal struct StringList: Codable {
    internal let items: [String]
}
}
#endif
