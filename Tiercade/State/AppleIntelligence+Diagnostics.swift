import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Model Output Diagnostics
//
// This file contains diagnostic tests to understand exactly what the on-device
// model is generating and why @Generable decoding might be failing.
//
// Tests:
// 1. Raw output (no schema) - capture what model actually generates
// 2. @Generable with varying token limits - find the breaking point
// 3. @Generable with varying item counts - understand scaling behavior
// 4. Manual JSON parsing - verify if output is valid JSON but schema mismatch

#if canImport(FoundationModels) && DEBUG
@available(iOS 26.0, macOS 26.0, *)
@MainActor
internal struct ModelDiagnostics {
    private let logger: (String) -> Void

    internal init(logger: @escaping (String) -> Void = { print($0) }) {
        self.logger = logger
    }

    /// Run comprehensive diagnostics
    internal func runAll() async -> DiagnosticReport {
        logger("🔬 ========================================")
        logger("🔬 MODEL OUTPUT DIAGNOSTICS")
        logger("🔬 ========================================")
        logger("")

        internal var results: [DiagnosticResult] = []

        // Test 1: Raw output (no schema constraint)
        results.append(await testRawOutput(itemCount: 10, tokens: 112))
        results.append(await testRawOutput(itemCount: 40, tokens: 280))
        results.append(await testRawOutput(itemCount: 80, tokens: 560))

        // Test 2: @Generable with increased token limits
        results.append(await testGenerableWithTokens(itemCount: 40, tokensPerItem: 7, seed: 42))
        results.append(await testGenerableWithTokens(itemCount: 40, tokensPerItem: 10, seed: 42))
        results.append(await testGenerableWithTokens(itemCount: 40, tokensPerItem: 15, seed: 42))

        // Test 2b: Same test but with seed 123 (the coordinator's seed)
        results.append(await testGenerableWithTokens(itemCount: 40, tokensPerItem: 7, seed: 123))

        // Test 3: Find breaking point (binary search style)
        results.append(await testGenerableWithTokens(itemCount: 20, tokensPerItem: 7))
        results.append(await testGenerableWithTokens(itemCount: 30, tokensPerItem: 7))

        // Test 4: CRITICAL - Replicate exact acceptance test flow
        results.append(await testViaCoordinator(itemCount: 25))

        internal let report = DiagnosticReport(
            timestamp: Date(),
            results: results,
            environment: RunEnv()
        )

        logger("")
        logger("🔬 ========================================")
        logger("🔬 DIAGNOSTICS COMPLETE")
        logger("🔬 ========================================")
        logger("🔬 Total tests: \(results.count)")
        logger("🔬 Successful: \(results.filter { $0.success }.count)")
        logger("🔬 Failed: \(results.filter { !$0.success }.count)")
        logger("")

        return report
    }

    // MARK: - Test 1: Raw Output (No Schema)

    private func testRawOutput(itemCount: Int, tokens: Int) async -> DiagnosticResult {
        logger("🔬 [Test] Raw output - \(itemCount) items, \(tokens) tokens")

        do {
            guard let session = try? await createTestSession() else {
                return buildFailureResult(
                    testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
                    message: "Failed to create session"
                )
            }

            internal let prompt = buildRawOutputPrompt(itemCount: itemCount)
            internal let options = buildGenerationOptions(tokens: tokens)
            logPromptAndOptions(prompt: prompt, tokens: tokens)

            internal let start = Date()
            internal let response = try await session.respond(to: Prompt(prompt), options: options)
            internal let elapsed = Date().timeIntervalSince(start)
            internal let rawText = response.content

            logResponseMetrics(rawText: rawText, elapsed: elapsed)

            internal let (parseSuccess, itemsParsed) = attemptManualJSONParse(rawText: rawText)

            return buildSuccessResult(
                testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
                rawText: rawText,
                elapsed: elapsed,
                parseSuccess: parseSuccess,
                itemsParsed: itemsParsed
            )

        } catch {
            logger("  ❌ Error: \(error)")
            return buildFailureResult(
                testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
                message: "Exception: \(error.localizedDescription)"
            )
        }
    }

    private func buildRawOutputPrompt(itemCount: Int) -> String {
        """
        Return ONLY a JSON object matching the schema.
        Task: famous scientists throughout history. Produce \(itemCount) distinct items.
        """
    }

    private func buildGenerationOptions(tokens: Int) -> GenerationOptions {
        GenerationOptions(
            sampling: .random(probabilityThreshold: 0.92, seed: 42),
            temperature: 0.8,
            maximumResponseTokens: tokens
        )
    }

    private func logPromptAndOptions(prompt: String, tokens: Int) {
        logger("  📝 Prompt: \(prompt.count) chars")
        logger("  🎛️  Options: maxTokens=\(tokens), temp=0.8, seed=42")
    }

    private func logResponseMetrics(rawText: String, elapsed: TimeInterval) {
        logger("  ✓ Got response in \(String(format: "%.2f", elapsed))s")
        logger("  📏 Response length: \(rawText.count) chars")
        logger("  📄 First 500 chars:")
        logger("  ---")
        logger(String(rawText.prefix(500)))
        logger("  ---")
        logger("  📄 Last 200 chars:")
        logger("  ---")
        logger(String(rawText.suffix(200)))
        logger("  ---")
    }

    private func attemptManualJSONParse(rawText: String) -> (success: Bool, itemsParsed: Int) {
        internal var parseSuccess = false
        internal var itemsParsed = 0

        if let data = rawText.data(using: .utf8) {
            do {
                internal let json = try JSONDecoder().decode(UniqueListResponse.self, from: data)
                itemsParsed = json.items.count
                parseSuccess = true
                logger("  ✓ Manual JSON parse succeeded: \(itemsParsed) items")
            } catch {
                logger("  ❌ Manual JSON parse failed: \(error.localizedDescription)")
            }
        }

        return (parseSuccess, itemsParsed)
    }

    private func buildSuccessResult(
        testName: String,
        rawText: String,
        elapsed: TimeInterval,
        parseSuccess: Bool,
        itemsParsed: Int
    ) -> DiagnosticResult {
        DiagnosticResult(
            testName: testName,
            success: true,
            message: "Response captured. ParseSuccess=\(parseSuccess), Items=\(itemsParsed)",
            rawOutput: rawText,
            details: [
                "responseLength": "\(rawText.count)",
                "elapsedSeconds": "\(String(format: "%.2f", elapsed))",
                "manualParseSuccess": "\(parseSuccess)",
                "itemsParsed": "\(itemsParsed)"
            ]
        )
    }

    private func buildFailureResult(testName: String, message: String) -> DiagnosticResult {
        DiagnosticResult(
            testName: testName,
            success: false,
            message: message,
            rawOutput: nil,
            details: [:]
        )
    }

    // MARK: - Test 2: @Generable with Token Variations

    private func testGenerableWithTokens(
        itemCount: Int,
        tokensPerItem: Int,
        seed: UInt64 = 42
    ) async -> DiagnosticResult {
        internal let maxTokens = itemCount * tokensPerItem
        internal let testName = "Generable_\(itemCount)items_\(tokensPerItem)tpi_seed\(seed)"
        logger(
            "🔬 [Test] @Generable - \(itemCount) items, \(tokensPerItem) tokens/item = \(maxTokens) total, seed=\(seed)"
        )

        do {
            guard let session = try? await createTestSession() else {
                return buildGenerableFailureResult(testName: testName, message: "Failed to create session", seed: seed)
            }

            internal let prompt = buildRawOutputPrompt(itemCount: itemCount)
            internal let options = buildGenerableOptions(seed: seed, maxTokens: maxTokens)
            logGenerableOptions(prompt: prompt, options: options)

            internal let start = Date()
            internal let response = try await session.respond(
                to: Prompt(prompt),
                generating: UniqueListResponse.self,
                includeSchemaInPrompt: true,
                options: options
            )
            internal let elapsed = Date().timeIntervalSince(start)
            internal let items = response.content.items

            logGenerableSuccess(items: items, elapsed: elapsed)

            return buildGenerableSuccessResult(context: GenerableSuccessContext(
                testName: testName,
                items: items,
                elapsed: elapsed,
                tokensPerItem: tokensPerItem,
                maxTokens: maxTokens,
                seed: seed
            ))

        } catch let e as LanguageModelSession.GenerationError {
            return handleGenerationError(
                error: e,
                testName: testName,
                tokensPerItem: tokensPerItem,
                maxTokens: maxTokens,
                seed: seed
            )
        } catch {
            logger("  ❌ Unexpected error: \(error)")
            return buildGenerableFailureResult(
                testName: testName,
                message: "Unexpected error: \(error.localizedDescription)",
                seed: seed
            )
        }
    }

    private func buildGenerableOptions(seed: UInt64, maxTokens: Int) -> GenerationOptions {
        GenerationOptions(
            sampling: .random(probabilityThreshold: 0.92, seed: seed),
            temperature: 0.8,
            maximumResponseTokens: maxTokens
        )
    }

    private func logGenerableOptions(prompt: String, options: GenerationOptions) {
        logger("  📝 Prompt: \(prompt.count) chars")
        logger("  🔍 Full prompt: \"\(prompt)\"")
        logger("  🔍 Options.maximumResponseTokens: \(String(describing: options.maximumResponseTokens))")
        logger("  🔍 Options.temperature: \(String(describing: options.temperature))")
        logger("  🔍 Options.sampling: \(String(describing: options.sampling))")
    }

    private func logGenerableSuccess(items: [String], elapsed: TimeInterval) {
        logger("  ✓ @Generable succeeded in \(String(format: "%.2f", elapsed))s")
        logger("  📦 Received \(items.count) items")
        logger("  📄 First 3 items: \(items.prefix(3).joined(separator: ", "))")
    }

    private struct GenerableSuccessContext: Sendable {
        internal let testName: String
        internal let items: [String]
        internal let elapsed: TimeInterval
        internal let tokensPerItem: Int
        internal let maxTokens: Int
        internal let seed: UInt64
    }

    private func buildGenerableSuccessResult(context: GenerableSuccessContext) -> DiagnosticResult {
        DiagnosticResult(
            testName: context.testName,
            success: true,
            message: "@Generable succeeded with \(context.items.count) items",
            rawOutput: nil,
            details: [
                "itemsReceived": "\(context.items.count)",
                "elapsedSeconds": "\(String(format: "%.2f", context.elapsed))",
                "tokensPerItem": "\(context.tokensPerItem)",
                "maxTokens": "\(context.maxTokens)",
                "seed": "\(context.seed)"
            ]
        )
    }

    private func handleGenerationError(
        error: LanguageModelSession.GenerationError,
        testName: String,
        tokensPerItem: Int,
        maxTokens: Int,
        seed: UInt64
    ) -> DiagnosticResult {
        logger("  ❌ @Generable failed: \(error)")

        internal var errorType = "unknown"
        internal var contextInfo = ""
        if case .decodingFailure(let context) = error {
            errorType = "decodingFailure"
            contextInfo = context.debugDescription
            logger("  📋 Context: \(contextInfo)")
        }

        return DiagnosticResult(
            testName: testName,
            success: false,
            message: "GenerationError: \(errorType)",
            rawOutput: nil,
            details: [
                "errorType": errorType,
                "errorDescription": error.localizedDescription,
                "contextInfo": contextInfo,
                "tokensPerItem": "\(tokensPerItem)",
                "maxTokens": "\(maxTokens)",
                "seed": "\(seed)"
            ]
        )
    }

    private func buildGenerableFailureResult(testName: String, message: String, seed: UInt64) -> DiagnosticResult {
        DiagnosticResult(
            testName: testName,
            success: false,
            message: message,
            rawOutput: nil,
            details: ["seed": "\(seed)"]
        )
    }

    // MARK: - Test 3: Via Coordinator (Exact Acceptance Test Path)

    private func testViaCoordinator(itemCount: Int) async -> DiagnosticResult {
        internal let testName = "Coordinator_\(itemCount)items"
        logger("🔬 [Test] Via UniqueListCoordinator - \(itemCount) items (EXACT acceptance test path)")

        do {
            guard let session = try? await createTestSession() else {
                return buildCoordinatorFailureResult(testName: testName, message: "Failed to create session")
            }

            internal let coordinator = setupCoordinator(session: session)

            internal let start = Date()
            internal let items = try await runCoordinatorTest(coordinator: coordinator, itemCount: itemCount)
            internal let elapsed = Date().timeIntervalSince(start)

            logCoordinatorSuccess(items: items, elapsed: elapsed)

            internal let (uniqueKeys, allUnique) = checkUniqueness(items: items)

            return buildCoordinatorSuccessResult(
                testName: testName,
                items: items,
                uniqueKeys: uniqueKeys,
                allUnique: allUnique,
                elapsed: elapsed
            )

        } catch let e as LanguageModelSession.GenerationError {
            return handleCoordinatorGenerationError(error: e, testName: testName)
        } catch {
            logger("  ❌ Unexpected error: \(error)")
            return buildCoordinatorFailureResult(
                testName: testName,
                message: "Unexpected error: \(error.localizedDescription)"
            )
        }
    }

    private func setupCoordinator(session: LanguageModelSession) -> UniqueListCoordinator {
        logger("  📝 Creating FMClient and UniqueListCoordinator...")
        internal let fm = FMClient(session: session, logger: logger)
        return UniqueListCoordinator(fm: fm, logger: logger)
    }

    private func runCoordinatorTest(coordinator: UniqueListCoordinator, itemCount: Int) async throws -> [String] {
        logger("  🎯 Calling coordinator.uniqueList(query:targetCount:seed:)...")
        return try await coordinator.uniqueList(
            query: "famous scientists throughout history",
            targetCount: itemCount,
            seed: 123
        )
    }

    private func logCoordinatorSuccess(items: [String], elapsed: TimeInterval) {
        logger("  ✓ Coordinator succeeded in \(String(format: "%.2f", elapsed))s")
        logger("  📦 Received \(items.count) items")
        logger("  📄 First 3 items: \(items.prefix(3).joined(separator: ", "))")
    }

    private func checkUniqueness(items: [String]) -> (uniqueKeys: Set<String>, allUnique: Bool) {
        internal let normKeys = items.map { $0.normKey }
        internal let uniqueKeys = Set(normKeys)
        internal let allUnique = normKeys.count == uniqueKeys.count
        return (uniqueKeys, allUnique)
    }

    private func buildCoordinatorSuccessResult(
        testName: String,
        items: [String],
        uniqueKeys: Set<String>,
        allUnique: Bool,
        elapsed: TimeInterval
    ) -> DiagnosticResult {
        DiagnosticResult(
            testName: testName,
            success: true,
            message: "Coordinator succeeded with \(items.count) items, allUnique=\(allUnique)",
            rawOutput: nil,
            details: [
                "itemsReceived": "\(items.count)",
                "uniqueCount": "\(uniqueKeys.count)",
                "allUnique": "\(allUnique)",
                "elapsedSeconds": "\(String(format: "%.2f", elapsed))"
            ]
        )
    }

    private func handleCoordinatorGenerationError(
        error: LanguageModelSession.GenerationError,
        testName: String
    ) -> DiagnosticResult {
        logger("  ❌ Coordinator failed with GenerationError: \(error)")

        internal var errorType = "unknown"
        internal var contextInfo = ""
        if case .decodingFailure(let context) = error {
            errorType = "decodingFailure"
            contextInfo = context.debugDescription
            logger("  📋 Context: \(contextInfo)")
        }

        return DiagnosticResult(
            testName: testName,
            success: false,
            message: "GenerationError: \(errorType)",
            rawOutput: nil,
            details: [
                "errorType": errorType,
                "errorDescription": error.localizedDescription,
                "contextInfo": contextInfo
            ]
        )
    }

    private func buildCoordinatorFailureResult(testName: String, message: String) -> DiagnosticResult {
        DiagnosticResult(
            testName: testName,
            success: false,
            message: message,
            rawOutput: nil,
            details: [:]
        )
    }

    // MARK: - Helper

    private func createTestSession() async throws -> LanguageModelSession {
        internal let instructions = Instructions("""
        You are a helpful assistant that generates lists.
        Always return valid JSON matching the requested schema.
        Ensure items are distinct and diverse.
        """)

        return LanguageModelSession(
            model: .default,
            tools: [],
            instructions: instructions
        )
    }
}

// MARK: - Diagnostic Data Structures

@available(iOS 26.0, macOS 26.0, *)
internal struct DiagnosticResult: Codable {
    internal let testName: String
    internal let success: Bool
    internal let message: String
    internal let rawOutput: String?
    internal let details: [String: String]
}

@available(iOS 26.0, macOS 26.0, *)
internal struct DiagnosticReport: Codable {
    internal let timestamp: Date
    internal let results: [DiagnosticResult]
    internal let environment: RunEnv
}

#endif
