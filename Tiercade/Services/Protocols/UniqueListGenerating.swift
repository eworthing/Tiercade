import Foundation

/// Protocol for generating unique item lists using AI/LLM services
///
/// Platform-gated to macOS/iOS where FoundationModels is available.
/// tvOS implementations should return empty results or throw unsupported errors.
protocol UniqueListGenerating: Sendable {
    /// Generate a unique list of items based on a topic
    /// - Parameters:
    ///   - topic: The topic or prompt for list generation
    ///   - count: Number of unique items to generate
    /// - Returns: Array of AI-generated item candidates
    /// - Throws: AIGenerationError if generation fails
    func generateUniqueList(topic: String, count: Int) async throws -> [AIGeneratedItemCandidate]

    /// Check if the generator is available on the current platform
    var isAvailable: Bool { get }
}

// Note: AIGeneratedItemCandidate and AIGenerationError are defined in
// State/Wizard/AIGenerationModels.swift and are already available globally.
