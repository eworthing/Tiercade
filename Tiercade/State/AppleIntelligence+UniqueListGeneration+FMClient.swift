import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - FMClient Helper Methods

@available(iOS 26.0, macOS 26.0, *)
extension FMClient {
    internal func initializeRetryState(params: GenerateParameters) -> RetryState {
        return RetryState(
            options: params.profile.options(
                seed: params.initialSeed,
                temp: params.temperature,
                maxTok: params.maxTokens
            ),
            seed: params.initialSeed,
            lastError: nil
        )
    }

    internal func handleUnexpectedError(_ error: Error) throws -> Never {
        logger("❌ [DEBUG] Unexpected error type: \(type(of: error))")
        logger("❌ [DEBUG] Error: \(error)")
        throw error
    }

    internal func buildRetryExhaustedError(lastError: Error?) -> Error {
        return lastError ?? NSError(domain: "FMClient", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "All retries failed"
        ])
    }

    internal func handleSuccessResponse(
        context: FMClient.ResponseContext,
        telemetry: inout [AttemptMetrics]
    ) {
        logSuccessfulGeneration(
            response: context.response,
            attempt: context.attempt,
            totalElapsed: Date().timeIntervalSince(context.totalStart),
            params: context.params
        )

        recordSuccessfulAttempt(
            context: FMClient.AttemptContext(
                attempt: context.attempt,
                seed: context.currentSeed,
                profile: context.params.profile,
                options: context.params.profile.options(
                    seed: context.currentSeed,
                    temp: context.params.temperature,
                    maxTok: context.params.maxTokens
                ),
                sessionRecreated: context.sessionRecreated,
                elapsed: Date().timeIntervalSince(context.attemptStart)
            ),
            itemsReturned: context.response.content.items.count,
            telemetry: &telemetry
        )
    }

    // swiftlint:disable:next function_parameter_count - Grouped: error + context + retry + telemetry
    internal func handleAttemptFailure(
        error: LanguageModelSession.GenerationError,
        attempt: Int,
        attemptStart: Date,
        params: GenerateParameters,
        retryState: inout RetryState,
        telemetry: inout [AttemptMetrics]
    ) async throws -> Bool {
        let attemptElapsed = Date().timeIntervalSince(attemptStart)

        recordFailedAttempt(
            context: FMClient.AttemptContext(
                attempt: attempt,
                seed: retryState.seed,
                profile: params.profile,
                options: retryState.options,
                sessionRecreated: retryState.sessionRecreated,
                elapsed: attemptElapsed
            ),
            telemetry: &telemetry
        )

        return try await handleGenerationError(
            error: error,
            attempt: attempt,
            params: params,
            retryState: &retryState
        )
    }

    internal func logGenerationStart(params: GenerateParameters) {
        logger("🔍 [DEBUG] Starting generation (maxRetries=\(params.maxRetries))...")
        logger("🔍 [DEBUG] Prompt length: \(params.prompt.count) chars")
        logger("🔍 [DEBUG] Full prompt: \"\(params.prompt)\"")
    }

    internal func logAttemptDetails(attempt: Int, maxRetries: Int, options: GenerationOptions) {
        logger("🔍 [DEBUG] Attempt \(attempt + 1)/\(maxRetries)")
        logger("🔍 [DEBUG] Options.maximumResponseTokens: \(String(describing: options.maximumResponseTokens))")
        logger("🔍 [DEBUG] Options.temperature: \(String(describing: options.temperature))")
        logger("🔍 [DEBUG] Options.sampling: \(String(describing: options.sampling))")
        logger("🔍 [DEBUG] Schema: UniqueListResponse (includeSchemaInPrompt=true)")
    }

    internal func executeGuidedGeneration(
        prompt: String,
        options: GenerationOptions
    ) async throws -> LanguageModelSession.Response<UniqueListResponse> {
        return try await session.respond(
            to: Prompt(prompt),
            generating: UniqueListResponse.self,
            includeSchemaInPrompt: true,
            options: options
        )
    }

    internal func logSuccessfulGeneration(
        response: LanguageModelSession.Response<UniqueListResponse>,
        attempt: Int,
        totalElapsed: Double,
        params: GenerateParameters
    ) {
        let ips = Double(response.content.items.count) / max(0.001, totalElapsed)

        if response.content.items.isEmpty {
            logger("⚠️ [CRITICAL] Schema parsing succeeded but returned EMPTY ARRAY")
            logger("⚠️ [CRITICAL] This means the model generated { \"items\": [] } - not a parsing error")
            logger("⚠️ [CRITICAL] Prompt was: \"\(params.prompt.prefix(200))...\"")
        }

        let attemptSuffix = attempt > 0 ? " [succeeded on attempt \(attempt + 1)]" : ""
        logger(
            "✓ Generated \(response.content.items.count) items in " +
            "\(String(format: "%.2f", totalElapsed))s " +
            "(\(String(format: "%.1f", ips)) items/sec)\(attemptSuffix)"
        )

        logger("🔍 [DEBUG] First item: \(response.content.items.first ?? "none")")
        logger("🔍 [DEBUG] Last item: \(response.content.items.last ?? "none")")
        logger("🔍 [DEBUG] Item count breakdown: total=\(response.content.items.count)")
    }

    internal func recordSuccessfulAttempt(
        context: FMClient.AttemptContext,
        itemsReturned: Int,
        telemetry: inout [AttemptMetrics]
    ) {
        telemetry.append(AttemptMetrics(
            attemptIndex: context.attempt,
            seed: context.seed,
            sampling: context.profile.description,
            temperature: context.options.temperature,
            sessionRecreated: context.sessionRecreated,
            itemsReturned: itemsReturned,
            elapsedSec: context.elapsed
        ))
    }

    internal func recordFailedAttempt(
        context: FMClient.AttemptContext,
        telemetry: inout [AttemptMetrics]
    ) {
        telemetry.append(AttemptMetrics(
            attemptIndex: context.attempt,
            seed: context.seed,
            sampling: context.profile.description,
            temperature: context.options.temperature,
            sessionRecreated: context.sessionRecreated,
            itemsReturned: nil,
            elapsedSec: context.elapsed
        ))
    }

    internal func handleGenerationError(
        error: LanguageModelSession.GenerationError,
        attempt: Int,
        params: GenerateParameters,
        retryState: inout RetryState
    ) async throws -> Bool {
        if case .decodingFailure(let context) = error {
            if attempt < params.maxRetries - 1 {
                logger("⚠️ [Attempt \(attempt + 1)] decodingFailure: \(context.debugDescription)")

                if try await handleAdaptiveRetry(
                    attempt: attempt,
                    params: params,
                    retryState: &retryState
                ) {
                    return true
                }

                return true
            } else {
                logger("❌ [Attempt \(attempt + 1)] decodingFailure: \(context.debugDescription)")
                logger("❌ Max retries exhausted, failing")
            }
        } else if case .exceededContextWindowSize(let details) = error {
            logger("❌ Context window overflow: \(details)")
            throw error
        } else {
            logger("❌ [DEBUG] GenerationError: \(error)")
            throw error
        }

        return false
    }

    internal func handleAdaptiveRetry(
        attempt: Int,
        params: GenerateParameters,
        retryState: inout RetryState
    ) async throws -> Bool {
        // ADAPTIVE RETRY: Boost tokens before seed rotation on first failure
        if attempt == 0 {
            let currentMax = retryState.options.maximumResponseTokens ?? 0
            let boosted = min(512, Int(Double(currentMax) * 1.8))
            if boosted > currentMax {
                logger("🔁 Boosting maxTokens → \(boosted) with same seed/profile")
                retryState.options = params.profile.options(
                    seed: retryState.seed,
                    temp: retryState.options.temperature,
                    maxTok: boosted
                )
                let seedStr = retryState.seed.map { String($0) } ?? "nil"
                logger("🔁 Retrying with seed=\(seedStr), profile=\(params.profile.description)")
                return true
            }
        }

        // Session hygiene: create fresh session after first failure
        if attempt == 1, let factory = sessionFactory {
            do {
                session = try await factory()
                retryState.sessionRecreated = true
                logger("♻️ Recreating session")
            } catch {
                logger("⚠️ Failed to create fresh session: \(error)")
            }
        }

        // Use deterministic seed ring for reproducible retries
        let newSeed = Self.seedRing[(attempt + 1) % Self.seedRing.count]
        retryState.seed = newSeed

        // Lower temperature after 2 failures
        let temp = attempt >= 2 ? 0.7 : params.temperature
        retryState.options = params.profile.options(seed: retryState.seed, temp: temp, maxTok: params.maxTokens)

        logger("🔁 Retrying with seed=\(newSeed), profile=\(params.profile.description)")
        return false
    }

    // MARK: - Unguided Generation Helpers

    // swiftlint:disable:next function_parameter_count - Grouped: response + context + params + telemetry
    internal func handleUnguidedResponse(
        response: LanguageModelSession.Response<String>,
        attempt: Int,
        attemptStart: Date,
        totalStart: Date,
        params: GenerateTextArrayParameters,
        options: GenerationOptions,
        sessionRecreated: Bool,
        telemetry: inout [AttemptMetrics]
    ) throws -> [String]? {
        let attemptElapsed = Date().timeIntervalSince(attemptStart)
        let debugDir = prepareDebugDirectory()

        saveUnguidedDebugData(
            response: response,
            attempt: attempt,
            params: params,
            options: options,
            elapsed: attemptElapsed,
            debugDir: debugDir
        )

        if let arr = parseJSONArray(response.content) {
            logSuccessfulParse(arr: arr, elapsed: Date().timeIntervalSince(totalStart))
            saveParseSuccessDebug(arr: arr, debugDir: debugDir)

            recordUnguidedSuccess(
                context: FMClient.UnguidedAttemptContext(
                    attempt: attempt,
                    params: params,
                    options: options,
                    sessionRecreated: sessionRecreated,
                    elapsed: attemptElapsed
                ),
                itemCount: arr.count,
                telemetry: &telemetry
            )

            return arr
        }

        try handleParseFailure(response: response, debugDir: debugDir)
        return nil
    }

    // swiftlint:disable:next function_parameter_count - Grouped: error + context + params + retry + telemetry
    internal func handleUnguidedError(
        error: Error,
        attempt: Int,
        attemptStart: Date,
        params: GenerateTextArrayParameters,
        options: GenerationOptions,
        currentOptions: inout GenerationOptions,
        sessionRecreated: inout Bool,
        telemetry: inout [AttemptMetrics]
    ) async -> Bool {
        let attemptElapsed = Date().timeIntervalSince(attemptStart)

        logUnguidedFailure(error: error, elapsed: attemptElapsed)

        recordUnguidedFailure(
            context: FMClient.UnguidedAttemptContext(
                attempt: attempt,
                params: params,
                options: options,
                sessionRecreated: sessionRecreated,
                elapsed: attemptElapsed
            ),
            telemetry: &telemetry
        )

        return await handleUnguidedRetry(
            attempt: attempt,
            params: params,
            currentOptions: &currentOptions,
            sessionRecreated: &sessionRecreated
        )
    }

    internal func prepareDebugDirectory() -> URL {
        let fileManager = FileManager.default
        let debugDir = fileManager.temporaryDirectory.appendingPathComponent(
            "unguided_debug",
            isDirectory: true
        )
        do {
            try fileManager.createDirectory(at: debugDir, withIntermediateDirectories: true)
        } catch {
            logger("⚠️ Failed to prepare debug directory: \(error)")
        }
        return debugDir
    }

    // swiftlint:disable:next function_parameter_count - Grouped: response + context + params + debug
    internal func saveUnguidedDebugData(
        response: LanguageModelSession.Response<String>,
        attempt: Int,
        params: GenerateTextArrayParameters,
        options: GenerationOptions,
        elapsed: Double,
        debugDir: URL
    ) {
        let preview = String(response.content.prefix(200))
        logger("🔍 [DEBUG] Unguided response preview: \(preview)")

        let debugFile = debugDir.appendingPathComponent("unguided_\(Date().timeIntervalSince1970).json")
        let debugData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "attempt": attempt,
            "seed": params.initialSeed ?? 0,
            "temperature": options.temperature,
            "maxTokens": options.maximumResponseTokens ?? 0,
            "promptLength": params.prompt.count,
            "responseLength": response.content.count,
            "elapsedSec": elapsed,
            "promptSnippet": String(params.prompt.prefix(200)),
            "fullResponse": response.content
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: debugData, options: .prettyPrinted)
            try jsonData.write(to: debugFile, options: .atomic)
            logger("📝 Debug data saved to: \(debugFile.path)")
        } catch {
            logger("⚠️ Failed to save debug data: \(error)")
        }
    }

    internal func logSuccessfulParse(arr: [String], elapsed: Double) {
        logger("✓ Parsed \(arr.count) items from text in \(String(format: "%.2f", elapsed))s")
    }

    internal func saveParseSuccessDebug(arr: [String], debugDir: URL) {
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
    }

    internal func handleParseFailure(response: LanguageModelSession.Response<String>, debugDir: URL) throws {
        logger("⚠️ Parse failed. Full response (\(response.content.count) chars): \(response.content)")

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
    }

    internal func recordUnguidedSuccess(
        context: FMClient.UnguidedAttemptContext,
        itemCount: Int,
        telemetry: inout [AttemptMetrics]
    ) {
        telemetry.append(AttemptMetrics(
            attemptIndex: context.attempt,
            seed: context.params.initialSeed,
            sampling: "unguided:\(context.params.profile.description)",
            temperature: context.options.temperature,
            sessionRecreated: context.sessionRecreated,
            itemsReturned: itemCount,
            elapsedSec: context.elapsed
        ))
    }

    internal func logUnguidedFailure(error: Error, elapsed: Double) {
        logger(
            "❌ [DEBUG] Unguided generation failed after " +
            "\(String(format: "%.2f", elapsed))s: \(error)"
        )
    }

    internal func recordUnguidedFailure(
        context: FMClient.UnguidedAttemptContext,
        telemetry: inout [AttemptMetrics]
    ) {
        telemetry.append(AttemptMetrics(
            attemptIndex: context.attempt,
            seed: context.params.initialSeed,
            sampling: "unguided:\(context.params.profile.description)",
            temperature: context.options.temperature,
            sessionRecreated: context.sessionRecreated,
            itemsReturned: 0,
            elapsedSec: context.elapsed
        ))
    }

    internal func handleUnguidedRetry(
        attempt: Int,
        params: GenerateTextArrayParameters,
        currentOptions: inout GenerationOptions,
        sessionRecreated: inout Bool
    ) async -> Bool {
        // Adaptive boost on first failure
        if attempt == 0 {
            let currentMax = currentOptions.maximumResponseTokens ?? 256
            let boosted = min(512, Int(Double(currentMax) * 1.8))
            if boosted > currentMax {
                logger("🔁 Boosting maxTokens → \(boosted) for unguided parse retry")
                currentOptions = params.profile.options(
                    seed: params.initialSeed,
                    temp: max(0.0, (params.temperature ?? 0.7) * 0.9),
                    maxTok: boosted
                )
                return true
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

        return false
    }

    /// Tolerant JSON array parser - extracts first [...] and parses strings or objects with "name" field.
    /// Handles both ["item1", "item2"] and [{"name": "item1"}, {"name": "item2"}] formats.
    /// Strips markdown code fences (```json ... ```) before parsing.
    /// Falls back to regex extraction of quoted strings even when array is truncated.
    internal func parseJSONArray(_ text: String) -> [String]? {
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
