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
        for (index, tierId) in tierOrder.enumerated() {
            tierColors[tierId] = self.theme.selectedTheme.colorHex(forRank: tierId, fallbackIndex: index)
        }
        tierColors["unranked"] = self.theme.selectedTheme.unrankedColorHex
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
        // Ensure the active flag mirrors the requested visibility immediately
        // to avoid races where other views read `themePickerActive` before
        // the overlay's `onAppear` runs.
        theme.themePickerActive = overlays.showThemePicker
    }

    /// Dismisses the theme picker overlay
    internal func dismissThemePicker() {
        overlays.showThemePicker = false
        theme.themePickerActive = false
    }
}
