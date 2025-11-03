import Foundation
import SwiftUI
import Observation
import os
import TiercadeCore

/// Consolidated state for tier list data and operations
///
/// This state object encapsulates all tier-related state including:
/// - Tier data (tiers, tierOrder)
/// - Selection for multi-select operations
/// - Tier metadata (labels, colors, locks)
/// - Global sort mode
/// - Undo/redo history management
@MainActor
@Observable
internal final class TierListState {
    // MARK: - Tier Data

    /// Core tier structure: tier name -> array of items
    var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]

    /// Order of tiers for display (excludes "unranked")
    var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]

    // MARK: - Selection

    /// Set of selected item IDs for batch operations
    var selection: Set<String> = []

    // MARK: - Tier Metadata

    /// Locked tiers that cannot receive items
    var lockedTiers: Set<String> = []

    /// Tier display label overrides (tierId -> display label)
    var tierLabels: [String: String] = [:]

    /// Tier color overrides (tierId -> hex color)
    var tierColors: [String: String] = [:]

    // MARK: - Sort & Layout

    /// Global sort mode for all tiers (default: alphabetical A-Z)
    var globalSortMode: GlobalSortMode = .alphabetical(ascending: true)

    // MARK: - Undo/Redo

    /// Undo manager for tier operations
    var undoManager: UndoManager?

    /// Flag to prevent undo registration during undo/redo operations
    private var isPerformingUndoRedo = false

    // MARK: - Snapshot for Undo/Redo

    /// Snapshot of tier state for undo/redo
    internal struct TierStateSnapshot: Sendable {
        var tiers: Items
        var tierOrder: [String]
        var tierLabels: [String: String]
        var tierColors: [String: String]
        var lockedTiers: Set<String>
    }

    // MARK: - Initialization

    internal init() {
        Logger.appState.info("TierListState initialized")
    }

    // MARK: - Undo/Redo Management

    /// Update the undo manager
    internal func updateUndoManager(_ manager: UndoManager?) {
        undoManager = manager
    }

    /// Capture current tier state as a snapshot
    internal func captureTierSnapshot() -> TierStateSnapshot {
        TierStateSnapshot(
            tiers: tiers,
            tierOrder: tierOrder,
            tierLabels: tierLabels,
            tierColors: tierColors,
            lockedTiers: lockedTiers
        )
    }

    /// Restore tier state from a snapshot
    internal func restore(from snapshot: TierStateSnapshot) {
        tiers = snapshot.tiers
        tierOrder = snapshot.tierOrder
        tierLabels = snapshot.tierLabels
        tierColors = snapshot.tierColors
        lockedTiers = snapshot.lockedTiers
    }

    /// Finalize a change by registering undo and marking as changed
    internal func finalizeChange(action: String, undoSnapshot: TierStateSnapshot, markChanged: @escaping () -> Void) {
        if !isPerformingUndoRedo {
            let redoSnapshot = captureTierSnapshot()
            registerUndo(action: action, undoSnapshot: undoSnapshot, redoSnapshot: redoSnapshot, isRedo: false, markChanged: markChanged)
        }
        markChanged()
    }

    private func registerUndo(
        action: String,
        undoSnapshot: TierStateSnapshot,
        redoSnapshot: TierStateSnapshot,
        isRedo: Bool,
        markChanged: @escaping () -> Void
    ) {
        guard let manager = undoManager else { return }
        manager.registerUndo(withTarget: self) { target in
            target.performUndo(
                action: action,
                undoSnapshot: undoSnapshot,
                redoSnapshot: redoSnapshot,
                isRedo: isRedo,
                markChanged: markChanged
            )
        }
        manager.setActionName(action)
    }

    private func performUndo(
        action: String,
        undoSnapshot: TierStateSnapshot,
        redoSnapshot: TierStateSnapshot,
        isRedo: Bool,
        markChanged: @escaping () -> Void
    ) {
        isPerformingUndoRedo = true
        defer { isPerformingUndoRedo = false }
        let inverseSnapshot = captureTierSnapshot()
        restore(from: undoSnapshot)
        markChanged()
        undoManager?.registerUndo(withTarget: self) { target in
            target.performUndo(
                action: action,
                undoSnapshot: redoSnapshot,
                redoSnapshot: inverseSnapshot,
                isRedo: !isRedo,
                markChanged: markChanged
            )
        }
        undoManager?.setActionName(action)
    }

    /// Perform undo if available
    internal func undo() {
        if let manager = undoManager, manager.canUndo {
            manager.undo()
        }
    }

    /// Perform redo if available
    internal func redo() {
        if let manager = undoManager, manager.canRedo {
            manager.redo()
        }
    }

    /// Check if undo is available
    internal var canUndo: Bool {
        undoManager?.canUndo ?? false
    }

    /// Check if redo is available
    internal var canRedo: Bool {
        undoManager?.canRedo ?? false
    }

    // MARK: - Computed Properties

    /// Total number of items across all tiers
    internal var totalItemCount: Int {
        tiers.values.reduce(into: 0) { partialResult, items in
            partialResult += items.count
        }
    }

    /// Whether there are any items
    internal var hasAnyItems: Bool {
        totalItemCount > 0
    }

    /// Whether there are enough items for pairing (H2H mode)
    internal var hasEnoughForPairing: Bool {
        totalItemCount >= 2
    }

    /// Whether there are enough items to randomize
    internal var canRandomizeItems: Bool {
        totalItemCount > 1
    }

    // MARK: - Selection Helpers

    /// Check if an item is selected
    internal func isSelected(_ id: String) -> Bool {
        selection.contains(id)
    }

    /// Toggle selection for an item
    internal func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// Clear all selections
    internal func clearSelection() {
        selection.removeAll()
    }

    // MARK: - Tier Display Helpers

    /// Get the display label for a tier (with fallback to tier ID)
    internal func displayLabel(for tierId: String) -> String {
        tierLabels[tierId] ?? tierId
    }

    /// Get the display color hex for a tier (with fallback)
    internal func displayColorHex(for tierId: String) -> String? {
        tierColors[tierId]
    }
}
