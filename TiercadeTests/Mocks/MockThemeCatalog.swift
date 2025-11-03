import Foundation
@testable import Tiercade
import TiercadeCore

/// Mock implementation of ThemeCatalogProviding for testing
///
/// Allows tests to inject predictable theme data without depending on
/// actual SwiftData or bundled theme catalogs.
actor MockThemeCatalog: ThemeCatalogProviding {
    // MARK: - Configuration

    /// Bundled themes to return
    var bundledThemesData: [TierTheme] = []

    /// Custom themes to return
    var customThemesData: [TierTheme] = []

    /// Error to throw from save/delete operations
    var errorToThrow: Error?

    /// Tracks all save calls for verification
    private(set) var saveCalls: [TierTheme] = []

    /// Tracks all delete calls for verification
    private(set) var deleteCalls: [String] = []

    // MARK: - ThemeCatalogProviding

    func allThemes() async -> [TierTheme] {
        bundledThemesData + customThemesData
    }

    func bundledThemes() async -> [TierTheme] {
        bundledThemesData
    }

    func customThemes() async -> [TierTheme] {
        customThemesData
    }

    func saveCustomTheme(_ theme: TierTheme) async throws {
        saveCalls.append(theme)

        if let error = errorToThrow {
            throw error
        }

        // Simulate successful save by adding to custom themes
        customThemesData.append(theme)
    }

    func deleteCustomTheme(id: String) async throws {
        deleteCalls.append(id)

        if let error = errorToThrow {
            throw error
        }

        // Simulate successful delete
        customThemesData.removeAll { $0.id.uuidString == id }
    }

    func findTheme(id: String) async -> TierTheme? {
        let all = await allThemes()
        return all.first { $0.id.uuidString == id }
    }

    // MARK: - Test Helpers

    /// Reset the mock to its initial state
    func reset() {
        bundledThemesData = []
        customThemesData = []
        errorToThrow = nil
        saveCalls = []
        deleteCalls = []
    }

    /// Configure the mock with test themes
    func mockThemes(bundled: [TierTheme], custom: [TierTheme]) {
        bundledThemesData = bundled
        customThemesData = custom
    }

    /// Configure the mock to throw an error
    func mockError(_ error: Error) {
        errorToThrow = error
    }
}
