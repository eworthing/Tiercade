import Foundation
import TiercadeCore

// MARK: - Theme Management

internal extension AppState {
    /// Applies the selected theme to all tiers
    internal func applyTheme(_ theme: TierTheme) {
        self.theme.selectedTheme = theme
        self.theme.selectedThemeID = theme.id
        applyCurrentTheme()
        try? save()
        showSuccessToast("Theme '\(theme.displayName)' applied")
    }

    /// Applies the currently selected theme to all tier colors
    internal func applyCurrentTheme() {
        tierColors = theme.applyTheme(theme.selectedTheme, to: tierOrder)
        persistence.hasUnsavedChanges = true
    }

    /// Resets all tier colors to use the selected theme
    internal func resetToThemeColors() {
        applyCurrentTheme()
        showSuccessToast("Colors reset to '\(self.theme.selectedTheme.displayName)' theme")
    }

    /// Toggles the theme picker overlay visibility
    internal func toggleThemePicker() {
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
    internal func dismissThemePicker() {
        overlays.dismissThemePicker()
    }
}
