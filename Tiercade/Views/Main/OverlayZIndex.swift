import Foundation

/// Z-index stacking order for overlays in MainAppView.
///
/// Defines semantic constants for overlay layering to prevent z-fighting and
/// maintain consistent stacking behavior across the app. Higher values appear
/// above lower values.
///
/// Usage:
/// ```swift
/// ProgressIndicatorView()
///     .zIndex(OverlayZIndex.progress)
/// ```
internal enum OverlayZIndex {
    /// Toast messages (top-most, must be visible above all other UI)
    static let toast: Double = 60

    /// Progress indicators (blocks all interaction during operations)
    static let progress: Double = 50

    /// Modal overlays (theme creator, AI chat)
    /// These are full-screen modal experiences that should block other overlays
    static let modalOverlay: Double = 55

    /// Detail sidebar (tvOS item detail view)
    static let detailSidebar: Double = 55

    /// Theme picker overlay
    static let themePicker: Double = 54

    /// Tier list browser full-screen view
    static let browser: Double = 53

    /// Analytics sidebar (tvOS)
    static let analytics: Double = 52

    /// Quick move overlay (tvOS unified item actions)
    static let quickMove: Double = 45

    /// Standard overlays (quick rank, head-to-head, general overlays)
    static let standardOverlay: Double = 40
}
