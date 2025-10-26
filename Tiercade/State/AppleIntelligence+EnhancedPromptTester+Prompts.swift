import Foundation

#if canImport(FoundationModels) && DEBUG
import FoundationModels

// MARK: - Prompts

@available(iOS 26.0, macOS 26.0, *)
extension EnhancedPromptTester {
    static let enhancedPrompts: [(name: String, text: String)] = [
        ("G0-Minimal", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        If a count is given, produce about 1.4× that many candidates. If no count, return a reasonable set.
        No commentary. Do not sort.
        """),

        ("G1-BudgetCap", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Produce up to 200 candidates, not more. No commentary. Do not sort.
        """),

        ("G2-LightUnique", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Aim for distinct items. If unsure, vary categories or eras.
        No commentary. Do not sort.
        """),

        ("G3-Diversity", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Encourage variety across regions, time periods, and subtypes. \
        Avoid near-identical variants in the same franchise or model line.
        No commentary. Do not sort.
        """),

        ("G4-CommonNames", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Use common names, not synonyms or parenthetical descriptors.
        No commentary. Do not sort.
        """),

        ("G5-GuidedSchema", """
        You output JSON: {"items":[string,...]} and nothing else.
        Task: {QUERY}
        """),

        ("G6-CandidateOnly", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Generate candidates freely. Do not check for duplicates or normalize.
        No commentary.
        """),

        ("G7-ShortNames", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Use short common names. No qualifiers or parentheticals.
        No commentary. Do not sort.
        """),

        ("G8-CategorySpread", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Aim for coverage across different types or subcategories relevant to the topic.
        No commentary. Do not sort.
        """),

        ("G9-NoNearVariants", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Avoid near-variants of the same item (model year, size, flavor) when a single \
        representative is reasonable.
        No commentary. Do not sort.
        """),

        ("G10-CommonNamePref", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Prefer common names over scientific names or regional synonyms.
        No commentary. Do not sort.
        """),

        ("G11-ProperNounPref", """
        Return ONLY a JSON array of strings.
        Task: {QUERY}
        Prefer distinct proper nouns. Avoid generic descriptions.
        No commentary. Do not sort.
        """)
    ]
}
#endif
