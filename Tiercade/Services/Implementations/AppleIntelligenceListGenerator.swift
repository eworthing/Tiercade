import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence-based list generator (macOS/iOS only)
///
/// Uses FoundationModels APIs to generate unique item lists via LLM.
/// Platform-gated to systems where FoundationModels is available.
internal actor AppleIntelligenceListGenerator: UniqueListGenerating {
    private let logger = Logger(subsystem: "com.tiercade.ai", category: "ListGenerator")

    internal init() {}

    internal nonisolated var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    internal func generateUniqueList(topic: String, count: Int) async throws -> [AIGeneratedItemCandidate] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw AIGenerationError.platformNotSupported
        }

        logger.info("Generating \(count) items for topic: \(topic)")

        // For PR 1, we're just setting up the protocol infrastructure
        // The actual implementation will be wired in PR 2 when we extract AIGenerationState
        // For now, return an empty array to satisfy the protocol
        logger.warning("AppleIntelligenceListGenerator not yet wired to FoundationModels (PR 1 infrastructure only)")
        return []

        #else
        throw AIGenerationError.platformNotSupported
        #endif
    }
}

// Note: makeAntiDuplicateInstructions() is defined in State/AppState+AppleIntelligence.swift
// and will be reused when we implement the full generation logic in PR 2.
