import Foundation
@testable import Tiercade
import TiercadeCore

/// Mock implementation of ThemeCatalogProviding for testing
///
/// Allows tests to inject predictable theme data without depending on
/// actual SwiftData or bundled theme catalogs.
internal actor MockThemeCatalog: ThemeCatalogProviding {
    // MARK: - Configuration

    /// Bundled themes to return
    internal var bundledThemesData: [TierTheme] = []

    /// Custom themes to return
    internal var customThemesData: [TierTheme] = []

    /// Error to throw from save/delete operations
    internal var errorToThrow: Error?

    /// Tracks all save calls for verification
    private(set) var saveCalls: [TierTheme] = []

    /// Tracks all delete calls for verification
    private(set) var deleteCalls: [String] = []

    // MARK: - ThemeCatalogProviding

    internal func allThemes() async -> [TierTheme] {
        bundledThemesData + customThemesData
    }

    internal func bundledThemes() async -> [TierTheme] {
        bundledThemesData
    }

    internal func customThemes() async -> [TierTheme] {
        customThemesData
    }

    internal func saveCustomTheme(_ theme: TierTheme) async throws {
        saveCalls.append(theme)

        if let error = errorToThrow {
            throw error
        }

        // Simulate successful save by adding to custom themes
        customThemesData.append(theme)
    }

    internal func deleteCustomTheme(id: String) async throws {
        deleteCalls.append(id)

        if let error = errorToThrow {
            throw error
        }

        // Simulate successful delete
        customThemesData.removeAll { $0.id.uuidString == id }
    }

    internal func findTheme(id: String) async -> TierTheme? {
        internal let all = await allThemes()
        return all.first { $0.id.uuidString == id }
    }

    // MARK: - Test Helpers

    /// Reset the mock to its initial state
    internal func reset() {
        bundledThemesData = []
        customThemesData = []
        errorToThrow = nil
        saveCalls = []
        deleteCalls = []
    }

    /// Configure the mock with test themes
    internal func mockThemes(bundled: [TierTheme], custom: [TierTheme]) {
        bundledThemesData = bundled
        customThemesData = custom
    }

    /// Configure the mock to throw an error
    internal func mockError(_ error: Error) {
        errorToThrow = error
    }
}
