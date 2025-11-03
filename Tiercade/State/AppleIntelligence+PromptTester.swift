import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

@MainActor
internal class SystemPromptTester {
    internal struct TestResult {
        internal let promptNumber: Int
        internal let promptText: String
        internal let hasDuplicates: Bool
        internal let duplicateCount: Int
        internal let uniqueItems: Int
        internal let totalItems: Int
        internal let insufficient: Bool
        internal let wasJsonParsed: Bool
        internal let response: String
        internal let parsedItems: [String]
        internal let normalizedItems: [String]
    }

    internal static func testPrompts(onProgress: @MainActor @escaping (String) -> Void) async -> [TestResult] {
        internal let testQuery = "What are the top 25 most popular animated series"
        internal var results: [TestResult] = []

        logTestHeader(testQuery: testQuery, onProgress: onProgress)

        for (index, prompt) in prompts.enumerated() {
            logPromptStart(index: index, prompt: prompt, onProgress: onProgress)

            internal let result = await testSinglePrompt(
                promptNumber: index + 1,
                systemPrompt: prompt,
                testQuery: testQuery
            )

            results.append(result)
            savePartialResults(results: results)

            internal let status = buildTestStatus(result: result)
            reportTestResult(result: result, status: status, onProgress: onProgress)

            // Short delay between tests
            try? await Task.sleep(for: .seconds(1))
        }

        printTestSummary(results: results, onProgress: onProgress)
        saveCompleteLogs(results: results, onProgress: onProgress)

        return results
    }

    nonisolated private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }

    internal struct TimeoutError: Error, Sendable {}

    private static func testSinglePrompt(
        promptNumber: Int,
        systemPrompt: String,
        testQuery: String
    ) async -> TestResult {
        do {
            internal let responseContent = try await executePromptGeneration(systemPrompt: systemPrompt, testQuery: testQuery)
            print("🧪   ✅ Generation completed successfully")
            internal let analysis = analyzeDuplicates(responseContent)
            return buildSuccessfulTestResult(
                promptNumber: promptNumber,
                systemPrompt: systemPrompt,
                responseContent: responseContent,
                analysis: analysis
            )
        } catch is TimeoutError {
            return buildTimeoutTestResult(promptNumber: promptNumber, systemPrompt: systemPrompt)
        } catch {
            return buildErrorTestResult(promptNumber: promptNumber, systemPrompt: systemPrompt, error: error)
        }
    }

    private static func executePromptGeneration(systemPrompt: String, testQuery: String) async throws -> String {
        internal let instructions = Instructions(systemPrompt)
        internal let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)

        // Explicit generation options for reproducibility and control
        internal let opts = GenerationOptions(
            sampling: .random(top: 50, seed: UInt64.random(in: 0...UInt64.max)),
            temperature: 0.8,
            maximumResponseTokens: 1200
        )

        print("🧪   ⏱️ Starting generation with 60s timeout...")

        // Add timeout to prevent hanging forever
        return try await withTimeout(seconds: 60) {
            try await session.respond(to: Prompt(testQuery), options: opts).content
        }
    }

    private static func buildSuccessfulTestResult(
        promptNumber: Int,
        systemPrompt: String,
        responseContent: String,
        analysis: DuplicateAnalysisResult
    ) -> TestResult {
        TestResult(
            promptNumber: promptNumber,
            promptText: systemPrompt,
            hasDuplicates: analysis.hasDuplicates,
            duplicateCount: analysis.duplicateCount,
            uniqueItems: analysis.uniqueItems,
            totalItems: analysis.totalItems,
            insufficient: analysis.insufficient,
            wasJsonParsed: analysis.wasJsonParsed,
            response: responseContent,
            parsedItems: analysis.parsedItems,
            normalizedItems: analysis.normalizedItems
        )
    }

    private static func buildTimeoutTestResult(promptNumber: Int, systemPrompt: String) -> TestResult {
        print("🧪 ⏱️ TIMEOUT after 60 seconds for prompt #\(promptNumber)")
        return TestResult(
            promptNumber: promptNumber,
            promptText: systemPrompt,
            hasDuplicates: true,
            duplicateCount: 0,
            uniqueItems: 0,
            totalItems: 0,
            insufficient: true,
            wasJsonParsed: false,
            response: "TIMEOUT: Generation took longer than 60 seconds",
            parsedItems: [],
            normalizedItems: []
        )
    }

    private static func buildErrorTestResult(promptNumber: Int, systemPrompt: String, error: Error) -> TestResult {
        print("🧪 ❌ ERROR testing prompt #\(promptNumber): \(error)")
        return TestResult(
            promptNumber: promptNumber,
            promptText: systemPrompt,
            hasDuplicates: true,
            duplicateCount: 0,
            uniqueItems: 0,
            totalItems: 0,
            insufficient: true,
            wasJsonParsed: false,
            response: "ERROR: \(error.localizedDescription)",
            parsedItems: [],
            normalizedItems: []
        )
    }
}
#endif
