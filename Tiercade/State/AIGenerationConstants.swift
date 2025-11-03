import Foundation

/// Constants for Apple Intelligence list generation and prompt chunking.
///
/// These values control how large prompts are split into smaller chunks to stay
/// within FoundationModels context limits while maximizing batch efficiency.
internal enum AIChunkingLimits {
    /// Token budget per prompt chunk (800 tokens).
    ///
    /// **Purpose:**
    /// - Keeps prompt size below FoundationModels context limits
    /// - Allows meaningful batch generation without truncation
    /// - Balances throughput with API rate limits
    ///
    /// **Derivation:**
    /// - Empirically tuned for 20-50 item names per chunk
    /// - Based on rough tokenization: `(nameLength + 3) / 4 + 3` tokens per item
    /// - Accounts for JSON array overhead (brackets, quotes, commas)
    ///
    /// **Typical usage:**
    /// - 800 tokens ≈ 30-40 medium-length item names (15-25 chars each)
    /// - Supports both guided (seeded) and unguided generation modes
    ///
    /// **Trade-offs:**
    /// - Larger budget (1000+): Risk of prompt truncation, API errors
    /// - Smaller budget (500-): More API calls, slower total generation time
    ///
    /// See: `chunkByTokens(_:budget:)` in `AppleIntelligence+UniqueListGeneration.swift`
    static let tokenBudget: Int = 800
}
