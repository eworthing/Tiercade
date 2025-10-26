import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Feature Flags

/// Feature flags for unique list generation (POC)
enum UniqueListGenerationFlags {
    /// EXPERIMENTAL: Enable the Generate → Dedup → Fill architecture for list requests
    /// When false, falls back to simple client-side deduplication
    ///
    /// Control via build script:
    /// - Default: enabled in DEBUG builds only
    /// - Override: ./build_install_launch.sh tvos --enable-advanced-generation
    /// - Override: ./build_install_launch.sh tvos --disable-advanced-generation
    nonisolated(unsafe) static var enableAdvancedGeneration: Bool = {
        #if FORCE_ENABLE_ADVANCED_GENERATION
        return true
        #elseif FORCE_DISABLE_ADVANCED_GENERATION
        return false
        #elseif DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Enable plural trimming in normalization (e.g., "Heroes" → "Hero")
    nonisolated(unsafe) static var pluralTrimEnabled = true

    /// Enable detailed logging for generation passes
    nonisolated(unsafe) static var verboseLogging = false
}

// MARK: - Configuration Defaults

enum Defaults {
    nonisolated(unsafe) static let maxPasses = 3
    nonisolated(unsafe) static let pass1OverGen = 1.6      // M = ceil(1.6 * N)
    nonisolated(unsafe) static let minBackfillFrac = 0.4    // backfill delta floor
    nonisolated(unsafe) static let tempDiverse = 0.8
    nonisolated(unsafe) static let tempControlled = 0.7
    nonisolated(unsafe) static let conservativeContextBudget = 3500
}

// MARK: - Normalization Configuration

struct NormConfig {
    static let pluralExceptions: Set<String> = [
        // Words ending in "ss"
        "bass", "glass", "chess", "success", "process", "class", "mass", "news",
        "dress", "stress", "mess", "loss", "boss", "cross", "pass", "grass",
        "brass", "compass", "genius", "princess", "duchess", "business",
        // Words ending in "es" that don't pluralize simply
        "analysis", "basis", "crisis", "hypothesis", "diagnosis", "thesis",
        // Irregular plurals
        "person", "child", "man", "woman", "foot", "tooth", "mouse", "goose"
    ]

    // Precompiled regex patterns
    static let reMarks: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: "[™®©]")
        } catch {
            fatalError("Invalid regex pattern for trademark symbols: \(error)")
        }
    }()
    static let reBrackets: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"\s*[\(\[][^\)\]]*[\)\]]"#)
        } catch {
            fatalError("Invalid regex pattern for brackets: \(error)")
        }
    }()
    static let reLeadArticles: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"^(the|a|an)\s+"#, options: [.caseInsensitive])
        } catch {
            fatalError("Invalid regex pattern for leading articles: \(error)")
        }
    }()
    static let rePunct: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"[[:punct:]]+"#)
        } catch {
            fatalError("Invalid regex pattern for punctuation: \(error)")
        }
    }()
    static let reWs: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"\s+"#)
        } catch {
            fatalError("Invalid regex pattern for whitespace: \(error)")
        }
    }()
}

// MARK: - String Normalization Extension

extension String {
    /// Recursively trim leading articles with delimiter awareness
    private func trimLeadingArticlesRecursive() -> String {
        let articles = Set(["a", "an", "the"])

        func stripArticles(_ text: String) -> String {
            var result = text.trimmingCharacters(in: .whitespaces)
            while let firstWord = result.split(separator: " ").first,
                  articles.contains(firstWord.lowercased()) {
                result.removeFirst(firstWord.count)
                result = result.trimmingCharacters(in: .whitespaces)
            }
            return result
        }

        // Split on delimiters that start new segments (colon, hyphen)
        let withSpacedHyphens = self.replacingOccurrences(of: "-", with: " ")
        let segments = withSpacedHyphens.split(separator: ":").map { stripArticles(String($0)) }
        return segments.joined(separator: ":")
    }

    /// Compute deterministic normalization key for deduplication
    var normKey: String {
        var s = lowercased().folding(options: .diacriticInsensitive, locale: .current)

        // Remove trademark symbols
        s = NormConfig.reMarks.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: ""
        )

        // Map & to and
        s = s.replacingOccurrences(of: "&", with: " and ")

        // Remove bracketed content
        s = NormConfig.reBrackets.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: ""
        )

        // Recursive article removal with delimiter awareness
        s = s.trimLeadingArticlesRecursive()

        // Strip punctuation
        s = NormConfig.rePunct.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " "
        )

        // Collapse whitespace
        s = NormConfig.reWs.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " "
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Optional plural trimming
        guard UniqueListGenerationFlags.pluralTrimEnabled else { return s }
        var parts = s.split(separator: " ").map(String.init)
        if var last = parts.last, last.count > 4 {
            if !NormConfig.pluralExceptions.contains(last) {
                if last.hasSuffix("es") {
                    last.removeLast(2)
                } else if last.hasSuffix("s") {
                    last.removeLast()
                }
                parts[parts.count - 1] = last
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Array Token Budgeting Extension

extension Array where Element == String {
    /// Chunk array by token budget for avoid-list management
    func chunkedByTokenBudget(
        maxTokens: Int,
        estimate: (String) -> Int = { ($0.count + 3) / 4 }
    ) -> [[String]] {
        var chunks: [[String]] = []
        var current: [String] = []
        var tally = 0

        for k in self {
            let t = estimate(k) + 2 // quotes + comma
            if tally + t > maxTokens, !current.isEmpty {
                chunks.append(current)
                current = [k]
                tally = t
            } else {
                current.append(k)
                tally += t
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}

// MARK: - GenerationOptions Extensions

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
extension GenerationOptions {
    /// Top-K sampling configuration
    nonisolated(unsafe) static func topK(_ k: Int, temp: Double, seed: UInt64?, maxTok: Int) -> Self {
        .init(
            sampling: .random(top: k, seed: seed),
            temperature: temp,
            maximumResponseTokens: maxTok
        )
    }

    /// Top-P sampling configuration (requires iOS 26+/macOS 26+)
    nonisolated(unsafe) static func topP(_ p: Double, temp: Double, seed: UInt64?, maxTok: Int) -> Self {
        .init(
            sampling: .random(probabilityThreshold: p, seed: seed),
            temperature: temp,
            maximumResponseTokens: maxTok
        )
    }

    /// Greedy deterministic sampling
    nonisolated(unsafe) static var greedy: Self {
        .init(
            sampling: .greedy,
            temperature: 0,
            maximumResponseTokens: 256
        )
    }

    /// Diverse sampling (uses top-p on supported platforms, falls back to top-k)
    nonisolated(unsafe) static func diverse(seed: UInt64?, maxTok: Int) -> Self {
        if #available(iOS 26.0, macOS 26.0, *) {
            return topP(0.92, temp: Defaults.tempDiverse, seed: seed, maxTok: maxTok)
        } else {
            return topK(50, temp: Defaults.tempDiverse, seed: seed, maxTok: maxTok)
        }
    }

    /// Controlled sampling (top-k with lower temperature)
    nonisolated(unsafe) static func controlled(seed: UInt64?, maxTok: Int) -> Self {
        topK(40, temp: Defaults.tempControlled, seed: seed, maxTok: maxTok)
    }
}
#endif

// MARK: - Guided Schema

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct UniqueListResponse: Decodable {
    var items: [String]
}
#endif

// MARK: - Telemetry Structures

struct RunEnv: Codable {
    let osVersionString: String
    let osVersion: String
    let hasTopP: Bool
    let deploymentTag: String?

    init(deploymentTag: String? = nil) {
        self.osVersionString = ProcessInfo.processInfo.operatingSystemVersionString

        let v = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"

        if #available(iOS 26.0, macOS 26.0, *) {
            self.hasTopP = true
        } else {
            self.hasTopP = false
        }

        self.deploymentTag = deploymentTag
    }
}

struct RunMetrics: Codable {
    let passAtN: Bool
    let uniqueAtN: Int
    let jsonStrictSuccess: Bool
    let itemsPerSecond: Double
    let dupRatePreDedup: Double
    let seed: UInt64?
    let decoderProfile: String
    let env: RunEnv
    let generationTimeSeconds: Double
    let totalPasses: Int
}

// MARK: - Decoder Profile

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
/// Profile that preserves sampling strategy across retries
enum DecoderProfile {
    case greedy
    case topK(Int)
    case topP(Double)

    func options(seed: UInt64?, temp: Double?, maxTok: Int?) -> GenerationOptions {
        switch self {
        case .greedy:
            return GenerationOptions(sampling: .greedy, temperature: temp, maximumResponseTokens: maxTok)
        case .topK(let k):
            return GenerationOptions(
                sampling: .random(top: k, seed: seed),
                temperature: temp,
                maximumResponseTokens: maxTok
            )
        case .topP(let p):
            return GenerationOptions(
                sampling: .random(probabilityThreshold: p, seed: seed),
                temperature: temp,
                maximumResponseTokens: maxTok
            )
        }
    }

    var description: String {
        switch self {
        case .greedy: return "greedy"
        case .topK(let k): return "topK:\(k)"
        case .topP(let p): return "topP:\(p)"
        }
    }
}
#endif

/// Per-attempt telemetry for diagnostics
struct AttemptMetrics: Codable {
    let attemptIndex: Int
    let seed: UInt64?
    let sampling: String
    let temperature: Double?
    let sessionRecreated: Bool
    let itemsReturned: Int?
    let elapsedSec: Double?
}

/// Full run telemetry for export
struct RunTelemetry: Codable {
    let testId: String
    let query: String
    let targetN: Int
    let passIndex: Int
    let attemptIndex: Int
    let seed: UInt64?
    let sampling: String
    let temperature: Double?
    let sessionRecreated: Bool
    let itemsReturned: Int
    let elapsedSec: Double
    let osVersion: String

    // Diagnostic fields (all optional for backward compatibility)
    let totalGenerated: Int?
    let dupCount: Int?
    let dupRate: Double?
    let backfillRounds: Int?
    let circuitBreakerTriggered: Bool?
    let passCount: Int?
    let failureReason: String?
    let topDuplicates: [String: Int]?  // Top 5 duplicate items with counts
}

/// Export telemetry to JSONL
@MainActor
func exportTelemetryToJSONL(_ records: [RunTelemetry], to path: String? = nil) {
    guard !records.isEmpty else { return }

    // Use NSTemporaryDirectory() for portability
    let defaultPath = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("unique_list_runs.jsonl").path
    let targetPath = path ?? defaultPath

    let encoder = JSONEncoder()
    encoder.outputFormatting = []  // Compact JSON for JSONL

    do {
        let fileURL = URL(fileURLWithPath: targetPath)

        // CAP: Rotate file at 10MB to prevent unbounded growth
        if FileManager.default.fileExists(atPath: targetPath) {
            let attrs = try FileManager.default.attributesOfItem(atPath: targetPath)
            if let size = (attrs[.size] as? NSNumber)?.intValue, size > 10_000_000 {
                let backupPath = targetPath.replacingOccurrences(
                    of: ".jsonl",
                    with: "_\(Date().timeIntervalSince1970).jsonl"
                )
                try? FileManager.default.moveItem(atPath: targetPath, toPath: backupPath)
                print("📊 Rotated telemetry log (>10MB) to: \(backupPath)")
            }
        }

        let fileHandle: FileHandle

        // Create or append to file
        if FileManager.default.fileExists(atPath: targetPath) {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
        } else {
            FileManager.default.createFile(atPath: targetPath, contents: nil)
            fileHandle = try FileHandle(forWritingTo: fileURL)
        }

        defer { try? fileHandle.close() }

        for record in records {
            let data = try encoder.encode(record)
            fileHandle.write(data)
            fileHandle.write(Data("\n".utf8))
        }
    } catch {
        print("⚠️ Failed to export telemetry: \(error)")
    }
}

// MARK: - FM Client Wrapper

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class FMClient {
    var session: LanguageModelSession
    let logger: (String) -> Void
    let sessionFactory: (() async throws -> LanguageModelSession)?

    // Deterministic seed ring for reproducible retries
    static let seedRing: [UInt64] = [42, 1337, 9999, 123456, 987654]

    init(
        session: LanguageModelSession,
        logger: @escaping (String) -> Void,
        sessionFactory: (() async throws -> LanguageModelSession)? = nil
    ) {
        self.session = session
        self.logger = logger
        self.sessionFactory = sessionFactory
    }

    struct GenerateParameters {
        let prompt: String
        let profile: DecoderProfile
        let initialSeed: UInt64?
        let temperature: Double?
        let maxTokens: Int?
        let maxRetries: Int
    }

    /// Generate using guided schema with automatic retry on seed-dependent failures
    func generate(
        _ params: GenerateParameters,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        let start = Date()
        var retryState = initializeRetryState(params: params)

        logGenerationStart(params: params)

        for attempt in 0..<params.maxRetries {
            let attemptStart = Date()
            var sessionRecreated = false

            logAttemptDetails(attempt: attempt, maxRetries: params.maxRetries, options: retryState.options)

            do {
                let response = try await executeGuidedGeneration(
                    prompt: params.prompt,
                    options: retryState.options
                )

                handleSuccessResponse(
                    context: ResponseContext(
                        response: response,
                        attempt: attempt,
                        attemptStart: attemptStart,
                        totalStart: start,
                        currentSeed: retryState.seed,
                        sessionRecreated: sessionRecreated,
                        params: params
                    ),
                    telemetry: &telemetry
                )

                return response.content.items

            } catch let e as LanguageModelSession.GenerationError {
                retryState.lastError = e

                if try await handleAttemptFailure(
                    error: e,
                    attempt: attempt,
                    attemptStart: attemptStart,
                    params: params,
                    currentOptions: &retryState.options,
                    currentSeed: &retryState.seed,
                    sessionRecreated: &sessionRecreated,
                    telemetry: &telemetry
                ) {
                    continue
                } else {
                    break
                }

            } catch {
                try handleUnexpectedError(error)
            }
        }

        throw buildRetryExhaustedError(lastError: retryState.lastError)
    }

    struct RetryState {
        var options: GenerationOptions
        var seed: UInt64?
        var lastError: Error?
        var sessionRecreated: Bool = false
    }

    public struct AttemptContext: Sendable {
        let attempt: Int
        let seed: UInt64?
        let profile: DecoderProfile
        let options: GenerationOptions
        let sessionRecreated: Bool
        let elapsed: Double
    }

    public struct ResponseContext: Sendable {
        let response: LanguageModelSession.Response<UniqueListResponse>
        let attempt: Int
        let attemptStart: Date
        let totalStart: Date
        let currentSeed: UInt64?
        let sessionRecreated: Bool
        let params: GenerateParameters
    }

    public struct UnguidedAttemptContext: Sendable {
        let attempt: Int
        let params: GenerateTextArrayParameters
        let options: GenerationOptions
        let sessionRecreated: Bool
        let elapsed: Double
    }

    struct GenerateTextArrayParameters {
        let prompt: String
        let profile: DecoderProfile
        let initialSeed: UInt64?
        let temperature: Double?
        let maxTokens: Int?
        let maxRetries: Int
    }

    /// Unguided generation that returns [String] by parsing JSON text array.
    /// Used for backfill where semantic constraints (avoid-list) must be respected.
    func generateTextArray(
        _ params: GenerateTextArrayParameters,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        let start = Date()
        var currentOptions = params.profile.options(
            seed: params.initialSeed,
            temp: params.temperature,
            maxTok: params.maxTokens
        )
        var lastError: Error?

        for attempt in 0..<params.maxRetries {
            let attemptStart = Date()
            var sessionRecreated = false

            do {
                let response = try await session.respond(
                    to: Prompt(params.prompt),
                    options: currentOptions
                )

                if let arr = try handleUnguidedResponse(
                    response: response,
                    attempt: attempt,
                    attemptStart: attemptStart,
                    totalStart: start,
                    params: params,
                    options: currentOptions,
                    sessionRecreated: sessionRecreated,
                    telemetry: &telemetry
                ) {
                    return arr
                }

            } catch {
                lastError = error

                if await handleUnguidedError(
                    error: error,
                    attempt: attempt,
                    attemptStart: attemptStart,
                    params: params,
                    options: currentOptions,
                    currentOptions: &currentOptions,
                    sessionRecreated: &sessionRecreated,
                    telemetry: &telemetry
                ) {
                    continue
                }
            }
        }

        throw lastError ?? NSError(domain: "Unguided", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "All unguided retries failed"
        ])
    }
}
#endif

// MARK: - Token Chunking Helper

private func chunkByTokens(_ keys: [String], budget: Int = 800) -> [[String]] {
    var chunks: [[String]] = []
    var cur: [String] = []
    var used = 2  // Account for [ ]

    for k in keys {
        let t = (k.count + 3) / 4 + 3  // Rough: text + quotes/comma
        if used + t > budget, !cur.isEmpty {
            chunks.append(cur)
            cur = []
            used = 2
        }
        cur.append(k)
        used += t
    }

    if !cur.isEmpty {
        chunks.append(cur)
    }

    return chunks
}

// MARK: - Unique List Coordinator

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class UniqueListCoordinator {
    let fm: FMClient
    let logger: (String) -> Void
    var telemetry: [AttemptMetrics] = []
    let useGuidedBackfill: Bool

    // Run diagnostics (populated by uniqueList())
    var lastRunTotalGenerated: Int?
    var lastRunDupCount: Int?
    var lastRunDupRate: Double?
    var lastRunBackfillRounds: Int?
    var lastRunCircuitBreakerTriggered: Bool?
    var lastRunPassCount: Int?
    var lastRunFailureReason: String?
    var lastRunTopDuplicates: [String: Int]?

    init(fm: FMClient, logger: @escaping (String) -> Void = { print($0) }, useGuidedBackfill: Bool = false) {
        self.fm = fm
        self.logger = logger
        self.useGuidedBackfill = useGuidedBackfill
    }

    /// Generate N unique items using Generate → Dedup → Fill architecture
    func uniqueList(query: String, targetCount: Int, seed: UInt64? = nil) async throws -> [String] {
        let startTime = Date()
        var state = GenerationState(targetCount: targetCount)

        try await executePass1(query: query, targetCount: targetCount, seed: seed, state: &state)

        if state.ordered.count >= targetCount {
            finalizeSuccess(state: state, startTime: startTime)
            return Array(state.ordered.prefix(targetCount))
        }

        try await executeBackfill(query: query, targetCount: targetCount, state: &state)

        finalizeGeneration(state: state, targetCount: targetCount, startTime: startTime)

        return Array(state.ordered.prefix(targetCount))
    }

    struct GenerationState {
        var ordered: [String] = []
        var seen = Set<String>()
        var totalGeneratedCount = 0
        var duplicatesFound = 0
        var passCount = 0
        var localTelemetry: [AttemptMetrics] = []
        var dupFrequency: [String: Int] = [:]
        var backfillRoundsTotal = 0
        var circuitBreakerTriggered = false
        let targetCount: Int

        mutating func absorb(
            _ items: [String],
            logger: (String) -> Void
        ) {
            totalGeneratedCount += items.count
            for s in items {
                let k = s.normKey
                if seen.insert(k).inserted {
                    ordered.append(s)
                } else {
                    duplicatesFound += 1
                    dupFrequency[k, default: 0] += 1
                    logger("  [Dedup] Filtered: \(s) → \(k)")
                }
                if ordered.count >= targetCount { return }
            }
        }
    }
}
#endif

// MARK: - Diagnostic Helpers

func looksLikeJSON5(_ s: String) -> Bool {
    s.range(of: #"//|/\*|\*/"#, options: .regularExpression) != nil ||
        s.range(of: #",\s*[}\]]"#, options: .regularExpression) != nil
}
