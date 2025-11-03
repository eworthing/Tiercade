import Foundation
import SwiftUI
import Observation
import os
import TiercadeCore

/// Consolidated state for modal/overlay routing and visibility
///
/// This state object encapsulates all overlay-related state including:
/// - Detail/Quick Move modals
/// - Analytics sidebar
/// - Tier list creator/browser
/// - Theme picker
/// - Computed overlay state (active overlay, background focus blocking)
@MainActor
@Observable
internal final class OverlaysState {
    // MARK: - Item Detail & Quick Move

    /// Currently selected item for detail view (if any)
    var detailItem: Item?

    /// Target item for quick move operation (if any)
    var quickMoveTarget: Item?

    // MARK: - Tier List Management

    /// Whether the tier list creator wizard is visible
    var showTierListCreator: Bool = false

    /// Whether the tier list browser is visible
    var showTierListBrowser: Bool = false

    // MARK: - Theme Management

    /// Whether the theme picker overlay is visible
    var showThemePicker: Bool = false

    /// Whether the theme creator is visible
    var showThemeCreator: Bool = false

    // MARK: - Analytics

    /// Whether the analytics sidebar is visible (iOS/macOS sidebar or tvOS overlay)
    var showAnalyticsSidebar: Bool = false

    // MARK: - Computed State

    /// The currently active overlay type (if any)
    internal var activeOverlay: OverlayType? {
        if detailItem != nil { return .detail }
        if quickMoveTarget != nil { return .quickMove }
        if showThemePicker { return .themePicker }
        if showTierListCreator { return .tierListCreator }
        if showTierListBrowser { return .tierListBrowser }
        if showAnalyticsSidebar { return .analytics }
        return nil
    }

    /// Whether any overlay is currently blocking background focus
    internal var blocksBackgroundFocus: Bool {
        activeOverlay != nil
    }

    // MARK: - Overlay Type

    internal enum OverlayType {
        case detail
        case quickMove
        case themePicker
        case themeCreator
        case tierListCreator
        case tierListBrowser
        case analytics
    }

    // MARK: - Methods

    /// Dismisses all active overlays
    internal func dismissAllOverlays() {
        detailItem = nil
        quickMoveTarget = nil
        showThemePicker = false
        showThemeCreator = false
        showTierListCreator = false
        showTierListBrowser = false
        showAnalyticsSidebar = false
        Logger.appState.info("Dismissed all overlays")
    }

    /// Shows the detail overlay for the given item
    internal func showDetail(_ item: Item) {
        detailItem = item
    }

    /// Dismisses the detail overlay
    internal func dismissDetail() {
        detailItem = nil
    }

    /// Shows the quick move overlay for the given item
    internal func showQuickMove(_ item: Item) {
        quickMoveTarget = item
    }

    /// Dismisses the quick move overlay
    internal func dismissQuickMove() {
        quickMoveTarget = nil
    }

    /// Presents the tier list creator
    internal func presentTierListCreator() {
        showTierListCreator = true
    }

    /// Dismisses the tier list creator
    internal func dismissTierListCreator() {
        showTierListCreator = false
    }

    /// Presents the tier list browser
    internal func presentTierListBrowser() {
        showTierListBrowser = true
    }

    /// Dismisses the tier list browser
    internal func dismissTierListBrowser() {
        showTierListBrowser = false
    }

    /// Presents the theme picker
    internal func presentThemePicker() {
        showThemePicker = true
    }

    /// Dismisses the theme picker
    internal func dismissThemePicker() {
        showThemePicker = false
    }

    /// Presents the analytics sidebar
    internal func presentAnalytics() {
        showAnalyticsSidebar = true
    }

    /// Dismisses the analytics sidebar
    internal func dismissAnalytics() {
        showAnalyticsSidebar = false
    }
}
