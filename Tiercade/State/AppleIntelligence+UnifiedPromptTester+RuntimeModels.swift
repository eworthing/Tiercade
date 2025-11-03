import Foundation

#if DEBUG && canImport(FoundationModels)
import FoundationModels

// MARK: - Runtime Models (Internal Test Execution)

@available(iOS 26.0, macOS 26.0, *)
extension UnifiedPromptTester {

// MARK: - Test Run

/// A single test run configuration
internal struct TestRun: Identifiable, Sendable {
    let id: UUID
    let runNumber: Int

    /// Configuration
    let prompt: SystemPromptConfig
    let query: TestQueryConfig
    let decoder: DecodingConfigDef
    let seed: UInt64
    let useGuidedSchema: Bool

    /// Computed properties
    var effectiveTarget: Int {
        query.targetCount ?? 40  // Default for open-ended queries
    }

    var nBucket: String {
        switch effectiveTarget {
        case ...25: return "small"
        case 26...50: return "medium"
        default: return "large"
        }
    }

    /// Create a unique fingerprint for caching/deduplication
    var fingerprint: String {
        "\(prompt.id):\(query.id):\(decoder.id):\(seed):\(useGuidedSchema)"
    }
}

// MARK: - Test Run Context

/// Context for a test run (includes runtime state)
internal struct TestRunContext: Sendable {
    let run: TestRun
    let maxTokens: Int
    let overgenFactor: Double
    let startTime: Date

    /// Calculate overgen factor based on target count
    static func calculateOvergenFactor(targetCount: Int) -> Double {
        switch targetCount {
        case ...50: return 1.4
        case 51...150: return 1.6
        default: return 2.0
        }
    }

    /// Calculate max tokens based on target and overgen factor
    static func calculateMaxTokens(targetCount: Int, overgenFactor: Double) -> Int {
        let tokensPerItem = 10  // Increased from 6 to account for JSON formatting overhead
        let calculated = Int(ceil(Double(targetCount) * overgenFactor * Double(tokensPerItem) * 1.5))
        return min(4096, calculated)  // Increased cap to allow for larger lists
    }

    internal init(run: TestRun, maxTokensOverride: Int? = nil) {
        self.run = run
        let target = run.effectiveTarget
        self.overgenFactor = Self.calculateOvergenFactor(targetCount: target)

        // Use override if provided, otherwise calculate
        if let override = maxTokensOverride {
            self.maxTokens = override
        } else {
            self.maxTokens = Self.calculateMaxTokens(targetCount: target, overgenFactor: overgenFactor)
        }

        self.startTime = Date()
    }
}

// MARK: - Prompt Template

/// Handles prompt template variable substitution
internal struct PromptTemplate {
    let raw: String

    /// Available variables that can be substituted
    enum Variable: String, CaseIterable {
        case query = "{QUERY}"
        case delta = "{DELTA}"
        case avoidList = "{AVOID_LIST}"
        case targetCount = "{TARGET_COUNT}"
        case domain = "{DOMAIN}"
    }

    /// Substitute variables in the template
    internal func render(substitutions: [Variable: String]) -> String {
        var result = raw
        for (variable, value) in substitutions {
            result = result.replacingOccurrences(of: variable.rawValue, with: value)
        }
        return result
    }

    /// Check which variables are required by this template
    internal func requiredVariables() -> Set<Variable> {
        var required = Set<Variable>()
        for variable in Variable.allCases where raw.contains(variable.rawValue) {
            required.insert(variable)
        }
        return required
    }

    /// Validate that all required substitutions are provided
    internal func validate(substitutions: [Variable: String]) throws {
        let required = requiredVariables()
        let provided = Set(substitutions.keys)
        let missing = required.subtracting(provided)

        if !missing.isEmpty {
            throw TestingError.promptTemplateError(.missingVariables(missing.map { $0.rawValue }))
        }
    }
}

// MARK: - Test Progress

/// Progress information during test execution
internal struct TestProgress: Sendable {
    let completedRuns: Int
    let totalRuns: Int
    let currentRun: TestRun?
    let estimatedTimeRemaining: TimeInterval?

    var percentComplete: Double {
        Double(completedRuns) / Double(max(1, totalRuns))
    }

    var progressText: String {
        "\(completedRuns)/\(totalRuns) runs completed (\(Int(percentComplete * 100))%)"
    }
}

}
#endif
