//
//  AppleIntelligence+TestConfig.swift
//  Tiercade
//
//  Configuration system for testing different prompt templates and settings
//

import Foundation

#if canImport(FoundationModels) && (os(iOS) || os(macOS))
@available(iOS 26.0, macOS 26.0, *)

// MARK: - Test Configuration Types

internal struct TestConfiguration: Codable {
    let name: String
    let description: String
    let tokenPerItem: Int
    let minTokens: Int
    let tokenMultiplier: Double
    let maxChunkSize: Int?
    let promptTemplate: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case tokenPerItem = "token_per_item"
        case minTokens = "min_tokens"
        case tokenMultiplier = "token_multiplier"
        case maxChunkSize = "max_chunk_size"
        case promptTemplate = "prompt_template"
    }
}

internal struct SamplingProfile: Codable {
    let name: String
    let type: String
    let value: Double?
    let temperature: Double
}

internal struct TestScenario: Codable {
    let name: String
    let config: String
    let sampling: String
    let targetCount: Int
    let query: String

    enum CodingKeys: String, CodingKey {
        case name
        case config
        case sampling
        case targetCount = "target_count"
        case query
    }
}

internal struct TestConfigFile: Codable {
    let configurations: [TestConfiguration]
    let samplingProfiles: [SamplingProfile]
    let testScenarios: [TestScenario]

    enum CodingKeys: String, CodingKey {
        case configurations
        case samplingProfiles = "sampling_profiles"
        case testScenarios = "test_scenarios"
    }
}

extension UniqueListCoordinator {

    /// Load test configurations from file
    internal static func loadTestConfigurations() -> TestConfigFile? {
        // First try project directory
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("test_configs.json")

        // Also try Documents directory
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("test_configs.json")

        // Try /tmp as fallback
        let tmpPath = URL(fileURLWithPath: "/tmp/test_configs.json")

        for path in [projectPath, docsPath, tmpPath].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: path),
               let config = try? JSONDecoder().decode(TestConfigFile.self, from: data) {
                print("📋 Loaded test configurations from: \(path.path)")
                return config
            }
        }

        print("⚠️ No test configuration file found")
        return nil
    }

    /// Apply a test configuration to the current generation settings
    internal func applyConfiguration(_ config: TestConfiguration) {
        print("🔧 Applying configuration: \(config.name) - \(config.description)")

        // Store configuration in UserDefaults for the actual generation code to use
        let defaults = UserDefaults.standard
        defaults.set(config.tokenPerItem, forKey: "test_config_token_per_item")
        defaults.set(config.minTokens, forKey: "test_config_min_tokens")
        defaults.set(config.tokenMultiplier, forKey: "test_config_token_multiplier")
        defaults.set(config.maxChunkSize, forKey: "test_config_max_chunk_size")
        defaults.set(config.promptTemplate, forKey: "test_config_prompt_template")
        defaults.synchronize()
    }

    struct ConfigOverrides {
        let tokenPerItem: Int?
        let minTokens: Int?
        let tokenMultiplier: Double?
        let maxChunkSize: Int?
        let promptTemplate: String?
    }

    /// Get current configuration overrides
    internal static func getCurrentConfigOverrides() -> ConfigOverrides {
        let defaults = UserDefaults.standard

        // Clean up old values if test is not active
        if !CommandLine.arguments.contains("-testConfig") {
            return ConfigOverrides(
                tokenPerItem: nil,
                minTokens: nil,
                tokenMultiplier: nil,
                maxChunkSize: nil,
                promptTemplate: nil
            )
        }

        return ConfigOverrides(
            tokenPerItem: defaults.object(forKey: "test_config_token_per_item") as? Int,
            minTokens: defaults.object(forKey: "test_config_min_tokens") as? Int,
            tokenMultiplier: defaults.object(forKey: "test_config_token_multiplier") as? Double,
            maxChunkSize: defaults.object(forKey: "test_config_max_chunk_size") as? Int,
            promptTemplate: defaults.string(forKey: "test_config_prompt_template")
        )
    }

    /// Build prompt with configuration template
    internal static func buildPromptFromTemplate(
        template: String,
        count: Int,
        query: String,
        avoidList: [String]
    ) -> String {
        let avoidJSON = avoidList.map { "\"\($0)\"" }.joined(separator: ", ")

        return template
            .replacingOccurrences(of: "{count}", with: "\(count)")
            .replacingOccurrences(of: "{query}", with: query)
            .replacingOccurrences(of: "{avoid_list}", with: avoidJSON)
    }

    /*
     /// Run a specific test scenario (future enhancement - requires generate method)
     func runTestScenario(_ scenario: TestScenario) async throws {
     guard let configs = Self.loadTestConfigurations() else {
     throw NSError(domain: "TestConfig", code: -1, userInfo: [
     NSLocalizedDescriptionKey: "Failed to load test configurations"
     ])
     }

     guard let config = configs.configurations.first(where: { $0.name == scenario.config }) else {
     throw NSError(domain: "TestConfig", code: -2, userInfo: [
     NSLocalizedDescriptionKey: "Configuration '\(scenario.config)' not found"
     ])
     }

     guard let sampling = configs.samplingProfiles.first(where: { $0.name == scenario.sampling }) else {
     throw NSError(domain: "TestConfig", code: -3, userInfo: [
     NSLocalizedDescriptionKey: "Sampling profile '\(scenario.sampling)' not found"
     ])
     }

     print("🧪 Running test scenario: \(scenario.name)")
     print("   Config: \(config.name)")
     print("   Sampling: \(sampling.name)")
     print("   Target: \(scenario.targetCount) items")
     print("   Query: \(scenario.query)")

     // Apply the configuration
     applyConfiguration(config)

     // Create appropriate DecoderProfile
     let profile: DecoderProfile
     switch sampling.type {
     case "topK":
     profile = .topK(Int(sampling.value ?? 40))
     case "topP":
     profile = .topP(sampling.value ?? 0.92)
     case "greedy":
     profile = .greedy
     default:
     profile = .topK(40)
     }

     // Run the generation
     let result = try await self.generate(
     N: scenario.targetCount,
     query: scenario.query,
     budget: 3600,  // Max tokens
     seeds: [42],   // Single seed for testing
     decoders: [profile]
     )

     print("✅ Scenario complete: \(result.ordered.count)/\(scenario.targetCount) unique items")
     }
     */
}

// Extension to use configuration in generation
@available(iOS 26.0, macOS 26.0, *)
extension FMClient {

    struct GenerateWithConfigParameters {
        let prompt: String
        let profile: DecoderProfile
        let initialSeed: UInt64?
        let temperature: Double?
        let maxTokens: Int?
    }

    /// Generate with configuration overrides
    internal func generateWithConfig(
        _ params: GenerateWithConfigParameters,
        telemetry: inout [AttemptMetrics]
    ) async throws -> [String] {
        // Check for configuration overrides
        let overrides = UniqueListCoordinator.getCurrentConfigOverrides()

        // Use overridden values if available
        let actualMaxTokens = overrides.minTokens ?? params.maxTokens
        let actualPrompt: String

        if overrides.promptTemplate != nil {
            // Parse the prompt to extract count, query, and avoid list
            // This is a simplified extraction - in production would need better parsing
            actualPrompt = params.prompt  // For now, use original until we implement full parsing
        } else {
            actualPrompt = params.prompt
        }

        // Call the actual generation method
        return try await generateTextArray(
            GenerateTextArrayParameters(
                prompt: actualPrompt,
                profile: params.profile,
                initialSeed: params.initialSeed,
                temperature: params.temperature,
                maxTokens: actualMaxTokens,
                maxRetries: 3
            ),
            telemetry: &telemetry
        )
    }
}
#endif
