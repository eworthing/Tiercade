import Foundation

/// Focus management workarounds for SwiftUI platform differences.
///
/// SwiftUI's accessibility tree registration and focus system have platform-specific
/// timing behaviors that require explicit delays to ensure correct focus assignment.
internal enum FocusWorkarounds {
    /// Delay before reasserting focus on non-tvOS platforms.
    ///
    /// Required because SwiftUI's accessibility tree registration is asynchronous.
    /// Without this delay, `.focused($binding)` attempts to set focus before the overlay
    /// appears in the accessibility hierarchy, causing focus to silently fail.
    ///
    /// **Platform context:**
    /// - tvOS: Focus system is synchronous; no delay needed
    /// - iOS/macOS: Accessibility tree updates asynchronously; requires delay
    ///
    /// **Usage pattern:**
    /// ```swift
    /// #if !os(tvOS)
    /// Task { @MainActor in
    ///     try? await Task.sleep(for: FocusWorkarounds.reassertDelay)
    ///     if overlayStillVisible {
    ///         overlayHasFocus = true
    ///     }
    /// }
    /// #endif
    /// ```
    ///
    /// See: `OVERLAY_ACCESSIBILITY_PATTERN.md` for full pattern documentation.
    static let reassertDelay: Duration = .milliseconds(50)
}
