import Foundation
import Observation
import os
import SwiftData

/// Consolidated state for tier list persistence and file management
///
/// This state object encapsulates all persistence-related state including:
/// - Auto-save tracking (unsaved changes, last saved time)
/// - Active tier list management
/// - Recent tier lists history
/// - File I/O coordination
@MainActor
@Observable
final class PersistenceState {

    // MARK: Lifecycle

    // MARK: - Initialization

    init(persistenceStore: TierPersistenceStore) {
        self.persistenceStore = persistenceStore
        Logger.persistence.info("PersistenceState initialized")
    }

    // MARK: Internal

    // MARK: - Auto-Save State

    /// Whether there are unsaved changes to the current tier list
    var hasUnsavedChanges: Bool = false

    /// Timestamp of the last successful save operation
    var lastSavedTime: Date?

    // MARK: - Active Tier List

    /// Handle for the currently active tier list (if any)
    var activeTierList: TierListHandle?

    /// Cached reference to the active SwiftData entity
    var activeTierListEntity: TierListEntity?

    // MARK: - Recent Tier Lists

    /// Recently accessed tier lists (for quick access menu)
    var recentTierLists: [TierListHandle] = []

    /// Maximum number of recent tier lists to track
    let maxRecentTierLists: Int = 6

    /// Maximum number to show in quick pick menu
    let quickPickMenuLimit: Int = 5

    // MARK: - File Management

    /// Current file name (for save/load operations)
    var currentFileName: String?

    /// Check if the persistence store is available
    var isStoreAvailable: Bool {
        persistenceStore.isAvailable
    }

    // MARK: - State Management

    /// Mark that changes have been made and need saving
    func markUnsaved() {
        hasUnsavedChanges = true
    }

    /// Mark that all changes have been saved
    func markSaved() {
        hasUnsavedChanges = false
        lastSavedTime = Date()
    }

    // MARK: Private

    // MARK: - Dependencies

    private let persistenceStore: TierPersistenceStore

}
