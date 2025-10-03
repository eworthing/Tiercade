import Foundation
import TiercadeCore

// MARK: - Theme Management

extension AppState {
    /// Applies the selected theme to all tiers
    func applyTheme(_ theme: TierTheme) {
        selectedTheme = theme
        selectedThemeID = theme.id
        applyCurrentTheme()
        try? save()
        showSuccessToast("Theme '\(theme.displayName)' applied")
    }

    /// Applies the currently selected theme to all tier colors
    func applyCurrentTheme() {
        for (index, tierId) in tierOrder.enumerated() {
            tierColors[tierId] = selectedTheme.colorHex(forRank: tierId, fallbackIndex: index)
        }
        tierColors["unranked"] = selectedTheme.unrankedColorHex
        hasUnsavedChanges = true
    }

    /// Resets all tier colors to use the selected theme
    func resetToThemeColors() {
        applyCurrentTheme()
        showSuccessToast("Colors reset to '\(selectedTheme.displayName)' theme")
    }

    /// Toggles the theme picker overlay visibility
    func toggleThemePicker() {
        showThemePicker.toggle()
        // Ensure the active flag mirrors the requested visibility immediately
        // to avoid races where other views read `themePickerActive` before
        // the overlay's `onAppear` runs.
        themePickerActive = showThemePicker
    }

    /// Dismisses the theme picker overlay
    func dismissThemePicker() {
        showThemePicker = false
        themePickerActive = false
    }
}
