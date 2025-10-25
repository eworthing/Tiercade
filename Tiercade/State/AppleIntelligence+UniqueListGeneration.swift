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
    static let reMarks = try! NSRegularExpression(pattern: "[™®©]")
    static let reBrackets = try! NSRegularExpression(
        pattern: #"\s*[\(\[][^\)\]]*[\)\]]"#
    )
    static let reLeadArticles = try! NSRegularExpression(
        pattern: #"^(the|a|an)\s+"#,
        options: [.caseInsensitive]
    )
    static let rePunct = try! NSRegularExpression(pattern: #"[[:punct:]]+"#)
    static let reWs = try! NSRegularExpression(pattern: #"\s+"#)
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
            return GenerationOptions(sampling: .random(top: k, seed: seed), temperature: temp, maximumResponseTokens: maxTok)
        case .topP(let p):
            return GenerationOptions(sampling: .random(probabilityThreshold: p, seed: seed), temperature: temp, maximumResponseTokens: maxTok)
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
            fileHandle.write("\n".data(using: .utf8)!)
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

    init(session: LanguageModelSession, logger: @escaping (String) -> Void, sessionFactory: (() async throws -> LanguageModelSession)? = nil) {
        self.session = session
        self.logger = logger
        self.sessionFactory = sessionFactory
    }

    /// Generate using guided schema with automatic retry on seed-dependent failures
    func generate(
        _ prompt: String,
        profile: DecoderProfile,
        initialSeed: UInt64?,
        temperature: Double?,
        maxTokens: Int?,
        maxRetries: Int = 5,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        let start = Date()
        var currentOptions = profile.options(seed: initialSeed, temp: temperature, maxTok: maxTokens)
        var currentSeed = initialSeed
        var lastError: Error?

        // Debug logging
        logger("🔍 [DEBUG] Starting generation (maxRetries=\(maxRetries))...")
        logger("🔍 [DEBUG] Prompt length: \(prompt.count) chars")
        logger("🔍 [DEBUG] Full prompt: \"\(prompt)\"")

        for attempt in 0..<maxRetries {
            let attemptStart = Date()
            var sessionRecreated = false

            logger("🔍 [DEBUG] Attempt \(attempt + 1)/\(maxRetries)")
            logger("🔍 [DEBUG] Options.maximumResponseTokens: \(String(describing: currentOptions.maximumResponseTokens))")
            logger("🔍 [DEBUG] Options.temperature: \(String(describing: currentOptions.temperature))")
            logger("🔍 [DEBUG] Options.sampling: \(String(describing: currentOptions.sampling))")
            logger("🔍 [DEBUG] Schema: UniqueListResponse (includeSchemaInPrompt=true)")

            do {
                let response = try await session.respond(
                    to: Prompt(prompt),
                    generating: UniqueListResponse.self,
                    includeSchemaInPrompt: true,
                    options: currentOptions
                )

                let attemptElapsed = Date().timeIntervalSince(attemptStart)
                let totalElapsed = Date().timeIntervalSince(start)
                let ips = Double(response.content.items.count) / max(0.001, totalElapsed)

                // CRITICAL: Log when we get 0 items to understand why
                if response.content.items.isEmpty {
                    logger("⚠️ [CRITICAL] Schema parsing succeeded but returned EMPTY ARRAY")
                    logger("⚠️ [CRITICAL] This means the model generated { \"items\": [] } - not a parsing error")
                    logger("⚠️ [CRITICAL] Prompt was: \"\(prompt.prefix(200))...\"")
                }

                // Record successful attempt telemetry
                telemetry.append(AttemptMetrics(
                    attemptIndex: attempt,
                    seed: currentSeed,
                    sampling: profile.description,
                    temperature: currentOptions.temperature,
                    sessionRecreated: sessionRecreated,
                    itemsReturned: response.content.items.count,
                    elapsedSec: attemptElapsed
                ))

                if attempt > 0 {
                    logger("✓ Generated \(response.content.items.count) items in \(String(format: "%.2f", totalElapsed))s (\(String(format: "%.1f", ips)) items/sec) [succeeded on attempt \(attempt + 1)]")
                } else {
                    logger("✓ Generated \(response.content.items.count) items in \(String(format: "%.2f", totalElapsed))s (\(String(format: "%.1f", ips)) items/sec)")
                }
                logger("🔍 [DEBUG] First item: \(response.content.items.first ?? "none")")
                logger("🔍 [DEBUG] Last item: \(response.content.items.last ?? "none")")
                logger("🔍 [DEBUG] Item count breakdown: total=\(response.content.items.count)")

                return response.content.items

            } catch let e as LanguageModelSession.GenerationError {
                lastError = e

                let attemptElapsed = Date().timeIntervalSince(attemptStart)

                // Record failed attempt telemetry
                telemetry.append(AttemptMetrics(
                    attemptIndex: attempt,
                    seed: currentSeed,
                    sampling: profile.description,
                    temperature: currentOptions.temperature,
                    sessionRecreated: sessionRecreated,
                    itemsReturned: nil,
                    elapsedSec: attemptElapsed
                ))

                if case .decodingFailure(let context) = e {
                    if attempt < maxRetries - 1 {
                        logger("⚠️ [Attempt \(attempt + 1)] decodingFailure: \(context.debugDescription)")

                        // ADAPTIVE RETRY: Boost tokens before seed rotation on first failure
                        if attempt == 0 {
                            let currentMax = currentOptions.maximumResponseTokens ?? 0
                            let boosted = min(512, Int(Double(currentMax) * 1.8))
                            if boosted > currentMax {
                                logger("🔁 Boosting maxTokens → \(boosted) with same seed/profile")
                                currentOptions = profile.options(
                                    seed: currentSeed,
                                    temp: currentOptions.temperature,
                                    maxTok: boosted
                                )
                                logger("🔁 Retrying with seed=\(currentSeed.map { String($0) } ?? "nil"), profile=\(profile.description)")
                                continue
                            }
                        }

                        // Session hygiene: create fresh session after first failure
                        if attempt == 1, let factory = sessionFactory {
                            do {
                                session = try await factory()
                                sessionRecreated = true
                                logger("♻️ Recreating session")
                            } catch {
                                logger("⚠️ Failed to create fresh session: \(error)")
                            }
                        }

                        // Use deterministic seed ring for reproducible retries
                        let newSeed = Self.seedRing[(attempt + 1) % Self.seedRing.count]
                        currentSeed = newSeed

                        // Lower temperature after 2 failures
                        let temp = attempt >= 2 ? 0.7 : temperature
                        currentOptions = profile.options(seed: currentSeed, temp: temp, maxTok: maxTokens)

                        logger("🔁 Retrying with seed=\(newSeed), profile=\(profile.description)")
                        continue
                    } else {
                        logger("❌ [Attempt \(attempt + 1)] decodingFailure: \(context.debugDescription)")
                        logger("❌ Max retries exhausted, failing")
                    }
                } else if case .exceededContextWindowSize(let details) = e {
                    logger("❌ Context window overflow: \(details)")
                    throw e  // Non-recoverable
                } else {
                    logger("❌ [DEBUG] GenerationError: \(e)")
                    throw e  // Non-recoverable
                }
            } catch {
                logger("❌ [DEBUG] Unexpected error type: \(type(of: error))")
                logger("❌ [DEBUG] Error: \(error)")
                throw error
            }
        }

        // If we get here, all retries failed
        if let error = lastError {
            throw error
        } else {
            throw NSError(domain: "FMClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retries failed"])
        }
    }

    /// Unguided generation that returns [String] by parsing JSON text array.
    /// Used for backfill where semantic constraints (avoid-list) must be respected.
    func generateTextArray(
        _ prompt: String,
        profile: DecoderProfile,
        initialSeed: UInt64?,
        temperature: Double?,
        maxTokens: Int?,
        maxRetries: Int = 3,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        let start = Date()
        var currentOptions = profile.options(seed: initialSeed, temp: temperature, maxTok: maxTokens)
        var lastError: Error?

        for attempt in 0..<maxRetries {
            let attemptStart = Date()
            var sessionRecreated = false

            do {
                let response = try await session.respond(
                    to: Prompt(prompt),
                    options: currentOptions
                )

                let attemptElapsed = Date().timeIntervalSince(attemptStart)

                // DEBUG: Log what we actually got
                let preview = String(response.content.prefix(200))
                logger("🔍 [DEBUG] Unguided response preview: \(preview)")

                // Write debug data to file
                let fileManager = FileManager.default
                let debugDir = fileManager.temporaryDirectory.appendingPathComponent("unguided_debug", isDirectory: true)
                do {
                    try fileManager.createDirectory(at: debugDir, withIntermediateDirectories: true)
                } catch {
                    logger("⚠️ Failed to prepare debug directory: \(error)")
                }

                let debugFile = debugDir.appendingPathComponent("unguided_\(Date().timeIntervalSince1970).json")
                let debugData: [String: Any] = [
                    "timestamp": Date().timeIntervalSince1970,
                    "attempt": attempt,
                    "seed": initialSeed ?? 0,
                    "temperature": currentOptions.temperature,
                    "maxTokens": currentOptions.maximumResponseTokens ?? 0,
                    "promptLength": prompt.count,
                    "responseLength": response.content.count,
                    "elapsedSec": attemptElapsed,
                    "promptSnippet": String(prompt.prefix(200)),
                    "fullResponse": response.content
                ]

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: debugData, options: .prettyPrinted)
                    try jsonData.write(to: debugFile, options: .atomic)
                    logger("📝 Debug data saved to: \(debugFile.path)")
                } catch {
                    logger("⚠️ Failed to save debug data: \(error)")
                }

                if let arr = parseJSONArray(response.content) {
                    let totalElapsed = Date().timeIntervalSince(start)
                    logger("✓ Parsed \(arr.count) items from text in \(String(format: "%.2f", totalElapsed))s")

                    // Save parse success info
                    let parseDebug: [String: Any] = [
                        "parseSuccess": true,
                        "itemsExtracted": arr.count,
                        "items": arr
                    ]
                    do {
                        let parseData = try JSONSerialization.data(withJSONObject: parseDebug, options: .prettyPrinted)
                        let parseFile = debugDir.appendingPathComponent("parse_\(Date().timeIntervalSince1970).json")
                        try parseData.write(to: parseFile, options: .atomic)
                    } catch {
                        logger("⚠️ Failed to save parse debug: \(error)")
                    }

                    // Record successful telemetry
                    telemetry.append(AttemptMetrics(
                        attemptIndex: attempt,
                        seed: initialSeed,
                        sampling: "unguided:\(profile.description)",
                        temperature: currentOptions.temperature,
                        sessionRecreated: sessionRecreated,
                        itemsReturned: arr.count,
                        elapsedSec: attemptElapsed
                    ))

                    return arr
                }

                // Parse failure - log the full response for debugging
                logger("⚠️ Parse failed. Full response (\(response.content.count) chars): \(response.content)")

                // Save parse failure info
                let parseFailDebug: [String: Any] = [
                    "parseSuccess": false,
                    "response": response.content,
                    "reason": "Could not extract JSON array"
                ]
                do {
                    let failData = try JSONSerialization.data(withJSONObject: parseFailDebug, options: .prettyPrinted)
                    let failFile = debugDir.appendingPathComponent("parsefail_\(Date().timeIntervalSince1970).json")
                    try failData.write(to: failFile, options: .atomic)
                } catch {
                    logger("⚠️ Failed to save parse failure debug: \(error)")
                }

                throw NSError(domain: "UnguidedParse", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse JSON array from response"
                ])

            } catch {
                lastError = error
                let attemptElapsed = Date().timeIntervalSince(attemptStart)
                logger("❌ [DEBUG] Unguided generation failed after \(String(format: "%.2f", attemptElapsed))s: \(error)")

                // Record failed telemetry
                telemetry.append(AttemptMetrics(
                    attemptIndex: attempt,
                    seed: initialSeed,
                    sampling: "unguided:\(profile.description)",
                    temperature: currentOptions.temperature,
                    sessionRecreated: sessionRecreated,
                    itemsReturned: 0,
                    elapsedSec: attemptElapsed
                ))

                // Adaptive boost on first failure
                if attempt == 0 {
                    let currentMax = currentOptions.maximumResponseTokens ?? 256
                    let boosted = min(512, Int(Double(currentMax) * 1.8))
                    if boosted > currentMax {
                        logger("🔁 Boosting maxTokens → \(boosted) for unguided parse retry")
                        currentOptions = profile.options(
                            seed: initialSeed,
                            temp: max(0.0, (temperature ?? 0.7) * 0.9),
                            maxTok: boosted
                        )
                        continue
                    }
                }

                // Session refresh on second failure
                if attempt == 1, let factory = sessionFactory {
                    do {
                        session = try await factory()
                        logger("♻️ Recreating session for unguided retry")
                    } catch {
                        logger("⚠️ Failed to create fresh session: \(error)")
                    }
                }
            }
        }

        throw lastError ?? NSError(domain: "Unguided", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "All unguided retries failed"
        ])
    }

    /// Tolerant JSON array parser - extracts first [...] and parses strings or objects with "name" field.
    /// Handles both ["item1", "item2"] and [{"name": "item1"}, {"name": "item2"}] formats.
    /// Strips markdown code fences (```json ... ```) before parsing.
    /// Falls back to regex extraction of quoted strings even when array is truncated.
    private func parseJSONArray(_ text: String) -> [String]? {
        // Strip markdown code fences if present (handles newlines)
        var cleanedText = text
        // Remove ```json\n or ```json variants
        cleanedText = cleanedText.replacingOccurrences(of: #"```json\s*"#, with: "", options: .regularExpression)
        // Remove closing ``` fences
        cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")

        // Find first [ - closing ] is optional (may be truncated)
        guard let start = cleanedText.firstIndex(of: "[") else {
            return nil
        }

        // Try to find closing bracket, but continue if missing (truncated array)
        let slice: String
        if let end = cleanedText.lastIndex(of: "]"), start < end {
            slice = String(cleanedText[start...end])
        } else {
            // Truncated array - use everything from [ onwards
            slice = String(cleanedText[start...])
        }

        // Try standard JSON parsing first (only works if array is complete)
        if let data = slice.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            // Handle both string arrays and object arrays with "name" field
            return json.compactMap { element -> String? in
                // Try direct string first
                if let string = element as? String {
                    return string
                }
                // Try extracting from object with "name" field
                if let dict = element as? [String: Any],
                   let name = dict["name"] as? String {
                    return name
                }
                return nil
            }
        }

        // Salvage: extract quoted strings with regex (handles truncated arrays)
        var extracted: [String] = []
        let pattern = #""([^"\\]|\\.)*""#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = slice as NSString
            let matches = regex.matches(in: slice, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let quoted = nsString.substring(with: match.range)
                let unquoted = quoted.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                extracted.append(unquoted)
            }
        }

        return extracted.isEmpty ? nil : extracted
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
    private let fm: FMClient
    private let logger: (String) -> Void
    private var telemetry: [AttemptMetrics] = []
    private let useGuidedBackfill: Bool

    // Run diagnostics (populated by uniqueList())
    private var lastRunTotalGenerated: Int?
    private var lastRunDupCount: Int?
    private var lastRunDupRate: Double?
    private var lastRunBackfillRounds: Int?
    private var lastRunCircuitBreakerTriggered: Bool?
    private var lastRunPassCount: Int?
    private var lastRunFailureReason: String?
    private var lastRunTopDuplicates: [String: Int]?

    init(fm: FMClient, logger: @escaping (String) -> Void = { print($0) }, useGuidedBackfill: Bool = false) {
        self.fm = fm
        self.logger = logger
        self.useGuidedBackfill = useGuidedBackfill
    }

    /// Export telemetry for a test run
    func exportRunTelemetry(
        testId: String,
        query: String,
        targetN: Int,
        totalGenerated: Int? = nil,
        dupCount: Int? = nil,
        dupRate: Double? = nil,
        backfillRounds: Int? = nil,
        circuitBreakerTriggered: Bool? = nil,
        passCount: Int? = nil,
        failureReason: String? = nil,
        topDuplicates: [String: Int]? = nil
    ) {
        guard !telemetry.isEmpty else { return }

        let osVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }()

        var records: [RunTelemetry] = []
        var passIndex = 1

        for metric in telemetry {
            records.append(RunTelemetry(
                testId: testId,
                query: query,
                targetN: targetN,
                passIndex: passIndex,
                attemptIndex: metric.attemptIndex,
                seed: metric.seed,
                sampling: metric.sampling,
                temperature: metric.temperature,
                sessionRecreated: metric.sessionRecreated,
                itemsReturned: metric.itemsReturned ?? 0,
                elapsedSec: metric.elapsedSec ?? 0,
                osVersion: osVersion,
                // Use provided parameters, fall back to stored diagnostics
                totalGenerated: totalGenerated ?? lastRunTotalGenerated,
                dupCount: dupCount ?? lastRunDupCount,
                dupRate: dupRate ?? lastRunDupRate,
                backfillRounds: backfillRounds ?? lastRunBackfillRounds,
                circuitBreakerTriggered: circuitBreakerTriggered ?? lastRunCircuitBreakerTriggered,
                passCount: passCount ?? lastRunPassCount,
                failureReason: failureReason ?? lastRunFailureReason,
                topDuplicates: topDuplicates ?? lastRunTopDuplicates
            ))
        }

        exportTelemetryToJSONL(records)
    }

    /// Diagnostics snapshot from the last uniqueList() run
    struct RunDiagnostics {
        let totalGenerated: Int?
        let dupCount: Int?
        let dupRate: Double?
        let backfillRounds: Int?
        let circuitBreakerTriggered: Bool?
        let passCount: Int?
        let failureReason: String?
        let topDuplicates: [String: Int]?
    }

    /// Retrieve diagnostics from the last uniqueList() run
    func getDiagnostics() -> RunDiagnostics {
        return RunDiagnostics(
            totalGenerated: lastRunTotalGenerated,
            dupCount: lastRunDupCount,
            dupRate: lastRunDupRate,
            backfillRounds: lastRunBackfillRounds,
            circuitBreakerTriggered: lastRunCircuitBreakerTriggered,
            passCount: lastRunPassCount,
            failureReason: lastRunFailureReason,
            topDuplicates: lastRunTopDuplicates
        )
    }

    /// Generate N unique items using Generate → Dedup → Fill architecture
    func uniqueList(query: String, N: Int, seed: UInt64? = nil) async throws -> [String] {
        let startTime = Date()
        var ordered: [String] = []
        var seen = Set<String>()
        var totalGeneratedCount = 0
        var duplicatesFound = 0
        var passCount = 0
        var localTelemetry: [AttemptMetrics] = []  // Local telemetry to avoid actor isolation issues
        var dupFrequency: [String: Int] = [:]  // Track frequency for guided backfill

        // Diagnostics tracking
        var backfillRoundsTotal = 0
        var circuitBreakerTriggered = false

        func absorb(_ items: [String]) {
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
                if ordered.count >= N { return }
            }
        }

        // PASS 1: Over-generate with diverse sampling
        logger("🎯 [Pass 1] Target: \(N) unique items")

        // Token budgeting: compute M1 from budget instead of hard cap
        let budget = 3500
        let prompt1Base = """
        Return ONLY a JSON object matching the schema.
        Task: \(query). Produce
        """
        let promptTok = (prompt1Base.count + 20) / 4  // Rough estimate with margin
        let respBudget = max(0, budget - promptTok)
        let avgTPI = 7
        let mByBudget = respBudget / avgTPI
        let M1 = min(Int(ceil(Double(N) * Defaults.pass1OverGen)), mByBudget)
        let maxTok1 = Int(ceil(7.0 * Double(M1)))

        let prompt1 = """
        Return ONLY a JSON object matching the schema.
        Task: \(query). Produce \(M1) distinct items.
        """

        logger("  Requesting \(M1) items (over-gen: \(String(format: "%.1f", Defaults.pass1OverGen))x, budget: \(maxTok1) tokens)")

        // Use top-p profile for diverse sampling
        let profile1 = DecoderProfile.topP(0.92)
        let items1 = try await fm.generate(
            prompt1,
            profile: profile1,
            initialSeed: seed,
            temperature: Defaults.tempDiverse,
            maxTokens: maxTok1,
            telemetry: &localTelemetry
        )
        absorb(items1)
        passCount = 1

        logger("  Result: \(ordered.count)/\(N) unique, \(duplicatesFound) duplicates filtered")

        if ordered.count >= N {
            let elapsed = Date().timeIntervalSince(startTime)
            logger("✅ Success in \(passCount) pass (\(String(format: "%.2f", elapsed))s)")
            return Array(ordered.prefix(N))
        }

        // BACKFILL: Use guided or unguided based on flag
        if useGuidedBackfill {
            // GUIDED BACKFILL: Use JSON schema enforcement with rotating avoid-list samples
            var backfillRound = 0
            var consecutiveNoProgress = 0

            while ordered.count < N && backfillRound < Defaults.maxPasses {
                backfillRound += 1
                backfillRoundsTotal += 1
                passCount += 1

                let deltaNeed = N - ordered.count
                // Request more than needed to account for potential duplicates
                let delta = max(Int(ceil(Double(deltaNeed) * 1.5)), Int(ceil(Defaults.minBackfillFrac * Double(N))))
                // More generous token budget: match unguided approach
                let maxTok = max(1024, delta * 20)

                let avoid = Array(seen)
                logger("🔄 [Pass \(passCount)] Guided Backfill: need \(deltaNeed), requesting \(delta), avoiding \(avoid.count) items")

                // Rotating avoid-list sample: show different items each pass for better coverage
                // Pass 1: items 0-40, Pass 2: items 20-60, Pass 3: items 40-80, etc.
                let sampleSize = 40
                let offset = (backfillRound - 1) * 20  // 20-item overlap between passes
                let startIdx = offset % max(1, avoid.count)
                let endIdx = min(startIdx + sampleSize, avoid.count)

                // Build sample with wraparound if needed
                var avoidSampleKeys: [String] = []
                if endIdx <= avoid.count {
                    avoidSampleKeys = Array(avoid[startIdx..<endIdx])
                } else {
                    avoidSampleKeys = Array(avoid[startIdx..<avoid.count])
                    let remaining = sampleSize - avoidSampleKeys.count
                    avoidSampleKeys += Array(avoid.prefix(remaining))
                }

                // Add frequency hints for repeat offenders
                let topOffenders = dupFrequency
                    .sorted { $0.value > $1.value }
                    .prefix(5)
                    .map { "\"\($0.key)\" (filtered \($0.value)x)" }
                    .joined(separator: ", ")

                let avoidSample = avoidSampleKeys.map { "\"\($0)\"" }.joined(separator: ", ")
                let coverageNote = avoid.count > sampleSize ?
                    "\n  Showing \(avoidSampleKeys.count) of \(avoid.count) forbidden items (rotating sample, pass \(backfillRound))" : ""
                let offenderNote = !topOffenders.isEmpty ?
                    "\n  Most repeated: [\(topOffenders)]" : ""

                let promptFill = """
                Return ONLY a JSON object matching the schema.
                Task: \(query). Produce \(delta) distinct items.

                CRITICAL: Do NOT include items with these normalized keys:
                [\(avoidSample)]\(coverageNote)\(offenderNote)

                Generate NEW items that are NOT in the forbidden list above.
                """

                let before = ordered.count

                do {
                    let itemsFill = try await fm.generate(
                        promptFill,
                        profile: .topP(0.92),
                        initialSeed: UInt64.random(in: 0...UInt64.max),
                        temperature: Defaults.tempDiverse,
                        maxTokens: maxTok,
                        telemetry: &localTelemetry
                    )
                    absorb(itemsFill)
                } catch {
                    logger("⚠️ Guided backfill error: \(error)")

                    // Capture failure reason if not already set
                    if self.lastRunFailureReason == nil {
                        self.lastRunFailureReason = "Guided backfill error: \(error.localizedDescription)"
                    }
                }

                // Adaptive retry if no progress
                if ordered.count == before {
                    do {
                        let retryDelta = min(deltaNeed * 2, Int(ceil(Double(N) * 0.5)))
                        logger("  ⟳ Retry: requesting \(retryDelta) items with higher temperature")

                        // Emphasize top offenders in retry
                        let retryOffenders = dupFrequency
                            .sorted { $0.value > $1.value }
                            .prefix(10)  // Show more in retry
                            .map { "\"\($0.key)\" (\($0.value)x)" }
                            .joined(separator: ", ")

                        let promptRetry = """
                        Return ONLY a JSON object matching the schema.
                        Task: \(query). Produce \(retryDelta) distinct items.

                        CRITICAL: Avoid these items (most frequently repeated):
                        [\(retryOffenders)]

                        Also avoid: [\(avoidSample)]
                        """

                        let itemsRetry = try await fm.generate(
                            promptRetry,
                            profile: .topK(50),
                            initialSeed: UInt64.random(in: 0...UInt64.max),
                            temperature: 0.9,
                            maxTokens: max(1536, retryDelta * 25),
                            telemetry: &localTelemetry
                        )
                        absorb(itemsRetry)
                    } catch {
                        logger("⚠️ Adaptive retry failed: \(error)")

                        // Capture failure reason if not already set
                        if self.lastRunFailureReason == nil {
                            self.lastRunFailureReason = "Adaptive retry failed: \(error.localizedDescription)"
                        }
                    }
                }

                logger("  Result: \(ordered.count)/\(N) unique (filtered \(duplicatesFound) duplicates)")

                // Circuit breaker
                if ordered.count == before {
                    consecutiveNoProgress += 1
                    if consecutiveNoProgress >= 2 {
                        logger("⚠️ Circuit breaker: 2 consecutive rounds with no progress. Exiting backfill early.")
                        circuitBreakerTriggered = true
                        break
                    }
                } else {
                    consecutiveNoProgress = 0
                }

                // Greedy last-mile for final 1-2 items
                if (1...2).contains(N - ordered.count) {
                    do {
                        let remaining = N - ordered.count
                        logger("  🎯 Greedy last-mile: requesting \(remaining) item(s)")

                        let greedyPrompt = """
                        Return ONLY a JSON object matching the schema.
                        Task: \(query). Produce EXACTLY \(remaining) distinct item\(remaining > 1 ? "s" : "").
                        """

                        let greedyItems = try await fm.generate(
                            greedyPrompt,
                            profile: .greedy,
                            initialSeed: nil,
                            temperature: 0.0,
                            maxTokens: 512,
                            telemetry: &localTelemetry
                        )
                        absorb(greedyItems)
                    } catch {
                        logger("⚠️ Greedy last-mile failed: \(error)")

                        // Capture failure reason if not already set
                        if self.lastRunFailureReason == nil {
                            self.lastRunFailureReason = "Greedy last-mile failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        } else {
            // UNGUIDED BACKFILL: Semantic constraints in prompt
            var backfillRound = 0
            var consecutiveNoProgress = 0  // Circuit breaker: exit early if no progress
            while ordered.count < N && backfillRound < Defaults.maxPasses {
                backfillRound += 1
                backfillRoundsTotal += 1
                passCount += 1

                let deltaNeed = N - ordered.count

                // Token budgeting - INCREASED for better results
                let backfillAvgTPI = 20  // Increased from 16 for more room per item
                let promptFillBase = "Generate NEW items for: \(query). Do NOT include any with norm_keys in:"
                let baseTok = (promptFillBase.count + 50) / 4
                let respBudget = max(0, budget - baseTok - 200)
                let deltaByBudget = respBudget / backfillAvgTPI
                // Request 4x items to account for high duplicate rate (~50%) in unguided generation
                let deltaWithDupBuffer = Int(ceil(Double(deltaNeed) * 4.0))
                let delta = min(max(deltaWithDupBuffer, Int(ceil(Defaults.minBackfillFrac * Double(N)))), deltaByBudget)
                // Significantly increased minimum and multiplier for better generation
                let maxTok = max(1024, delta * backfillAvgTPI * 2)  // 2x multiplier and 1024 min

                logger("🔄 [Pass \(passCount)] Unguided Backfill: need \(deltaNeed), requesting \(delta)")

                let avoid = Array(seen)
                let avoidJSON = avoid.map { "\"\($0)\"" }.joined(separator: ",")

                let promptFill = """
                Generate EXACTLY \(delta) NEW unique items for: \(query).
                Do NOT include any with norm_keys in:
                [\(avoidJSON)]

                Return ONLY a JSON array with \(delta) string items.
                Format: ["item1", "item2", "item3", ...]
                Include all \(delta) items in your response.
                """

                let before = ordered.count

                do {
                    let itemsFill = try await fm.generateTextArray(
                        promptFill,
                        profile: .topK(40),
                        initialSeed: UInt64.random(in: 0...UInt64.max),
                        temperature: 0.6,
                        maxTokens: maxTok,
                        telemetry: &localTelemetry
                    )
                    absorb(itemsFill)
                } catch {
                    logger("⚠️ Unguided backfill error: \(error)")

                    // Capture failure reason if not already set
                    if self.lastRunFailureReason == nil {
                        self.lastRunFailureReason = "Unguided backfill error: \(error.localizedDescription)"
                    }
                }

                // Adaptive retry if no progress
                if ordered.count == before {
                    do {
                        // Request 5x items in retry to maximize chance of getting enough unique items
                        let retryCount = min((N - ordered.count) * 5, deltaByBudget)
                        let promptRetry = """
                        Generate EXACTLY \(retryCount) NEW unique items for: \(query).
                        Do NOT include any with norm_keys in: [\(avoidJSON)]

                        Return ONLY a JSON array with \(retryCount) string items.
                        Format: ["item1", "item2", "item3", ...]
                        """
                        let itemsRetry = try await fm.generateTextArray(
                            promptRetry,
                            profile: .topK(40),
                            initialSeed: UInt64.random(in: 0...UInt64.max),
                            temperature: 0.55,
                            maxTokens: max(1536, retryCount * 30),  // More generous tokens
                            telemetry: &localTelemetry
                        )
                        absorb(itemsRetry)
                    } catch {
                        logger("⚠️ Adaptive retry also failed: \(error)")

                        // Capture failure reason if not already set
                        if self.lastRunFailureReason == nil {
                            self.lastRunFailureReason = "Adaptive retry also failed: \(error.localizedDescription)"
                        }
                    }
                }

                logger("  Result: \(ordered.count)/\(N) unique")

                // Circuit breaker: track consecutive rounds with no progress
                if ordered.count == before {
                    consecutiveNoProgress += 1
                    if consecutiveNoProgress >= 2 {
                        logger("⚠️ Circuit breaker: 2 consecutive rounds with no progress. Exiting backfill early.")
                        circuitBreakerTriggered = true
                        break
                    }
                } else {
                    consecutiveNoProgress = 0  // Reset on any progress
                }

                // Greedy last-mile for final 1-2 items
                if (1...2).contains(N - ordered.count) {
                    do {
                        let remaining = N - ordered.count
                        let greedyPrompt = """
                        Generate EXACTLY \(remaining) NEW unique item\(remaining > 1 ? "s" : "") for: \(query).

                        Return ONLY a JSON array with \(remaining) string item\(remaining > 1 ? "s" : "").
                        Format: \(remaining == 1 ? "[\"item\"]" : "[\"item1\", \"item2\"]")
                        """
                        let greedyItems = try await fm.generateTextArray(
                            greedyPrompt,
                            profile: .greedy,
                            initialSeed: nil,
                            temperature: 0.0,
                            maxTokens: 512,  // Increased from 200
                            telemetry: &localTelemetry
                        )
                        absorb(greedyItems)
                    } catch {
                        logger("⚠️ Greedy last-mile failed: \(error)")

                        // Capture failure reason if not already set
                        if self.lastRunFailureReason == nil {
                            self.lastRunFailureReason = "Greedy last-mile failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let success = ordered.count >= N

        // Store telemetry
        telemetry = localTelemetry

        if success {
            logger("✅ Success in \(passCount) passes (\(String(format: "%.2f", elapsed))s)")
        } else {
            logger("⚠️ Incomplete: \(ordered.count)/\(N) after \(passCount) passes")
        }

        logger("📊 Stats: \(totalGeneratedCount) total generated, \(duplicatesFound) filtered (\(String(format: "%.1f", Double(duplicatesFound) / Double(totalGeneratedCount) * 100))% dup rate)")

        // Store diagnostics for telemetry export
        lastRunTotalGenerated = totalGeneratedCount
        lastRunDupCount = duplicatesFound
        lastRunDupRate = totalGeneratedCount > 0 ? Double(duplicatesFound) / Double(totalGeneratedCount) : 0.0
        lastRunPassCount = passCount
        lastRunBackfillRounds = backfillRoundsTotal
        lastRunCircuitBreakerTriggered = circuitBreakerTriggered

        // Extract top 5 duplicates
        let topDups = dupFrequency.sorted { $0.value > $1.value }.prefix(5)
        lastRunTopDuplicates = topDups.isEmpty ? nil : Dictionary(uniqueKeysWithValues: Array(topDups))

        // Failure reason (if incomplete)
        if !success {
            if circuitBreakerTriggered {
                lastRunFailureReason = "Circuit breaker: 2 consecutive rounds with no progress at \(ordered.count)/\(N)"
            } else {
                lastRunFailureReason = "Incomplete: \(ordered.count)/\(N) items after \(passCount) passes"
            }
        } else {
            lastRunFailureReason = nil
        }

        return Array(ordered.prefix(N))
    }

    /// Generate unique list with full telemetry
    func uniqueListWithMetrics(
        query: String,
        N: Int,
        seed: UInt64? = nil,
        decoderProfile: String = "diverse"
    ) async throws -> (items: [String], metrics: RunMetrics) {
        let startTime = Date()
        let items = try await uniqueList(query: query, N: N, seed: seed)
        let elapsed = Date().timeIntervalSince(startTime)

        let metrics = RunMetrics(
            passAtN: items.count >= N,
            uniqueAtN: items.count,
            jsonStrictSuccess: true,
            itemsPerSecond: Double(items.count) / max(0.001, elapsed),
            dupRatePreDedup: 0.0, // TODO: Track this in absorb
            seed: seed,
            decoderProfile: decoderProfile,
            env: RunEnv(),
            generationTimeSeconds: elapsed,
            totalPasses: 0 // TODO: Track this
        )

        return (items, metrics)
    }
}
#endif

// MARK: - Diagnostic Helpers

func looksLikeJSON5(_ s: String) -> Bool {
    s.range(of: #"//|/\*|\*/"#, options: .regularExpression) != nil ||
    s.range(of: #",\s*[}\]]"#, options: .regularExpression) != nil
}
