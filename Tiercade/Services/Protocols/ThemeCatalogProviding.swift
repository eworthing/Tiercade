import Foundation

/// Protocol for providing and managing tier list themes
///
/// Implementations can provide bundled themes, user-created themes,
/// or dynamically fetched themes from remote sources.
internal protocol ThemeCatalogProviding: Sendable {
    /// Get all available themes
    /// - Returns: Array of all themes (bundled + custom)
    internal func allThemes() async -> [TierTheme]

    /// Get only bundled system themes
    /// - Returns: Array of bundled themes
    internal func bundledThemes() async -> [TierTheme]

    /// Get only user-created custom themes
    /// - Returns: Array of custom themes
    internal func customThemes() async -> [TierTheme]

    /// Save a custom theme
    /// - Parameter theme: The theme to save
    /// - Throws: ThemeError if save fails
    internal func saveCustomTheme(_ theme: TierTheme) async throws

    /// Delete a custom theme
    /// - Parameter id: The theme ID to delete
    /// - Throws: ThemeError if delete fails or theme is not custom
    internal func deleteCustomTheme(id: String) async throws

    /// Find a theme by ID
    /// - Parameter id: The theme ID to find
    /// - Returns: The theme if found, nil otherwise
    internal func findTheme(id: String) async -> TierTheme?
}

/// Errors specific to theme operations
internal enum ThemeError: Error, CustomStringConvertible {
    internal case themeNotFound(String)
    internal case cannotDeleteBundledTheme
    internal case saveFailed(String)
    internal case invalidThemeData

    internal var description: String {
        switch self {
        case .themeNotFound(let id):
            return "Theme not found: \(id)"
        case .cannotDeleteBundledTheme:
            return "Cannot delete bundled system themes"
        case .saveFailed(let message):
            return "Failed to save theme: \(message)"
        case .invalidThemeData:
            return "Invalid theme data provided"
        }
    }
}
