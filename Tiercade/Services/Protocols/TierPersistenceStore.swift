import Foundation
import TiercadeCore

/// Protocol for persisting tier list state
///
/// Implementations handle the actual storage mechanism (SwiftData, UserDefaults, etc.)
/// while keeping the persistence logic testable through mock implementations.
///
/// **PR 1 NOTE**: This is infrastructure-only for dependency injection.
/// The actual persistence implementation will be completed in PR 3.
internal protocol TierPersistenceStore: Sendable {
    /// Indicates whether this store is available and ready to use
    var isAvailable: Bool { get }
}
