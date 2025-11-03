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

    /// Whether the theme picker is currently active (for focus management)
    var themePickerActive: Bool = false

    /// Whether the theme creator is currently active (for focus management)
    var themeCreatorActive: Bool = false

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
    internal func applyTheme(_ theme: TierTheme, to tierOrder: [String]) -> [String: String] {
        selectedTheme = theme
        selectedThemeID = theme.id

        var colors: [String: String] = [:]
        for (index, tierId) in tierOrder.enumerated() {
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

    // MARK: - Theme Picker/Creator State

    /// Activate the theme picker
    internal func activateThemePicker() {
        themePickerActive = true
    }

    /// Deactivate the theme picker
    internal func deactivateThemePicker() {
        themePickerActive = false
    }

    /// Activate the theme creator with a draft
    internal func activateThemeCreator(draft: ThemeDraft) {
        themeDraft = draft
        themeCreatorActive = true
    }

    /// Deactivate the theme creator and clear draft
    internal func deactivateThemeCreator() {
        themeCreatorActive = false
        themeDraft = nil
    }
}
