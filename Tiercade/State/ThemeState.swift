import Foundation
import SwiftUI
import Observation
import os
import TiercadeCore

/// Consolidated state for theme selection and management
///
/// This state object encapsulates all theme-related state including:
/// - Selected theme and available themes
/// - Custom theme management
/// - Theme picker/creator active states
/// - Theme application and color updates
@MainActor
@Observable
internal final class ThemeState {
    // MARK: - Selected Theme

    /// Currently selected theme ID
    var selectedThemeID: UUID = TierThemeCatalog.defaultTheme.id

    /// Currently selected theme
    var selectedTheme: TierTheme = TierThemeCatalog.defaultTheme

    // MARK: - Custom Themes

    /// User-created custom themes
    var customThemes: [TierTheme] = []

    /// Set of custom theme IDs for quick lookup
    var customThemeIDs: Set<UUID> = []

    // MARK: - UI State

    /// Draft theme being edited in the theme creator
    var themeDraft: ThemeDraft?

    // MARK: - Dependencies

    private let themeCatalog: ThemeCatalogProviding

    // MARK: - Initialization

    internal init(themeCatalog: ThemeCatalogProviding) {
        self.themeCatalog = themeCatalog
        Logger.appState.info("ThemeState initialized")
    }

    // MARK: - Available Themes

    /// All available themes (bundled + custom)
    internal var availableThemes: [TierTheme] {
        TierThemeCatalog.allThemes + customThemes
    }

    /// Find a theme by ID
    internal func theme(with id: UUID) -> TierTheme? {
        availableThemes.first { $0.id == id }
    }

    // MARK: - Theme Application

    /// Apply a theme and return the color mappings
    /// Supports variable-length tier lists by repeating last color when tiers exceed theme ranks
    internal func applyTheme(_ theme: TierTheme, to tierOrder: [String]) -> [String: String] {
        selectedTheme = theme
        selectedThemeID = theme.id

        let themeRankCount = theme.rankedTiers.count

        var colors: [String: String] = [:]
        for (index, tierId) in tierOrder.enumerated() {
            // colorHex(forRank:fallbackIndex:) handles fallbacks internally
            colors[tierId] = theme.colorHex(forRank: tierId, fallbackIndex: index)
        }
        colors["unranked"] = theme.unrankedColorHex

        return colors
    }

    /// Get color hex for a tier from the current theme
    internal func colorHex(forRank rank: String, fallbackIndex: Int) -> String {
        selectedTheme.colorHex(forRank: rank, fallbackIndex: fallbackIndex)
    }

    // MARK: - Custom Theme Management

    /// Add a custom theme
    internal func addCustomTheme(_ theme: TierTheme) {
        guard !customThemeIDs.contains(theme.id) else { return }
        customThemes.append(theme)
        customThemeIDs.insert(theme.id)
        sortCustomThemes()
    }

    /// Remove a custom theme
    internal func removeCustomTheme(_ theme: TierTheme) {
        customThemes.removeAll { $0.id == theme.id }
        customThemeIDs.remove(theme.id)
    }

    /// Sort custom themes alphabetically
    private func sortCustomThemes() {
        customThemes.sort {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    // MARK: - Theme Draft Management

    /// Set the current theme draft
    internal func setThemeDraft(_ draft: ThemeDraft?) {
        themeDraft = draft
    }

    /// Clear the theme draft
    internal func clearThemeDraft() {
        themeDraft = nil
    }
}
