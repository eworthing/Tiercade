import Foundation
import TiercadeCore

// MARK: - Theme Management

extension AppState {
    /// Applies the selected theme to all tiers
    func applyTheme(_ theme: TierTheme) {
        self.theme.selectedTheme = theme
        self.theme.selectedThemeID = theme.id
        applyCurrentTheme()
        try? save()
        showSuccessToast("Theme '\(theme.displayName)' applied")
    }

    /// Applies the currently selected theme to all tier colors
    func applyCurrentTheme() {
        tierColors = theme.applyTheme(theme.selectedTheme, to: tierOrder)
        persistence.hasUnsavedChanges = true
    }

    /// Resets all tier colors to use the selected theme
    func resetToThemeColors() {
        applyCurrentTheme()
        showSuccessToast("Colors reset to '\(theme.selectedTheme.displayName)' theme")
    }

    /// Toggles the theme picker overlay visibility
    func toggleThemePicker() {
        // Close analysis when opening theme picker
        if !overlays.showThemePicker {
            showingAnalysis = false
            #if os(tvOS)
            overlays.showAnalyticsSidebar = false
            #endif
        }

        overlays.showThemePicker.toggle()
    }

    /// Dismisses the theme picker overlay
    func dismissThemePicker() {
        overlays.dismissThemePicker()
    }
}
