import Foundation
import SwiftData
import TiercadeCore
import os

/// SwiftData-backed persistence store for tier lists
///
/// **PR 1 NOTE**: This is a stub implementation for dependency injection infrastructure.
/// The actual persistence logic will be implemented in PR 3 when we extract PersistenceState.
///
/// For now, this just wraps the existing AppState persistence methods.
@MainActor
internal final class SwiftDataPersistenceStore: TierPersistenceStore {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.tiercade.persistence", category: "SwiftData")

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("SwiftDataPersistenceStore initialized (PR 1 stub)")
    }

    internal nonisolated var isAvailable: Bool {
        true
    }
}

// Note: TierListEntity is defined in State/Persistence/TierListEntities.swift
// and is already part of the SwiftData schema.
