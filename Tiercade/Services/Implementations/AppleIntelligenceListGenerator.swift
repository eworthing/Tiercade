import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AppleIntelligenceListGenerator

/// Apple Intelligence-based list generator (macOS/iOS only)
///
/// Uses FoundationModels APIs to generate unique item lists via LLM.
/// Platform-gated to systems where FoundationModels is available.
actor AppleIntelligenceListGenerator: UniqueListGenerating {
    private let logger = Logger(subsystem: "com.tiercade.ai", category: "ListGenerator")

    init() {}

    nonisolated var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    func generateUniqueList(topic: String, count: Int) async throws -> [AIGeneratedItemCandidate] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw AIGenerationError.platformNotSupported
        }

        logger.info("Generating \(count) items for topic: \(topic)")

        // Stub: FoundationModels integration not implemented yet. Returning an
        // empty result keeps protocol contract intact until integration lands.
        logger.warning("AppleIntelligenceListGenerator not yet wired to FoundationModels (stub)")
        return []

        #else
        throw AIGenerationError.platformNotSupported
        #endif
    }
}

// Note: makeAntiDuplicateInstructions() is defined in State/AppState+AppleIntelligence.swift
// and will be reused when we implement the full generation logic in PR 2.
