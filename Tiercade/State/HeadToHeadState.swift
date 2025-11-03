import Foundation
import TiercadeCore

/// Phase of a Head-to-Head ranking session
internal enum H2HSessionPhase: Sendable {
    case quick
    case refinement
}

/// Consolidated state for Head-to-Head ranking mode
///
/// Previously scattered across 17+ properties in AppState with `h2h` prefix.
/// Consolidation benefits:
/// - Single source of truth for H2H session data
/// - Semantic grouping of related properties
/// - Improved autocomplete (no more `h2h` prefix pollution)
/// - Self-documenting structure
internal struct HeadToHeadState: Sendable {
    // MARK: - Session Control

    /// Whether a Head-to-Head session is currently active
    var isActive: Bool = false

    /// Timestamp when the session was activated (for exit command debouncing)
    var activatedAt: Date?

    /// Current phase of the Head-to-Head session
    var phase: H2HSessionPhase = .quick

    /// Snapshot of tier state before H2H session started (for undo)
    var initialSnapshot: TierListState.TierStateSnapshot?

    // MARK: - Item Pool & Pairing

    /// Items participating in the Head-to-Head session
    var pool: [Item] = []

    /// Current pair being compared (nil if between comparisons)
    var currentPair: (Item, Item)?

    /// Queue of pairs to compare (quick phase)
    var pairsQueue: [(Item, Item)] = []

    /// Pairs that were skipped and may be revisited
    var deferredPairs: [(Item, Item)] = []

    /// Suggested pairs for refinement phase
    var suggestedPairs: [(Item, Item)] = []

    // MARK: - Comparison Records

    /// Win/loss records for each item (keyed by item ID)
    var records: [String: H2HRecord] = [:]

    /// Set of skipped pair keys (for deduplication)
    var skippedPairKeys: Set<String> = []

    // MARK: - Progress Tracking (Quick Phase)

    /// Total number of comparisons planned for quick phase
    var totalComparisons: Int = 0

    /// Number of comparisons completed in quick phase
    var completedComparisons: Int = 0

    // MARK: - Progress Tracking (Refinement Phase)

    /// Total number of comparisons planned for refinement phase
    var refinementTotalComparisons: Int = 0

    /// Number of comparisons completed in refinement phase
    var refinementCompletedComparisons: Int = 0

    // MARK: - Artifacts

    /// Artifacts generated after quick phase (tier assignments, confidence scores)
    var artifacts: H2HArtifacts?

    // MARK: - Computed Properties

    /// Number of pairs that have been skipped
    var skippedCount: Int {
        skippedPairKeys.count
    }

    /// Quick phase progress (0.0 to 1.0)
    var progress: Double {
        guard totalComparisons > 0 else { return 0.0 }
        return Double(completedComparisons) / Double(totalComparisons)
    }

    /// Remaining comparisons in quick phase
    var remainingComparisons: Int {
        max(0, totalComparisons - completedComparisons)
    }

    /// Refinement phase progress (0.0 to 1.0)
    var refinementProgress: Double {
        guard refinementTotalComparisons > 0 else { return 0.0 }
        return Double(refinementCompletedComparisons) / Double(refinementTotalComparisons)
    }

    /// Remaining comparisons in refinement phase
    var refinementRemainingComparisons: Int {
        max(0, refinementTotalComparisons - refinementCompletedComparisons)
    }

    /// Total comparisons completed across both phases
    var totalDecidedComparisons: Int {
        completedComparisons + refinementCompletedComparisons
    }

    /// Total remaining comparisons across both phases
    var totalRemainingComparisons: Int {
        remainingComparisons + refinementRemainingComparisons
    }

    /// Overall progress across both phases (weighted 75% quick, 25% refinement)
    var overallProgress: Double {
        let quickFraction = progress
        let refinementFraction = refinementProgress
        let quickWeight = HeadToHeadWeights.quickPhase
        let refinementWeight = HeadToHeadWeights.refinementPhase
        return (quickFraction * quickWeight) + (refinementFraction * refinementWeight)
    }
}
