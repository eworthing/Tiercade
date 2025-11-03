import Foundation
@testable import Tiercade

/// Mock implementation of TierPersistenceStore for testing
///
/// Allows tests to verify persistence behavior without depending on
/// actual SwiftData or file system operations.
actor MockTierPersistenceStore: TierPersistenceStore {
    // MARK: - Configuration

    /// Whether the store should report as available
    var isAvailable: Bool = true

    // MARK: - Test Helpers

    /// Reset the mock to its initial state
    func reset() {
        isAvailable = true
    }
}
