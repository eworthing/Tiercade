import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - FM Client Wrapper

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class FMClient {
    internal var session: LanguageModelSession
    internal let logger: (String) -> Void
    internal let sessionFactory: (() async throws -> LanguageModelSession)?

    // Deterministic seed ring for reproducible retries
    internal static let seedRing: [UInt64] = [42, 1337, 9999, 123456, 987654]

    internal init(
        session: LanguageModelSession,
        logger: @escaping (String) -> Void,
        sessionFactory: (() async throws -> LanguageModelSession)? = nil
    ) {
        self.session = session
        self.logger = logger
        self.sessionFactory = sessionFactory
    }

    internal struct GenerateParameters {
        internal let prompt: String
        internal let profile: DecoderProfile
        internal let initialSeed: UInt64?
        internal let temperature: Double?
        internal let maxTokens: Int?
        internal let maxRetries: Int
    }

    /// Generate using guided schema with automatic retry on seed-dependent failures
    internal func generate(
        _ params: GenerateParameters,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        internal let start = Date()
        internal var retryState = initializeRetryState(params: params)

        logGenerationStart(params: params)

        for attempt in 0..<params.maxRetries {
            internal let attemptStart = Date()
            // INVARIANT: Reset per-attempt flags to preserve telemetry accuracy (see 1c5d26b).
            // This flag is scoped per attempt; handleAttemptFailure may set it to true during
            // session recreation, but it must start false each iteration for accurate reporting.
            retryState.sessionRecreated = false

            logAttemptDetails(attempt: attempt, maxRetries: params.maxRetries, options: retryState.options)

            do {
                internal let response = try await executeGuidedGeneration(
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
                        sessionRecreated: retryState.sessionRecreated,
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
                    retryState: &retryState,
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

    internal struct RetryState {
        internal var options: GenerationOptions
        internal var seed: UInt64?
        internal var lastError: Error?
        internal var sessionRecreated: Bool = false
    }

    public struct AttemptContext: Sendable {
        internal let attempt: Int
        internal let seed: UInt64?
        internal let profile: DecoderProfile
        internal let options: GenerationOptions
        internal let sessionRecreated: Bool
        internal let elapsed: Double
    }

    public struct ResponseContext {
        internal let response: LanguageModelSession.Response<UniqueListResponse>
        internal let attempt: Int
        internal let attemptStart: Date
        internal let totalStart: Date
        internal let currentSeed: UInt64?
        internal let sessionRecreated: Bool
        internal let params: GenerateParameters
    }

    public struct UnguidedAttemptContext: Sendable {
        internal let attempt: Int
        internal let params: GenerateTextArrayParameters
        internal let options: GenerationOptions
        internal let sessionRecreated: Bool
        internal let elapsed: Double
    }

    internal struct UnguidedRetryState {
        internal var options: GenerationOptions
        internal var lastError: Error?
        internal var sessionRecreated: Bool = false
    }

    internal struct GenerateTextArrayParameters {
        internal let prompt: String
        internal let profile: DecoderProfile
        internal let initialSeed: UInt64?
        internal let temperature: Double?
        internal let maxTokens: Int?
        internal let maxRetries: Int
    }

    /// Unguided generation that returns [String] by parsing JSON text array.
    /// Used for backfill where semantic constraints (avoid-list) must be respected.
    internal func generateTextArray(
        _ params: GenerateTextArrayParameters,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        internal let start = Date()
        internal var retryState = UnguidedRetryState(
            options: params.profile.options(
                seed: params.initialSeed,
                temp: params.temperature,
                maxTok: params.maxTokens
            ),
            lastError: nil
        )

        for attempt in 0..<params.maxRetries {
            internal let attemptStart = Date()
            // INVARIANT: Reset per-attempt flags to preserve telemetry accuracy (see 1c5d26b).
            // This flag is scoped per attempt; handleUnguidedError may set it to true during
            // session recreation, but it must start false each iteration for accurate reporting.
            retryState.sessionRecreated = false

            do {
                internal let response = try await session.respond(
                    to: Prompt(params.prompt),
                    options: retryState.options
                )

                if let arr = try handleUnguidedResponse(
                    response: response,
                    attempt: attempt,
                    attemptStart: attemptStart,
                    totalStart: start,
                    params: params,
                    options: retryState.options,
                    sessionRecreated: retryState.sessionRecreated,
                    telemetry: &telemetry
                ) {
                    return arr
                }

            } catch {
                retryState.lastError = error

                if await handleUnguidedError(
                    error: error,
                    attempt: attempt,
                    attemptStart: attemptStart,
                    params: params,
                    options: retryState.options,
                    currentOptions: &retryState.options,
                    sessionRecreated: &retryState.sessionRecreated,
                    telemetry: &telemetry
                ) {
                    continue
                }
            }
        }

        throw retryState.lastError ?? NSError(domain: "Unguided", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "All unguided retries failed"
        ])
    }
}
#endif

// MARK: - Token Chunking Helper

private func chunkByTokens(_ keys: [String], budget: Int = AIChunkingLimits.tokenBudget) -> [[String]] {
    internal var chunks: [[String]] = []
    internal var cur: [String] = []
    internal var used = 2  // Account for [ ]

    for k in keys {
        internal let t = (k.count + 3) / 4 + 3  // Rough: text + quotes/comma
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
    internal let fm: FMClient
    internal let logger: (String) -> Void
    internal var telemetry: [AttemptMetrics] = []
    internal let useGuidedBackfill: Bool
    // DEBUG: Proactively boost first guided backfill round (no hybrid switch)
    internal var guidedBudgetBumpFirst: Bool = false
    // DEBUG-only: Hybrid switch from guided→unguided backfill by heuristic
    internal var hybridSwitchEnabled: Bool = false
    internal var hybridDupThreshold: Double = 0.70  // 70% round dup-rate
    internal enum PromptStyle: String, Sendable { case strict, minimal }
    internal var promptStyle: PromptStyle = .strict

    // Run diagnostics (populated by uniqueList())
    internal var lastRunTotalGenerated: Int?
    internal var lastRunDupCount: Int?
    internal var lastRunDupRate: Double?
    internal var lastRunBackfillRounds: Int?
    internal var lastRunCircuitBreakerTriggered: Bool?
    internal var lastRunPassCount: Int?
    internal var lastRunFailureReason: String?
    internal var lastRunTopDuplicates: [String: Int]?

    internal init(
        fm: FMClient,
        logger: @escaping (String) -> Void = { print($0) },
        useGuidedBackfill: Bool = false,
        hybridSwitchEnabled: Bool = false,
        guidedBudgetBumpFirst: Bool = false,
        promptStyle: PromptStyle = .strict
    ) {
        self.fm = fm
        self.logger = logger
        self.useGuidedBackfill = useGuidedBackfill
        self.hybridSwitchEnabled = hybridSwitchEnabled
        self.guidedBudgetBumpFirst = guidedBudgetBumpFirst
        self.promptStyle = promptStyle
    }

    /// Generate N unique items using Generate → Dedup → Fill architecture
    internal func uniqueList(query: String, targetCount: Int, seed: UInt64? = nil) async throws -> [String] {
        internal let startTime = Date()
        internal var state = GenerationState(targetCount: targetCount)

        try await executePass1(query: query, targetCount: targetCount, seed: seed, state: &state)

        if state.ordered.count >= targetCount {
            finalizeSuccess(state: state, startTime: startTime)
            return Array(state.ordered.prefix(targetCount))
        }

        try await executeBackfill(query: query, targetCount: targetCount, state: &state)

        finalizeGeneration(state: state, targetCount: targetCount, startTime: startTime)

        return Array(state.ordered.prefix(targetCount))
    }

    internal struct GenerationState {
        internal var ordered: [String] = []
        internal var seen = Set<String>()
        internal var totalGeneratedCount = 0
        internal var duplicatesFound = 0
        internal var passCount = 0
        internal var localTelemetry: [AttemptMetrics] = []
        internal var dupFrequency: [String: Int] = [:]
        internal var backfillRoundsTotal = 0
        internal var circuitBreakerTriggered = false
        internal let targetCount: Int

        mutating func absorb(
            _ items: [String],
            logger: (String) -> Void
        ) {
            totalGeneratedCount += items.count
            for s in items {
                internal let k = s.normKey
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

internal func looksLikeJSON5(_ s: String) -> Bool {
    s.range(of: #"//|/\*|\*/"#, options: .regularExpression) != nil ||
        s.range(of: #",\s*[}\]]"#, options: .regularExpression) != nil
}
