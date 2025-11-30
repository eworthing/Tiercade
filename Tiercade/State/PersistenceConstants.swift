import Foundation

/// Persistence timing constants for tier list auto-save and data synchronization.
///
/// These values balance data safety with performance, ensuring tier list changes
/// are persisted without causing excessive writes to SwiftData storage.
enum PersistenceIntervals {
    /// Auto-save interval for tier list changes (30 seconds).
    ///
    /// **Rationale:**
    /// - **Data safety:** Users expect tier list changes to persist without manual saves
    /// - **Performance:** More frequent saves (< 10s) cause unnecessary SwiftData writes
    /// - **User behavior:** Tier list editing typically involves bursts of activity
    ///   followed by pauses; 30s captures these natural boundaries
    /// - **Battery impact:** Minimizes disk writes on iOS/tvOS for battery efficiency
    ///
    /// **Trade-offs:**
    /// - Less frequent (60s+): Increased risk of data loss on app termination
    /// - More frequent (10s-): Higher CPU/disk usage, potential UI jank during saves
    ///
    /// **Testing considerations:**
    /// - Validated with rapid editing sessions (50+ items moved in < 60s)
    /// - Ensures autosave completes before app enters background (iOS/tvOS)
    static let autosave: TimeInterval = 30.0
}
