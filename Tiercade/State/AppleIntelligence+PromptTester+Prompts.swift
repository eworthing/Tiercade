import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Test Prompts

@MainActor
extension SystemPromptTester {
    static let prompts = [
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
        """,
    ]
}
#endif
