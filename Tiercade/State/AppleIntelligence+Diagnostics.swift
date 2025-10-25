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
struct ModelDiagnostics {
    private let logger: (String) -> Void

    init(logger: @escaping (String) -> Void = { print($0) }) {
        self.logger = logger
    }

    /// Run comprehensive diagnostics
    func runAll() async -> DiagnosticReport {
        logger("🔬 ========================================")
        logger("🔬 MODEL OUTPUT DIAGNOSTICS")
        logger("🔬 ========================================")
        logger("")

        var results: [DiagnosticResult] = []

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

        let report = DiagnosticReport(
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
                return DiagnosticResult(
                    testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
                    success: false,
                    message: "Failed to create session",
                    rawOutput: nil,
                    details: [:]
                )
            }

            let prompt = """
            Return ONLY a JSON object matching the schema.
            Task: famous scientists throughout history. Produce \(itemCount) distinct items.
            """

            let options = GenerationOptions(
                sampling: .random(probabilityThreshold: 0.92, seed: 42),
                temperature: 0.8,
                maximumResponseTokens: tokens
            )

            logger("  📝 Prompt: \(prompt.count) chars")
            logger("  🎛️  Options: maxTokens=\(tokens), temp=0.8, seed=42")

            let start = Date()

            // Use raw respond() to get the actual text output
            let response = try await session.respond(
                to: Prompt(prompt),
                options: options
            )

            let elapsed = Date().timeIntervalSince(start)
            let rawText = response.content

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

            // Try to parse as JSON manually
            var parseSuccess = false
            var itemsParsed = 0

            if let data = rawText.data(using: .utf8) {
                do {
                    let json = try JSONDecoder().decode(UniqueListResponse.self, from: data)
                    itemsParsed = json.items.count
                    parseSuccess = true
                    logger("  ✓ Manual JSON parse succeeded: \(itemsParsed) items")
                } catch {
                    logger("  ❌ Manual JSON parse failed: \(error.localizedDescription)")
                }
            }

            return DiagnosticResult(
                testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
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

        } catch {
            logger("  ❌ Error: \(error)")
            return DiagnosticResult(
                testName: "RawOutput_\(itemCount)items_\(tokens)tokens",
                success: false,
                message: "Exception: \(error.localizedDescription)",
                rawOutput: nil,
                details: [:]
            )
        }
    }

    // MARK: - Test 2: @Generable with Token Variations

    private func testGenerableWithTokens(itemCount: Int, tokensPerItem: Int, seed: UInt64 = 42) async -> DiagnosticResult {
        let maxTokens = itemCount * tokensPerItem
        logger("🔬 [Test] @Generable - \(itemCount) items, \(tokensPerItem) tokens/item = \(maxTokens) total, seed=\(seed)")

        do {
            guard let session = try? await createTestSession() else {
                return DiagnosticResult(
                    testName: "Generable_\(itemCount)items_\(tokensPerItem)tpi_seed\(seed)",
                    success: false,
                    message: "Failed to create session",
                    rawOutput: nil,
                    details: [:]
                )
            }

            let prompt = """
            Return ONLY a JSON object matching the schema.
            Task: famous scientists throughout history. Produce \(itemCount) distinct items.
            """

            let options = GenerationOptions(
                sampling: .random(probabilityThreshold: 0.92, seed: seed),
                temperature: 0.8,
                maximumResponseTokens: maxTokens
            )

            logger("  📝 Prompt: \(prompt.count) chars")
            logger("  🔍 Full prompt: \"\(prompt)\"")
            logger("  🔍 Options.maximumResponseTokens: \(String(describing: options.maximumResponseTokens))")
            logger("  🔍 Options.temperature: \(String(describing: options.temperature))")
            logger("  🔍 Options.sampling: \(String(describing: options.sampling))")

            let start = Date()

            // Use @Generable guided generation
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: UniqueListResponse.self,
                includeSchemaInPrompt: true,
                options: options
            )

            let elapsed = Date().timeIntervalSince(start)
            let items = response.content.items

            logger("  ✓ @Generable succeeded in \(String(format: "%.2f", elapsed))s")
            logger("  📦 Received \(items.count) items")
            logger("  📄 First 3 items: \(items.prefix(3).joined(separator: ", "))")

            return DiagnosticResult(
                testName: "Generable_\(itemCount)items_\(tokensPerItem)tpi_seed\(seed)",
                success: true,
                message: "@Generable succeeded with \(items.count) items",
                rawOutput: nil,
                details: [
                    "itemsReceived": "\(items.count)",
                    "elapsedSeconds": "\(String(format: "%.2f", elapsed))",
                    "tokensPerItem": "\(tokensPerItem)",
                    "maxTokens": "\(maxTokens)",
                    "seed": "\(seed)"
                ]
            )

        } catch let e as LanguageModelSession.GenerationError {
            logger("  ❌ @Generable failed: \(e)")

            // Check specific error type
            var errorType = "unknown"
            var contextInfo = ""
            if case .decodingFailure(let context) = e {
                errorType = "decodingFailure"
                contextInfo = context.debugDescription
                logger("  📋 Context: \(contextInfo)")
            }

            return DiagnosticResult(
                testName: "Generable_\(itemCount)items_\(tokensPerItem)tpi_seed\(seed)",
                success: false,
                message: "GenerationError: \(errorType)",
                rawOutput: nil,
                details: [
                    "errorType": errorType,
                    "errorDescription": e.localizedDescription,
                    "contextInfo": contextInfo,
                    "tokensPerItem": "\(tokensPerItem)",
                    "maxTokens": "\(maxTokens)",
                    "seed": "\(seed)"
                ]
            )
        } catch {
            logger("  ❌ Unexpected error: \(error)")
            return DiagnosticResult(
                testName: "Generable_\(itemCount)items_\(tokensPerItem)tpi_seed\(seed)",
                success: false,
                message: "Unexpected error: \(error.localizedDescription)",
                rawOutput: nil,
                details: ["seed": "\(seed)"]
            )
        }
    }

    // MARK: - Test 3: Via Coordinator (Exact Acceptance Test Path)

    private func testViaCoordinator(itemCount: Int) async -> DiagnosticResult {
        logger("🔬 [Test] Via UniqueListCoordinator - \(itemCount) items (EXACT acceptance test path)")

        do {
            guard let session = try? await createTestSession() else {
                return DiagnosticResult(
                    testName: "Coordinator_\(itemCount)items",
                    success: false,
                    message: "Failed to create session",
                    rawOutput: nil,
                    details: [:]
                )
            }

            logger("  📝 Creating FMClient and UniqueListCoordinator...")

            let fm = FMClient(session: session, logger: logger)
            let coordinator = UniqueListCoordinator(fm: fm, logger: logger)

            logger("  🎯 Calling coordinator.uniqueList(query:N:seed:)...")
            let start = Date()

            let items = try await coordinator.uniqueList(
                query: "famous scientists throughout history",
                N: itemCount,
                seed: 123
            )

            let elapsed = Date().timeIntervalSince(start)

            logger("  ✓ Coordinator succeeded in \(String(format: "%.2f", elapsed))s")
            logger("  📦 Received \(items.count) items")
            logger("  📄 First 3 items: \(items.prefix(3).joined(separator: ", "))")

            // Check uniqueness
            let normKeys = items.map { $0.normKey }
            let uniqueKeys = Set(normKeys)
            let allUnique = normKeys.count == uniqueKeys.count

            return DiagnosticResult(
                testName: "Coordinator_\(itemCount)items",
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

        } catch let e as LanguageModelSession.GenerationError {
            logger("  ❌ Coordinator failed with GenerationError: \(e)")

            var errorType = "unknown"
            var contextInfo = ""
            if case .decodingFailure(let context) = e {
                errorType = "decodingFailure"
                contextInfo = context.debugDescription
                logger("  📋 Context: \(contextInfo)")
            }

            return DiagnosticResult(
                testName: "Coordinator_\(itemCount)items",
                success: false,
                message: "GenerationError: \(errorType)",
                rawOutput: nil,
                details: [
                    "errorType": errorType,
                    "errorDescription": e.localizedDescription,
                    "contextInfo": contextInfo
                ]
            )
        } catch {
            logger("  ❌ Unexpected error: \(error)")
            return DiagnosticResult(
                testName: "Coordinator_\(itemCount)items",
                success: false,
                message: "Unexpected error: \(error.localizedDescription)",
                rawOutput: nil,
                details: [:]
            )
        }
    }

    // MARK: - Helper

    private func createTestSession() async throws -> LanguageModelSession {
        let instructions = Instructions("""
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
struct DiagnosticResult: Codable {
    let testName: String
    let success: Bool
    let message: String
    let rawOutput: String?
    let details: [String: String]
}

@available(iOS 26.0, macOS 26.0, *)
struct DiagnosticReport: Codable {
    let timestamp: Date
    let results: [DiagnosticResult]
    let environment: RunEnv
}

#endif
