import Foundation
import TiercadeCore

/// Protocol for persisting tier list state
///
/// Implementations handle the actual storage mechanism (SwiftData, UserDefaults, etc.)
/// while keeping the persistence logic testable through mock implementations.
///
/// Infrastructure-only protocol for dependency injection.
/// A concrete implementation can use SwiftData, files, or other storage.
internal protocol TierPersistenceStore: Sendable {
    /// Indicates whether this store is available and ready to use
    var isAvailable: Bool { get }
}
