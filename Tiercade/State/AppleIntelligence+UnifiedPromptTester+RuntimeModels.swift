import Foundation

#if DEBUG && canImport(FoundationModels)
import FoundationModels

// MARK: - Runtime Models (Internal Test Execution)

@available(iOS 26.0, macOS 26.0, *)
internal extension UnifiedPromptTester {

// MARK: - Test Run

/// A single test run configuration
internal struct TestRun: Identifiable, Sendable {
    internal let id: UUID
    internal let runNumber: Int

    /// Configuration
    internal let prompt: SystemPromptConfig
    internal let query: TestQueryConfig
    internal let decoder: DecodingConfigDef
    internal let seed: UInt64
    internal let useGuidedSchema: Bool

    /// Computed properties
    internal var effectiveTarget: Int {
        query.targetCount ?? 40  // Default for open-ended queries
    }

    internal var nBucket: String {
        switch effectiveTarget {
        case ...25: return "small"
        case 26...50: return "medium"
        default: return "large"
        }
    }

    /// Create a unique fingerprint for caching/deduplication
    internal var fingerprint: String {
        "\(prompt.id):\(query.id):\(decoder.id):\(seed):\(useGuidedSchema)"
    }
}

// MARK: - Test Run Context

/// Context for a test run (includes runtime state)
internal struct TestRunContext: Sendable {
    internal let run: TestRun
    internal let maxTokens: Int
    internal let overgenFactor: Double
    internal let startTime: Date

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
        internal let tokensPerItem = 10  // Increased from 6 to account for JSON formatting overhead
        internal let calculated = Int(ceil(Double(targetCount) * overgenFactor * Double(tokensPerItem) * 1.5))
        return min(4096, calculated)  // Increased cap to allow for larger lists
    }

    internal init(run: TestRun, maxTokensOverride: Int? = nil) {
        self.run = run
        internal let target = run.effectiveTarget
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
    internal let raw: String

    /// Available variables that can be substituted
    internal enum Variable: String, CaseIterable {
        case query = "{QUERY}"
        case delta = "{DELTA}"
        case avoidList = "{AVOID_LIST}"
        case targetCount = "{TARGET_COUNT}"
        case domain = "{DOMAIN}"
    }

    /// Substitute variables in the template
    internal func render(substitutions: [Variable: String]) -> String {
        internal var result = raw
        for (variable, value) in substitutions {
            result = result.replacingOccurrences(of: variable.rawValue, with: value)
        }
        return result
    }

    /// Check which variables are required by this template
    internal func requiredVariables() -> Set<Variable> {
        internal var required = Set<Variable>()
        for variable in Variable.allCases {
            if raw.contains(variable.rawValue) {
                required.insert(variable)
            }
        }
        return required
    }

    /// Validate that all required substitutions are provided
    internal func validate(substitutions: [Variable: String]) throws {
        internal let required = requiredVariables()
        internal let provided = Set(substitutions.keys)
        internal let missing = required.subtracting(provided)

        if !missing.isEmpty {
            throw TestingError.promptTemplateError(.missingVariables(missing.map { $0.rawValue }))
        }
    }
}

// MARK: - Test Progress

/// Progress information during test execution
internal struct TestProgress: Sendable {
    internal let completedRuns: Int
    internal let totalRuns: Int
    internal let currentRun: TestRun?
    internal let estimatedTimeRemaining: TimeInterval?

    internal var percentComplete: Double {
        Double(completedRuns) / Double(max(1, totalRuns))
    }

    internal var progressText: String {
        "\(completedRuns)/\(totalRuns) runs completed (\(Int(percentComplete * 100))%)"
    }
}

}
#endif
