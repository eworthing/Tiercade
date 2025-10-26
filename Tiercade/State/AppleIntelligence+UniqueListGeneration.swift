import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

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
            // INVARIANT: Reset per-attempt flags to preserve telemetry accuracy (see 1c5d26b).
            // This flag is scoped per attempt; handleAttemptFailure may set it to true during
            // session recreation, but it must start false each iteration for accurate reporting.
            retryState.sessionRecreated = false

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
