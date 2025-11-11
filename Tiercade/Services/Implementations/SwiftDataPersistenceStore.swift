import Foundation
import SwiftData
import TiercadeCore
import os

/// SwiftData-backed persistence store for tier lists
///
/// Stub implementation for dependency injection infrastructure.
/// Concrete persistence logic is handled by AppState today and will migrate
/// into a dedicated store implementation in a future change.
@MainActor
internal final class SwiftDataPersistenceStore: TierPersistenceStore {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.tiercade.persistence", category: "SwiftData")

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("SwiftDataPersistenceStore initialized (stub)")
    }

    internal nonisolated var isAvailable: Bool {
        true
    }
}

// Note: TierListEntity is defined in State/Persistence/TierListEntities.swift
// and is already part of the SwiftData schema.
