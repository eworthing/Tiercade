import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - UniqueListGenerationFlags

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

// MARK: - Defaults

enum Defaults {
    nonisolated static let maxPasses = 3
    nonisolated static let pass1OverGen = 1.6 // M = ceil(1.6 * N)
    nonisolated static let minBackfillFrac = 0.4 // backfill delta floor
    nonisolated static let tempDiverse = 0.8
    nonisolated static let tempControlled = 0.7
    nonisolated static let conservativeContextBudget = 3500
}

// MARK: - NormConfig

enum NormConfig {
    static let pluralExceptions: Set<String> = [
        // Words ending in "ss"
        "bass", "glass", "chess", "success", "process", "class", "mass", "news",
        "dress", "stress", "mess", "loss", "boss", "cross", "pass", "grass",
        "brass", "compass", "genius", "princess", "duchess", "business",
        // Words ending in "es" that don't pluralize simply
        "analysis", "basis", "crisis", "hypothesis", "diagnosis", "thesis",
        // Irregular plurals
        "person", "child", "man", "woman", "foot", "tooth", "mouse", "goose",
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
            while
                let firstWord = result.split(separator: " ").first,
                articles.contains(firstWord.lowercased())
            {
                result.removeFirst(firstWord.count)
                result = result.trimmingCharacters(in: .whitespaces)
            }
            return result
        }

        // Split on delimiters that start new segments (colon, hyphen)
        let withSpacedHyphens = replacingOccurrences(of: "-", with: " ")
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
            withTemplate: "",
        )

        // Map & to and
        s = s.replacingOccurrences(of: "&", with: " and ")

        // Remove bracketed content
        s = NormConfig.reBrackets.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: "",
        )

        // Recursive article removal with delimiter awareness
        s = s.trimLeadingArticlesRecursive()

        // Strip punctuation
        s = NormConfig.rePunct.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " ",
        )

        // Collapse whitespace
        s = NormConfig.reWs.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " ",
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Optional plural trimming
        guard UniqueListGenerationFlags.pluralTrimEnabled else {
            return s
        }
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

extension [String] {
    /// Chunk array by token budget for avoid-list management
    func chunkedByTokenBudget(
        maxTokens: Int,
        estimate: (String) -> Int = { ($0.count + 3) / 4 },
    )
        -> [[String]]
    {
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
    nonisolated static func topK(_ k: Int, temp: Double, seed: UInt64?, maxTok: Int) -> Self {
        .init(
            sampling: .random(top: k, seed: seed),
            temperature: temp,
            maximumResponseTokens: maxTok,
        )
    }

    /// Top-P sampling configuration (requires iOS 26+/macOS 26+)
    nonisolated static func topP(_ p: Double, temp: Double, seed: UInt64?, maxTok: Int) -> Self {
        .init(
            sampling: .random(probabilityThreshold: p, seed: seed),
            temperature: temp,
            maximumResponseTokens: maxTok,
        )
    }

    /// Greedy deterministic sampling
    nonisolated static var greedy: Self {
        .init(
            sampling: .greedy,
            temperature: 0,
            maximumResponseTokens: 256,
        )
    }

    /// Diverse sampling (uses top-p on supported platforms, falls back to top-k)
    nonisolated static func diverse(seed: UInt64?, maxTok: Int) -> Self {
        topP(0.92, temp: Defaults.tempDiverse, seed: seed, maxTok: maxTok)
    }

    /// Controlled sampling (top-k with lower temperature)
    nonisolated static func controlled(seed: UInt64?, maxTok: Int) -> Self {
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

// MARK: - RunEnv

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

// MARK: - RunMetrics

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
/// Profile that preserves sampling strategy across retries
@available(iOS 26.0, macOS 26.0, *)
enum DecoderProfile {
    case greedy
    case topK(Int)
    case topP(Double)

    // MARK: Internal

    var description: String {
        switch self {
        case .greedy: "greedy"
        case let .topK(k): "topK:\(k)"
        case let .topP(p): "topP:\(p)"
        }
    }

    func options(seed: UInt64?, temp: Double?, maxTok: Int?) -> GenerationOptions {
        switch self {
        case .greedy:
            GenerationOptions(sampling: .greedy, temperature: temp, maximumResponseTokens: maxTok)
        case let .topK(k):
            GenerationOptions(
                sampling: .random(top: k, seed: seed),
                temperature: temp,
                maximumResponseTokens: maxTok,
            )
        case let .topP(p):
            GenerationOptions(
                sampling: .random(probabilityThreshold: p, seed: seed),
                temperature: temp,
                maximumResponseTokens: maxTok,
            )
        }
    }

}
#endif

// MARK: - AttemptMetrics

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

// MARK: - RunTelemetry

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
    let topDuplicates: [String: Int]? // Top 5 duplicate items with counts
}

/// Export telemetry to JSONL
@MainActor
func exportTelemetryToJSONL(_ records: [RunTelemetry], to path: String? = nil) {
    guard !records.isEmpty else {
        return
    }

    // Use sandbox temp directory for security
    let defaultPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("unique_list_runs.jsonl").path
    let targetPath = path ?? defaultPath

    let encoder = JSONEncoder()
    encoder.outputFormatting = [] // Compact JSON for JSONL

    do {
        let fileURL = URL(fileURLWithPath: targetPath)

        // CAP: Rotate file at 10MB to prevent unbounded growth
        if FileManager.default.fileExists(atPath: targetPath) {
            let attrs = try FileManager.default.attributesOfItem(atPath: targetPath)
            if let size = (attrs[.size] as? NSNumber)?.intValue, size > 10_000_000 {
                let backupPath = targetPath.replacingOccurrences(
                    of: ".jsonl",
                    with: "_\(Date().timeIntervalSince1970).jsonl",
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
            #if os(macOS)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: targetPath,
            )
            #endif
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
