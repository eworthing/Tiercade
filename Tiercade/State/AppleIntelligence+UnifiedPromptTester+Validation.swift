import Foundation

#if DEBUG && canImport(FoundationModels)

// MARK: - Error Handling & Validation

@available(iOS 26.0, macOS 26.0, *)
extension UnifiedPromptTester {

// MARK: - Testing Errors

/// Errors that can occur during testing
internal enum TestingError: Error, LocalizedError {
    // Configuration errors
    case configurationNotFound(String)
    case invalidConfiguration(String)
    case missingRequiredField(String)

    // Execution errors
    case testExecutionFailed(String)
    case timeout
    case modelUnavailable
    case sessionCreationFailed

    // Data errors
    case invalidResponse(String)
    case parsingFailed(String)
    case validationFailed(String)

    // Prompt template errors
    case promptTemplateError(PromptTemplateError)

    // Resource errors
    case insufficientMemory
    case diskSpaceExhausted

    var errorDescription: String? {
        switch self {
        case .configurationNotFound(let name):
            return "Configuration not found: \(name)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .testExecutionFailed(let message):
            return "Test execution failed: \(message)"
        case .timeout:
            return "Test execution timed out"
        case .modelUnavailable:
            return "Language model is not available"
        case .sessionCreationFailed:
            return "Failed to create language model session"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse response: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .promptTemplateError(let error):
            return "Prompt template error: \(error.localizedDescription)"
        case .insufficientMemory:
            return "Insufficient memory to complete test"
        case .diskSpaceExhausted:
            return "Insufficient disk space for results"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .timeout:
            return "Try increasing the timeout duration or simplifying the test"
        case .modelUnavailable:
            return "Ensure Apple Intelligence is enabled in System Settings"
        case .insufficientMemory:
            return "Close other applications and try again"
        case .diskSpaceExhausted:
            return "Free up disk space and try again"
        default:
            return nil
        }
    }
}

/// Errors specific to prompt template processing
internal enum PromptTemplateError: Error, LocalizedError {
    case missingVariables([String])

    var errorDescription: String? {
        switch self {
        case .missingVariables(let vars):
            return "Missing required variables: \(vars.joined(separator: ", "))"
        }
    }
}

// MARK: - Config Validator

/// Validates configuration objects
internal struct ConfigValidator {
    /// Validate a system prompt config
    static func validate(_ prompt: SystemPromptConfig) throws {
        guard !prompt.id.isEmpty else {
            throw TestingError.missingRequiredField("SystemPrompt.id")
        }
        guard !prompt.text.isEmpty else {
            throw TestingError.missingRequiredField("SystemPrompt.text")
        }

        // Check if required variables are documented
        let template = PromptTemplate(raw: prompt.text)
        let required = template.requiredVariables()
        let documented = Set(prompt.metadata?.requiresVariables ?? [])

        if !required.isEmpty && documented.isEmpty {
            print("⚠️ Warning: Prompt '\(prompt.id)' has variables but none documented in metadata")
        }
    }

    /// Validate a test query config
    static func validate(_ query: TestQueryConfig) throws {
        guard !query.id.isEmpty else {
            throw TestingError.missingRequiredField("TestQuery.id")
        }
        guard !query.query.isEmpty else {
            throw TestingError.missingRequiredField("TestQuery.query")
        }

        if let target = query.targetCount {
            guard target > 0 && target <= 500 else {
                throw TestingError.validationFailed("Target count must be between 1 and 500")
            }
        }
    }

    /// Validate a decoding config
    static func validate(_ decoder: DecodingConfigDef) throws {
        guard !decoder.id.isEmpty else {
            throw TestingError.missingRequiredField("DecodingConfig.id")
        }

        guard decoder.temperature >= 0.0 && decoder.temperature <= 2.0 else {
            throw TestingError.validationFailed("Temperature must be between 0.0 and 2.0")
        }

        switch decoder.sampling.mode {
        case "greedy":
            break
        case "topK":
            guard let k = decoder.sampling.k, k > 0 else {
                throw TestingError.validationFailed("topK mode requires positive k value")
            }
        case "topP":
            guard let threshold = decoder.sampling.threshold,
                  threshold > 0.0 && threshold <= 1.0 else {
                throw TestingError.validationFailed("topP mode requires threshold between 0.0 and 1.0")
            }
        default:
            throw TestingError.validationFailed("Unknown sampling mode: \(decoder.sampling.mode)")
        }
    }

    /// Validate a test suite config
    static func validate(_ suite: TestSuiteConfig) throws {
        guard !suite.id.isEmpty else {
            throw TestingError.missingRequiredField("TestSuite.id")
        }
        guard !suite.config.promptIds.isEmpty else {
            throw TestingError.validationFailed("Test suite must specify at least one prompt")
        }
        guard !suite.config.queryIds.isEmpty else {
            throw TestingError.validationFailed("Test suite must specify at least one query")
        }
        guard !suite.config.decoderIds.isEmpty else {
            throw TestingError.validationFailed("Test suite must specify at least one decoder")
        }
        guard !suite.config.seeds.isEmpty else {
            throw TestingError.validationFailed("Test suite must specify at least one seed")
        }
        guard !suite.config.guidedModes.isEmpty else {
            throw TestingError.validationFailed("Test suite must specify at least one guided mode")
        }
    }
}

}
#endif
