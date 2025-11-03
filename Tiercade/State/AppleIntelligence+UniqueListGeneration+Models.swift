import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Feature Flags

/// Feature flags for unique list generation (POC)
internal enum UniqueListGenerationFlags {
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

internal enum Defaults {
    nonisolated(unsafe) static let maxPasses = 3
    nonisolated(unsafe) static let pass1OverGen = 1.6      // M = ceil(1.6 * N)
    nonisolated(unsafe) static let minBackfillFrac = 0.4    // backfill delta floor
    nonisolated(unsafe) static let tempDiverse = 0.8
    nonisolated(unsafe) static let tempControlled = 0.7
    nonisolated(unsafe) static let conservativeContextBudget = 3500
}

// MARK: - Normalization Configuration

internal struct NormConfig {
    internal static let pluralExceptions: Set<String> = [
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
    internal static let reMarks: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: "[™®©]")
        } catch {
            fatalError("Invalid regex pattern for trademark symbols: \(error)")
        }
    }()
    internal static let reBrackets: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"\s*[\(\[][^\)\]]*[\)\]]"#)
        } catch {
            fatalError("Invalid regex pattern for brackets: \(error)")
        }
    }()
    internal static let reLeadArticles: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"^(the|a|an)\s+"#, options: [.caseInsensitive])
        } catch {
            fatalError("Invalid regex pattern for leading articles: \(error)")
        }
    }()
    internal static let rePunct: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"[[:punct:]]+"#)
        } catch {
            fatalError("Invalid regex pattern for punctuation: \(error)")
        }
    }()
    internal static let reWs: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"\s+"#)
        } catch {
            fatalError("Invalid regex pattern for whitespace: \(error)")
        }
    }()
}

// MARK: - String Normalization Extension

internal extension String {
    /// Recursively trim leading articles with delimiter awareness
    private func trimLeadingArticlesRecursive() -> String {
        internal let articles = Set(["a", "an", "the"])

        internal func stripArticles(_ text: String) -> String {
            internal var result = text.trimmingCharacters(in: .whitespaces)
            while let firstWord = result.split(separator: " ").first,
                  articles.contains(firstWord.lowercased()) {
                result.removeFirst(firstWord.count)
                result = result.trimmingCharacters(in: .whitespaces)
            }
            return result
        }

        // Split on delimiters that start new segments (colon, hyphen)
        internal let withSpacedHyphens = self.replacingOccurrences(of: "-", with: " ")
        internal let segments = withSpacedHyphens.split(separator: ":").map { stripArticles(String($0)) }
        return segments.joined(separator: ":")
    }

    /// Compute deterministic normalization key for deduplication
    internal var normKey: String {
        internal var s = lowercased().folding(options: .diacriticInsensitive, locale: .current)

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
        internal var parts = s.split(separator: " ").map(String.init)
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

internal extension Array where Element == String {
    /// Chunk array by token budget for avoid-list management
    internal func chunkedByTokenBudget(
        maxTokens: Int,
        estimate: (String) -> Int = { ($0.count + 3) / 4 }
    ) -> [[String]] {
        internal var chunks: [[String]] = []
        internal var current: [String] = []
        internal var tally = 0

        for k in self {
            internal let t = estimate(k) + 2 // quotes + comma
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
internal extension GenerationOptions {
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
internal struct UniqueListResponse: Decodable {
    internal var items: [String]
}
#endif

// MARK: - Telemetry Structures

internal struct RunEnv: Codable {
    internal let osVersionString: String
    internal let osVersion: String
    internal let hasTopP: Bool
    internal let deploymentTag: String?

    internal init(deploymentTag: String? = nil) {
        self.osVersionString = ProcessInfo.processInfo.operatingSystemVersionString

        internal let v = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"

        if #available(iOS 26.0, macOS 26.0, *) {
            self.hasTopP = true
        } else {
            self.hasTopP = false
        }

        self.deploymentTag = deploymentTag
    }
}

internal struct RunMetrics: Codable {
    internal let passAtN: Bool
    internal let uniqueAtN: Int
    internal let jsonStrictSuccess: Bool
    internal let itemsPerSecond: Double
    internal let dupRatePreDedup: Double
    internal let seed: UInt64?
    internal let decoderProfile: String
    internal let env: RunEnv
    internal let generationTimeSeconds: Double
    internal let totalPasses: Int
}

// MARK: - Decoder Profile

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
/// Profile that preserves sampling strategy across retries
internal enum DecoderProfile {
    case greedy
    case topK(Int)
    case topP(Double)

    internal func options(seed: UInt64?, temp: Double?, maxTok: Int?) -> GenerationOptions {
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

    internal var description: String {
        switch self {
        case .greedy: return "greedy"
        case .topK(let k): return "topK:\(k)"
        case .topP(let p): return "topP:\(p)"
        }
    }
}
#endif

/// Per-attempt telemetry for diagnostics
internal struct AttemptMetrics: Codable {
    internal let attemptIndex: Int
    internal let seed: UInt64?
    internal let sampling: String
    internal let temperature: Double?
    internal let sessionRecreated: Bool
    internal let itemsReturned: Int?
    internal let elapsedSec: Double?
}

/// Full run telemetry for export
internal struct RunTelemetry: Codable {
    internal let testId: String
    internal let query: String
    internal let targetN: Int
    internal let passIndex: Int
    internal let attemptIndex: Int
    internal let seed: UInt64?
    internal let sampling: String
    internal let temperature: Double?
    internal let sessionRecreated: Bool
    internal let itemsReturned: Int
    internal let elapsedSec: Double
    internal let osVersion: String

    // Diagnostic fields (all optional for backward compatibility)
    internal let totalGenerated: Int?
    internal let dupCount: Int?
    internal let dupRate: Double?
    internal let backfillRounds: Int?
    internal let circuitBreakerTriggered: Bool?
    internal let passCount: Int?
    internal let failureReason: String?
    internal let topDuplicates: [String: Int]?  // Top 5 duplicate items with counts
}

/// Export telemetry to JSONL
@MainActor
internal func exportTelemetryToJSONL(_ records: [RunTelemetry], to path: String? = nil) {
    guard !records.isEmpty else { return }

    // Use sandbox temp directory for security
    internal let defaultPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("unique_list_runs.jsonl").path
    internal let targetPath = path ?? defaultPath

    internal let encoder = JSONEncoder()
    encoder.outputFormatting = []  // Compact JSON for JSONL

    do {
        internal let fileURL = URL(fileURLWithPath: targetPath)

        // CAP: Rotate file at 10MB to prevent unbounded growth
        if FileManager.default.fileExists(atPath: targetPath) {
            internal let attrs = try FileManager.default.attributesOfItem(atPath: targetPath)
            if let size = (attrs[.size] as? NSNumber)?.intValue, size > 10_000_000 {
                internal let backupPath = targetPath.replacingOccurrences(
                    of: ".jsonl",
                    with: "_\(Date().timeIntervalSince1970).jsonl"
                )
                try? FileManager.default.moveItem(atPath: targetPath, toPath: backupPath)
                print("📊 Rotated telemetry log (>10MB) to: \(backupPath)")
            }
        }

        internal let fileHandle: FileHandle

        // Create or append to file
        if FileManager.default.fileExists(atPath: targetPath) {
            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
        } else {
            FileManager.default.createFile(atPath: targetPath, contents: nil)
            #if os(macOS)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: targetPath
            )
            #endif
            fileHandle = try FileHandle(forWritingTo: fileURL)
        }

        defer { try? fileHandle.close() }

        for record in records {
            internal let data = try encoder.encode(record)
            fileHandle.write(data)
            fileHandle.write(Data("\n".utf8))
        }
    } catch {
        print("⚠️ Failed to export telemetry: \(error)")
    }
}
