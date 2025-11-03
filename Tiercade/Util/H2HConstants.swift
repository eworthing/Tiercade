import Foundation

#if os(tvOS)
/// tvOS-specific interaction timing constants
public enum TVInteraction {
    /// Debounce time for exit command to prevent accidental dismissals
    /// when user quickly navigates away from overlay activation
    public static let exitCommandDebounce: TimeInterval = 0.35
}
#endif

/// Head-to-Head phase weighting for progress calculation
public enum HeadToHeadWeights {
    /// Weight given to quick-phase comparisons in overall progress (75%)
    public static let quickPhase: Double = 0.75

    /// Weight given to refinement-phase comparisons in overall progress (25%)
    public static let refinementPhase: Double = 0.25
}

/// Heuristics for determining comparison requirements based on pool size
public enum H2HHeuristics {
    /// Pool size threshold for "large" pools (10+ items)
    public static let largePoolThreshold = 10

    /// Pool size threshold for "medium" pools (6+ items)
    public static let mediumPoolThreshold = 6

    /// Desired comparisons per item for large pools
    public static let largeDesiredComparisons = 3

    /// Desired comparisons per item for medium pools
    /// Note: Same as large (intentionally - provides consistent confidence)
    public static let mediumDesiredComparisons = 3

    /// Desired comparisons per item for small pools
    public static let smallDesiredComparisons = 2
}

/// Toast notification timing defaults
public enum ToastDefaults {
    /// Default duration for toast messages (seconds)
    public static let duration: TimeInterval = 3.0
}
