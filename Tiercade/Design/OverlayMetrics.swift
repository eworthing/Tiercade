import Foundation

// MARK: - OverlayMetrics

/// Design tokens for overlay dimensions and spacing
public enum OverlayMetrics {
    // MARK: - Quick Move Overlay

    public static let quickMoveMinWidth: CGFloat = 960
    public static let quickMoveMinWidthNonTVOS: CGFloat = 860

    // MARK: - Theme Library Overlay

    public static let themeGridMaxHeight: CGFloat = 640
    public static let themeContainerMaxWidth: CGFloat = 1180
}

// MARK: - OpacityTokens

/// Design tokens for opacity values throughout the app
public enum OpacityTokens {
    /// Background scrim opacity (behind modals/overlays)
    public static let scrim: Double = 0.65

    /// Solid container background opacity
    public static let containerBackground: Double = 0.85

    /// Divider line opacity
    public static let divider: Double = 0.3

    /// Tint opacity when element has focus
    public static let focusedTint: Double = 0.36

    /// Tint opacity when element is unfocused
    public static let unfocusedTint: Double = 0.24
}

// MARK: - SpacingTokens

/// Design tokens for spacing and padding
public enum SpacingTokens {
    /// Standard overlay padding
    public static let overlayPadding: CGFloat = 32

    /// Vertical spacing between overlay sections
    public static let verticalSpacing: CGFloat = 28

    /// Horizontal padding within overlay content
    public static let horizontalPadding: CGFloat = 24
}
