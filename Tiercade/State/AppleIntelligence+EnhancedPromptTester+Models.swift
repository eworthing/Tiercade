import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Models & Configuration

@available(iOS 26.0, macOS 26.0, *)
extension EnhancedPromptTester {
// MARK: - Configuration

enum SamplingMode {
    case greedy
    case topP(Double)
    case topK(Int)
}

struct DecodingConfig {
    let name: String
    let sampling: SamplingMode
    let temperature: Double

    func generationOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
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

struct TestQuery {
    let query: String
    let target: Int?
    let domain: String
}

struct TestConfig {
    // PILOT CONFIGURATION: Reduced grid for speed validation
    let seeds: [UInt64] = [42, 1337]  // 2 seeds

    let testQueries: [TestQuery] = [
        TestQuery(query: "top 15 most popular fruits", target: 15, domain: "food"),  // Small
        TestQuery(query: "best places to live in the United States", target: 50, domain: "geography"),  // Medium
        TestQuery(query: "best video games released in 2020-2023", target: 150, domain: "media"),  // Large
        // Open (treat as 40)
        TestQuery(query: "What are the most popular candy bars?", target: nil, domain: "food")
    ]

    let decodingConfigs: [DecodingConfig] = [
        // PILOT: 3 decoders
        DecodingConfig(name: "Greedy", sampling: .greedy, temperature: 0.0),
        DecodingConfig(name: "TopK50-T0.8", sampling: .topK(50), temperature: 0.8),
        DecodingConfig(name: "TopP92-T0.8", sampling: .topP(0.92), temperature: 0.8)
    ]

    let guidedModes: [Bool] = [false, true]

    // PILOT: Test 4 prompts only (G0, G2, G3, G6)
    // Full grid: 4 prompts × 4 queries × 3 decoders × 2 seeds × 2 guided = 192 runs (~15 min)

    // Dynamic token budget
    func dynamicMaxTokens(targetCount: Int, overgenFactor: Double) -> Int {
        let tokensPerItem = 6
        let calculated = Int(ceil(Double(targetCount) * overgenFactor * Double(tokensPerItem) * 1.3))
        return min(3000, calculated)
    }

    func overgenFactor(for targetCount: Int) -> Double {
        if targetCount <= 50 { return 1.4 }
        if targetCount <= 150 { return 1.6 }
        return 2.0
    }

    func nBucket(for targetCount: Int?) -> String {
        guard let n = targetCount else { return "open" }
        if n <= 25 { return "small" }
        if n <= 50 { return "medium" }
        return "large"
    }
}
// MARK: - Results

struct SingleRunResult: Sendable {
    let promptNumber: Int
    let promptName: String
    let runNumber: Int
    let seed: UInt64
    let query: String
    let targetCount: Int?
    let domain: String
    let nBucket: String
    let decodingName: String
    let guidedSchema: Bool
    let response: String
    let parsedItems: [String]
    let normalizedItems: [String]
    let totalItems: Int
    let uniqueItems: Int
    let duplicateCount: Int
    let dupRate: Double
    let passAtN: Bool
    let surplusAtN: Int  // max(0, unique - N)
    let jsonStrict: Bool  // Parsed as JSON array (not fallback)
    let insufficient: Bool
    let formatError: Bool
    let wasJsonParsed: Bool
    let finishReason: String?
    let wasTruncated: Bool
    let maxTokensUsed: Int
    let duration: TimeInterval
    let timePerUnique: Double  // duration / max(1, unique)
}

struct AggregateResult {
    let promptNumber: Int
    let promptName: String
    let promptText: String
    let totalRuns: Int
    let nBucket: String
    let domain: String

    // SORTED BY PRIORITY
    let passAtNRate: Double
    let meanUniqueItems: Double
    let jsonStrictRate: Double
    let meanTimePerUnique: Double
    let meanDupRate: Double
    let stdevDupRate: Double
    let meanSurplusAtN: Double
    let truncationRate: Double
    let seedVariance: Double  // stdev of unique@N across seeds
    let insufficientRate: Double
    let formatErrorRate: Double

    let bestRun: SingleRunResult?
    let worstRun: SingleRunResult?
    let allRuns: [SingleRunResult]
}

// MARK: - Guided Schema

@Generable
struct StringList: Codable {
    let items: [String]
}
}
#endif
