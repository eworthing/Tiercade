import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

@MainActor
class SystemPromptTester {
    struct TestResult {
        let promptNumber: Int
        let promptText: String
        let hasDuplicates: Bool
        let duplicateCount: Int
        let uniqueItems: Int
        let totalItems: Int
        let insufficient: Bool
        let wasJsonParsed: Bool
        let response: String
        let parsedItems: [String]
        let normalizedItems: [String]
    }

    static func testPrompts(onProgress: @MainActor @escaping (String) -> Void) async -> [TestResult] {
        let testQuery = "What are the top 25 most popular animated series"
        var results: [TestResult] = []

        onProgress("🧪 Starting automated test of \(prompts.count) system prompts...")
        onProgress("Test query: '\(testQuery)'")
        print("\n🧪 ========== SYSTEM PROMPT TESTING ==========")
        print("🧪 Test query: \(testQuery)")
        print("🧪 Testing \(prompts.count) different system prompts...\n")

        for (index, prompt) in prompts.enumerated() {
            onProgress("\n[\(index + 1)/\(prompts.count)] Testing prompt variant \(index + 1)...")
            print("🧪 [\(index + 1)/\(prompts.count)] Testing prompt variant...")
            print("🧪 Prompt preview: \(String(prompt.prefix(100)))...")

            let result = await testSinglePrompt(
                promptNumber: index + 1,
                systemPrompt: prompt,
                testQuery: testQuery
            )

            results.append(result)

            // Save partial results after each test in case we hang later
            let partialPath = "/tmp/tiercade_prompt_test_PARTIAL.txt"
            writeDetailedLog(results: results, to: partialPath)
            print("🧪 💾 Saved partial results (\(results.count) tests) to: \(partialPath)")

            // Separate status reporting for different failure types
            let status: String
            if !result.hasDuplicates && !result.insufficient {
                status = "✅ PASSED"
            } else if result.insufficient && !result.hasDuplicates {
                status = "⚠️ INSUFFICIENT"
            } else if result.hasDuplicates && !result.insufficient {
                status = "❌ DUPLICATES"
            } else {
                status = "❌ BOTH"
            }

            // Show raw response (no truncation)
            onProgress("\n📝 RAW RESPONSE:")
            onProgress(result.response)

            // Show parsed items (all of them)
            if !result.parsedItems.isEmpty {
                onProgress("\n📋 PARSED ITEMS (\(result.parsedItems.count)):")
                for (index, item) in result.parsedItems.enumerated() {
                    onProgress("\(index + 1). \(item)")
                }
            }

            // Show normalized items (all of them)
            if !result.normalizedItems.isEmpty {
                onProgress("\n🔍 NORMALIZED ITEMS (\(result.normalizedItems.count) unique):")
                for (index, item) in result.normalizedItems.enumerated() {
                    onProgress("\(index + 1). \(item)")
                }
            }

            // Show analysis results
            let summaryMessage = """

            📊 ANALYSIS:
            • Status: \(status)
            • Format: \(result.wasJsonParsed ? "JSON" : "Text")
            • Total items: \(result.totalItems)
            • Unique items: \(result.uniqueItems)
            • Duplicates: \(result.duplicateCount)
            \(result.insufficient ? "• ⚠️ Insufficient items (needed 20+)" : "")
            """
            onProgress(summaryMessage)

            print("🧪 Result: \(status)")
            print("🧪   - Total items: \(result.totalItems)")
            print("🧪   - Unique items: \(result.uniqueItems)")
            print("🧪   - Duplicates: \(result.duplicateCount)")
            if result.insufficient {
                print("🧪   ⚠️ Insufficient items (needed 20+)")
            }
            print("")

            // Short delay between tests
            try? await Task.sleep(for: .seconds(1))
        }

        print("\n🧪 ========== TEST SUMMARY ==========")
        let successful = results.filter { !$0.hasDuplicates && !$0.insufficient }
        let onlyDuplicates = results.filter { $0.hasDuplicates && !$0.insufficient }
        let onlyInsufficient = results.filter { !$0.hasDuplicates && $0.insufficient }
        let bothFailures = results.filter { $0.hasDuplicates && $0.insufficient }

        print("🧪 Successful prompts: \(successful.count)/\(results.count)")
        print("🧪 Only duplicates: \(onlyDuplicates.count)")
        print("🧪 Only insufficient: \(onlyInsufficient.count)")
        print("🧪 Both failures: \(bothFailures.count)")

        let summaryMessage = """

        📊 RESULTS: \(successful.count) of \(results.count) prompts fully passed
        • ✅ Passed: \(successful.count) (no duplicates, sufficient items)
        • ❌ Duplicates only: \(onlyDuplicates.count)
        • ⚠️ Insufficient only: \(onlyInsufficient.count)
        • ❌ Both issues: \(bothFailures.count)
        """
        onProgress(summaryMessage)

        if !successful.isEmpty {
            print("\n✅ WORKING PROMPTS:")
            onProgress("\n✅ WORKING PROMPTS:")
            for result in successful {
                let msg = "  • Prompt #\(result.promptNumber): \(result.uniqueItems) unique items"
                onProgress(msg)
                print("   Prompt #\(result.promptNumber): \(result.uniqueItems) unique items")
            }
        } else {
            onProgress("\n❌ No prompts fully passed both checks.")
        }

        // Write comprehensive log file for LLM analysis
        let logPath = "/tmp/tiercade_prompt_test_results.txt"
        let legacyLogPath = "/tmp/tiercade_test_output.log"
        writeDetailedLog(results: results, to: logPath)
        onProgress("\n📁 Detailed results saved to: \(logPath)")
        onProgress("📁 Legacy log mirrored to: \(legacyLogPath)")
        print("🧪 Detailed log saved to: \(logPath)")
        print("🧪 Legacy log mirrored to: \(legacyLogPath)")

        return results
    }

    private static func writeDetailedLog(results: [TestResult], to path: String) {
        var log = """
        ================================================================================
        TIERCADE PROMPT TESTING - DETAILED RESULTS
        ================================================================================
        Date: \(Date())
        Test Query: "What are the top 25 most popular animated series"
        Total Prompts Tested: \(results.count)


        """

        for result in results {
            let status = !result.hasDuplicates && !result.insufficient ? "PASSED"
                : result.insufficient && !result.hasDuplicates ? "INSUFFICIENT"
                : result.hasDuplicates && !result.insufficient ? "DUPLICATES"
                : "BOTH_FAILURES"

            log += """
            ================================================================================
            PROMPT #\(result.promptNumber)
            ================================================================================
            Status: \(status)
            Format: \(result.wasJsonParsed ? "JSON" : "Text")
            Total Items: \(result.totalItems)
            Unique Items: \(result.uniqueItems)
            Duplicates: \(result.duplicateCount)
            Insufficient: \(result.insufficient)

            SYSTEM PROMPT:
            --------------------------------------------------------------------------------
            \(result.promptText)

            RAW RESPONSE:
            --------------------------------------------------------------------------------
            \(result.response)

            PARSED ITEMS (\(result.parsedItems.count)):
            --------------------------------------------------------------------------------
            \(result.parsedItems.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

            NORMALIZED ITEMS (\(result.normalizedItems.count) unique):
            --------------------------------------------------------------------------------
            \(result.normalizedItems.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))


            """
        }

        log += """
        ================================================================================
        SUMMARY
        ================================================================================
        Total Prompts: \(results.count)
        Passed: \(results.filter { !$0.hasDuplicates && !$0.insufficient }.count)
        Duplicates Only: \(results.filter { $0.hasDuplicates && !$0.insufficient }.count)
        Insufficient Only: \(results.filter { !$0.hasDuplicates && $0.insufficient }.count)
        Both Failures: \(results.filter { $0.hasDuplicates && $0.insufficient }.count)
        ================================================================================
        """

        do {
            // Ensure the directory exists
            let url = URL(fileURLWithPath: path)
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            // Write the log file
            try log.write(toFile: path, atomically: true, encoding: .utf8)
            print("🧪 ✅ Log file written successfully to: \(path)")
            print("🧪 📁 File size: \(log.count) characters")

            // Mirror to the legacy aggregated log path for automation consumers
            let legacyPath = "/tmp/tiercade_test_output.log"
            try log.write(toFile: legacyPath, atomically: true, encoding: .utf8)
            print("🧪 ✅ Legacy log mirrored to: \(legacyPath)")
        } catch {
            print("🧪 ❌ ERROR writing log file to \(path)")
            print("🧪 ❌ Error: \(error)")
            print("🧪 ❌ Error description: \(error.localizedDescription)")

            // Fallback: try writing to Documents directory
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fallbackPath = documentsPath.appendingPathComponent("tiercade_prompt_test_results.txt").path
                do {
                    try log.write(toFile: fallbackPath, atomically: true, encoding: .utf8)
                    print("🧪 ✅ Fallback: Log written to \(fallbackPath)")
                } catch {
                    print("🧪 ❌ Fallback also failed: \(error)")
                }
            }
        }
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

    struct TimeoutError: Error, Sendable {}

    private static func testSinglePrompt(
        promptNumber: Int,
        systemPrompt: String,
        testQuery: String
    ) async -> TestResult {
        do {
            let instructions = Instructions(systemPrompt)
            let session = LanguageModelSession(model: .default, tools: [], instructions: instructions)

            // Explicit generation options for reproducibility and control
            let opts = GenerationOptions(
                sampling: .random(top: 50, seed: UInt64.random(in: 0...UInt64.max)),
                temperature: 0.8,
                maximumResponseTokens: 1200
            )

            print("🧪   ⏱️ Starting generation with 60s timeout...")

            // Add timeout to prevent hanging forever
            let responseContent = try await withTimeout(seconds: 60) {
                try await session.respond(to: Prompt(testQuery), options: opts).content
            }

            print("🧪   ✅ Generation completed successfully")
            let analysis = analyzeDuplicates(responseContent)

            return TestResult(
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
        } catch is TimeoutError {
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
        } catch {
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

    // Robust normalization function for duplicate detection
    private static func normalize(_ text: String) -> String {
        // Unicode folding (handles diacritics and case)
        var normalized = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )

        // Remove leading articles (the/a/an)
        if let range = normalized.range(
            of: #"^(the|a|an)\s+"#,
            options: .regularExpression
        ) {
            normalized.removeSubrange(range)
        }

        // Remove content in parentheses/brackets
        normalized = normalized.replacingOccurrences(
            of: #"\s*[\(\[\{].*?[\)\]\}]"#,
            with: "",
            options: .regularExpression
        )

        // Strip punctuation (except apostrophes in words)
        normalized = normalized.replacingOccurrences(
            of: #"[^\w\s']"#,
            with: "",
            options: .regularExpression
        )

        // Collapse whitespace
        normalized = normalized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct DuplicateAnalysisResult {
        let hasDuplicates: Bool
        let duplicateCount: Int
        let uniqueItems: Int
        let totalItems: Int
        let insufficient: Bool
        let wasJsonParsed: Bool
        let parsedItems: [String]
        let normalizedItems: [String]
    }

    private static func analyzeDuplicates(
        _ text: String,
        expectedCount: Int = 25
    ) -> DuplicateAnalysisResult {
        var items: [String] = []
        var wasJsonParsed = false

        // Try to parse as JSON array first
        if let jsonData = text.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            items = jsonArray
            wasJsonParsed = true
            print("🧪   Parsed as JSON array")
        } else {
            // Try numbered list parsing
            let lines = text.components(separatedBy: .newlines)
            var foundNumberedItems = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let range = trimmed.range(of: #"^\d+[\.)]\s*"#, options: .regularExpression) {
                    let content = String(trimmed[range.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                    items.append(content)
                    foundNumberedItems = true
                }
            }

            // If no numbered items found, try one-per-line format
            // But limit to avoid counting prose as items
            if !foundNumberedItems {
                var lineCount = 0
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // Skip empty lines and lines that look like commentary or prose
                    if !trimmed.isEmpty
                        && !trimmed.hasPrefix("//")
                        && !trimmed.hasPrefix("#")
                        && trimmed.count < 100 {  // Avoid prose paragraphs
                        items.append(trimmed)
                        lineCount += 1
                        if lineCount > 50 { break }  // Cap to avoid runaway parsing
                    }
                }
            }
        }

        // Count duplicates using robust normalization
        var seenNormalized = Set<String>()
        var normalizedList: [String] = []
        var duplicateCount = 0

        for item in items {
            let normalized = normalize(item)
            if seenNormalized.contains(normalized) {
                duplicateCount += 1
                print("🧪   Duplicate detected: '\(item)' (normalized: '\(normalized)')")
            } else {
                seenNormalized.insert(normalized)
                normalizedList.append(normalized)
            }
        }

        let totalItems = items.count
        let uniqueItems = seenNormalized.count

        // Separate failure causes
        let minimumRequired = Int(Double(expectedCount) * 0.8)
        let insufficient = totalItems < minimumRequired
        let hasDuplicates = duplicateCount > 0

        return DuplicateAnalysisResult(
            hasDuplicates: hasDuplicates,
            duplicateCount: duplicateCount,
            uniqueItems: uniqueItems,
            totalItems: totalItems,
            insufficient: insufficient,
            wasJsonParsed: wasJsonParsed,
            parsedItems: items,
            normalizedItems: normalizedList
        )
    }

    // Different system prompt variations to test
    private static let prompts = [
        // 1. Ultra-simple (baseline)
        """
        You are a helpful assistant.
        """,

        // 2. Strong imperative
        """
        You are a helpful assistant.

        NEVER repeat items in lists. Each entry must be unique.
        """,

        // 3-5. Few-shot prompting (showing correct examples)
        """
        You are a helpful assistant.

        Example of a CORRECT list (all unique items):
        1. France
        2. Japan
        3. Brazil
        4. Egypt
        5. Australia

        Example of an INCORRECT list (has duplicates - NEVER do this):
        1. France
        2. Japan
        3. France  ← WRONG! Already listed at #1

        When creating lists, ensure every item is unique like the correct example.
        """,

        """
        You are a helpful assistant.

        When asked for the "top N items", provide exactly N different items.

        Example request: "What are the top 3 colors?"
        Correct response:
        1. Red
        2. Blue
        3. Green

        Incorrect response:
        1. Red
        2. Blue
        3. Red  ← ERROR: duplicate

        Always follow the correct pattern.
        """,

        """
        You are a helpful assistant.

        CRITICAL: Maintain a mental set of items already mentioned. Before writing each item, check this set.

        Example process for "top 3 metals":
        - Item 1: "Gold" → Set: {gold}
        - Item 2: "Silver" → Set: {gold, silver}
        - Item 3: Check set, don't use gold or silver → "Copper" → Set: {gold, silver, copper}

        Use this process for all lists.
        """,

        // 6-8. Chain-of-thought reasoning
        """
        You are a helpful assistant.

        When creating lists, use this process:
        1. Read the request and note how many items are needed
        2. Generate each item ONE AT A TIME
        3. Before writing each item, mentally review all previous items
        4. Only add items that are completely new
        5. Stop when you reach the requested count

        Think through each step carefully.
        """,

        """
        You are a helpful assistant.

        For list generation:
        - Step 1: Understand N (the number requested)
        - Step 2: Create a mental checklist starting empty: []
        - Step 3: For each position from 1 to N:
          * Think of a candidate item
          * Check if it's in the checklist
          * If yes: think of a different item
          * If no: add to checklist and include in response
        - Step 4: Output the final list

        Follow this process exactly.
        """,

        """
        You are a helpful assistant. Answer clearly and concisely.

        BEFORE responding to list requests:
        1. Count how many items are needed
        2. Plan out all items mentally
        3. Verify no duplicates in your plan
        4. Output the verified plan

        If you notice duplicates while writing, STOP and revise.
        """,

        // 9-10. Self-critique and validation
        """
        You are a helpful assistant.

        After generating each list:
        1. Review what you wrote
        2. Check for any repeated items
        3. If you find duplicates, remove them and add new unique items
        4. Only show the final corrected list

        Quality control is essential.
        """,

        """
        You are a helpful assistant.

        When asked for N items, you MUST provide exactly N DIFFERENT items.

        After writing your list, perform this check:
        - Read through each numbered item
        - Cross-reference against all other items
        - If any item appears more than once, you have made an error
        - Correct any errors before responding

        This validation step is mandatory.
        """,

        // 11-13. Structured/constrained output
        """
        You are a helpful assistant.

        For list requests, use this EXACT format:

        [List of N items - each must be unique]
        1. <first unique item>
        2. <second unique item - different from #1>
        3. <third unique item - different from #1 and #2>
        ...
        N. <Nth unique item - different from all previous>

        The constraint "different from all previous" is MANDATORY for each entry.
        """,

        """
        You are a helpful assistant.

        List generation protocol:
        - Maintain a "used items" set
        - For each item: CHECK "used items" → IF present, choose different item → ADD to "used items" → OUTPUT item
        - Repeat until count reached

        This is a deterministic algorithm. Follow it exactly.
        """,

        """
        You are a helpful assistant.

        When creating numbered lists:
        Rule 1: Each number (1, 2, 3, ..., N) gets a unique item
        Rule 2: No item text can appear after multiple numbers
        Rule 3: Case-insensitive comparison (e.g., "Item" and "item" are the same)

        These rules are inviolable.
        """,

        // 14. Quality Over Quantity (Negative Reward)
        """
        You are an expert list generator. Your primary goal is quality and uniqueness.

        CRITICAL RULE: It is better to stop early and provide a shorter list than to provide a single duplicate item.

        If you are asked for 25 items, but you can only think of 20 unique items, your response MUST stop at 20. \
        Do not add a 21st item if it is a repeat.

        Repetition is a critical failure. Uniqueness is the highest priority.
        """,

        // 15. Architectural-Aware (Chunked Self-Correction)
        """
        You are a language model. You have an architectural limitation: when generating long lists, you can "forget" \
        items you wrote at the beginning. This can cause you to accidentally repeat items.

        To compensate for this, you MUST follow this strict, chunked generation algorithm:

        1. Generate items 1 through 5.
        2. PAUSE. Re-read items 1-5 to refresh your memory.
        3. Generate items 6 through 10, checking against 1-5.
        4. PAUSE. Re-read items 1-10 to refresh your memory.
        5. Generate items 11 through 15, checking against 1-10.
        6. PAUSE. Re-read items 1-15 to refresh your memory.
        7. Generate items 16 through 20, checking against 1-15.
        8. PAUSE. Re-read items 1-20 to refresh your memory.
        9. Generate items 21 through 25, checking against 1-20.

        This "pause and re-read" process is mandatory to ensure no duplicates.
        """,

        // 16. Universal JSON + Count Detection
        """
        You output JSON only. Return an array of strings for whatever list the user requests.

        If the user specifies a number N, return exactly N items.
        If the user asks for "all/complete/every," return as many as possible up to a safe cap.
        Otherwise return 25 items.

        No commentary.
        """,

        // 17. Canonicalization + Uniqueness Definition
        """
        Return a JSON array of strings.

        Items are considered DUPLICATES if they match after:
        - Case-insensitive comparison
        - Removing leading "the", "a", "an"
        - Stripping punctuation and parentheses/brackets
        - Collapsing whitespace

        Example: "The Matrix (1999)" and "Matrix" are duplicates.

        Use canonical names only. No alternate titles, years, or editions.
        Output only the JSON array.
        """,

        // 18. Diversity Constraint
        """
        Return a JSON array of strings.

        Aim for diversity across eras, styles, countries, and creators.
        Avoid clustering (e.g., all from one decade or one studio).
        Avoid near-duplicates that differ only trivially.

        Spread helps prevent repetition.
        No commentary.
        """,

        // 19. Alphabet Spread Bias
        """
        Return a JSON array of strings.

        Prefer coverage across A-Z so items start with varied letters.
        This natural spreading helps avoid duplicates.

        Don't force unnatural choices, but when equivalent options exist, prefer alphabetic diversity.

        Output only JSON array.
        """,

        // 20. Exact-Length Schema Hint
        """
        Return ONLY a JSON array of strings.

        If N is present in the user request, array length must equal N.
        Otherwise choose 25.

        Enforce uniqueness before emitting the array.

        No other text.
        """,

        // 21. Minimal Numbered Format (Alternative Output)
        """
        Output exactly N numbered lines (1 through N).
        Each line: number, period, space, item name only.
        No years, no parentheses, no explanations.

        Example:
        1. First Item
        2. Second Item
        3. Third Item

        Each item must be different using case-insensitive comparison.
        """,

        // 22. One Concept Per Entry (Franchise Deduplication)
        """
        Return JSON array of strings.

        One item per concept/franchise/brand/parent entity.
        Merge variants into single canonical item.

        WRONG: ["Star Wars", "Star Wars: Episode V", "Star Wars: Episode VI"]
        RIGHT: ["Star Wars"]

        Treat series/franchises as single entries.
        Output only JSON array.
        """,

        // 23. Near-Duplicate Ban List
        """
        Return JSON array of strings.

        Treat as DUPLICATES and avoid:
        - Items differing only by year/date
        - Edition/remaster/version variants
        - Punctuation differences
        - Plural vs singular
        - Trademark symbols (™, ®)
        - Trivial qualifiers

        Use strictest uniqueness definition.
        Output only JSON array.
        """,

        // 24. Shorter List (Reduced Scope)
        """
        You are a helpful assistant.

        CRITICAL: For this test, provide exactly 10 items instead of 25.
        Shorter lists may be easier to keep unique.

        Each item must be completely different from all others.
        Use strict case-insensitive comparison.
        """,

        // 25. JSON + Few-Shot Example (Combined Best Practices)
        """
        Output ONLY a valid JSON array of strings. No other text.

        Example of correct output (all unique):
        ["Python", "JavaScript", "Java", "C++", "Ruby"]

        Example of WRONG output (has duplicate):
        ["Python", "JavaScript", "Python"]  ← ERROR

        Rules:
        1. Exactly N items if number specified, else 25
        2. Case-insensitive uniqueness check
        3. JSON array format only
        4. Verify count before output
        """,

        // 26. JSON + Set Semantics + A-Z Sort
        """
        Output JSON only.

        Build a SET of items (no duplicates) using case-insensitive comparison after:
        - Removing leading "the/a/an"
        - Stripping punctuation

        Then sort A-Z and emit as JSON array.
        No commentary.
        """,

        // 27. JSON + Internal Normalized Key
        """
        JSON only.

        Internally compute normalized key for each candidate:
        1. Lowercase
        2. Remove "the/a/an"
        3. Strip punctuation and parentheses
        4. Collapse spaces

        Ensure all keys are unique. Output names as JSON array.
        """,

        // 28. Over-Generate Then Filter (Two-Pass)
        """
        JSON only.

        Pass 1: Generate 40+ candidates
        Pass 2: Remove duplicates (case-insensitive, article-stripped)
        Pass 3: Take first 25 unique items

        Output only the final JSON array.
        """,

        // 29. Prefix-Distinct Rule
        """
        JSON only.

        Ensure first two characters of each item (after lowercasing, removing "the/a/an") are unique until exhausted.

        Then enforce full-string uniqueness.
        No commentary.
        """,

        // 30. Disjoint-Buckets Selection
        """
        JSON only.

        Silently partition space into disjoint categories.
        Select at most one item per category until list is filled.

        Enforce case-insensitive uniqueness.
        Output final array only.
        """,

        // 31. Sorted-by-Length Then A-Z
        """
        JSON only.

        After de-duplication (case-insensitive, article-stripped):
        1. Sort by character length (shortest first)
        2. Break ties alphabetically

        Emit sorted array.
        """,

        // 32. Ban Structural Tokens
        """
        JSON only.

        Do NOT output items containing:
        - Digits or roman numerals
        - Parentheses/brackets
        - "season", "episode", "edition", "remaster"
        - Trademark symbols (™, ®)

        Enforce normalized uniqueness.
        """,

        // 33. One-Per-Initial Pass Then Fill
        """
        JSON only.

        Pass 1: Pick items with all-different first letters (after removing "the/a/an")
        Pass 2: Fill remaining slots without duplicates

        Enforce case-insensitive uniqueness.
        """,

        // 34. Strict Validator Protocol (Retry Loop)
        """
        JSON only.

        Protocol:
        1. Generate candidates
        2. Normalize and drop duplicates
        3. Keep first 25 unique
        4. Verify array length = 25
        5. If fail: regenerate and retry
        6. Emit array

        No other text.
        """,

        // 35. Diversity-First Selection
        """
        JSON only.

        Prefer items that maximize diversity across:
        - Time periods
        - Geographic regions
        - Categories/genres

        Reject near-duplicates early.
        Enforce normalized uniqueness.
        """,

        // 36. One-Per-Line Plain Text Mode
        """
        Output one item per line.

        No numbering.
        No punctuation.
        No commentary.

        Enforce uniqueness using case-insensitive comparison after:
        - Removing leading "the/a/an"
        - Stripping punctuation
        - Collapsing whitespace
        """
    ]
}
#endif
