import Testing
@testable import Tiercade
import TiercadeCore

/// Tests for OverlaysState
///
/// Focus on critical computed properties that determine focus blocking behavior.
/// These tests prevent regressions like the missing showThemeCreator check
/// discovered in the refactor review.
@MainActor
struct OverlaysStateTests {
    // MARK: - activeOverlay Tests

    @Test("activeOverlay returns nil when no overlays are active")
    func activeOverlay_noOverlays() {
        let state = OverlaysState()
        #expect(state.activeOverlay == nil)
    }

    @Test("activeOverlay returns detail when detailItem is set")
    func activeOverlay_detail() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])
        state.detailItem = item
        #expect(state.activeOverlay == .detail)
    }

    @Test("activeOverlay returns quickMove when quickMoveTarget is set")
    func activeOverlay_quickMove() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])
        state.quickMoveTarget = item
        #expect(state.activeOverlay == .quickMove)
    }

    @Test("activeOverlay returns themePicker when showThemePicker is true")
    func activeOverlay_themePicker() {
        let state = OverlaysState()
        state.showThemePicker = true
        #expect(state.activeOverlay == .themePicker)
    }

    @Test("activeOverlay returns themeCreator when showThemeCreator is true")
    func activeOverlay_themeCreator() {
        let state = OverlaysState()
        state.showThemeCreator = true
        #expect(state.activeOverlay == .themeCreator)
    }

    @Test("activeOverlay returns tierListCreator when showTierListCreator is true")
    func activeOverlay_tierListCreator() {
        let state = OverlaysState()
        state.showTierListCreator = true
        #expect(state.activeOverlay == .tierListCreator)
    }

    @Test("activeOverlay returns tierListBrowser when showTierListBrowser is true")
    func activeOverlay_tierListBrowser() {
        let state = OverlaysState()
        state.showTierListBrowser = true
        #expect(state.activeOverlay == .tierListBrowser)
    }

    @Test("activeOverlay returns analytics when showAnalyticsSidebar is true")
    func activeOverlay_analytics() {
        let state = OverlaysState()
        state.showAnalyticsSidebar = true
        #expect(state.activeOverlay == .analytics)
    }

    @Test("activeOverlay priority: detail > quickMove > themePicker > themeCreator")
    func activeOverlay_priority() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])

        // Set multiple overlays
        state.detailItem = item
        state.quickMoveTarget = item
        state.showThemePicker = true
        state.showThemeCreator = true

        // Detail should win
        #expect(state.activeOverlay == .detail)

        // Remove detail, quickMove should win
        state.detailItem = nil
        #expect(state.activeOverlay == .quickMove)

        // Remove quickMove, themePicker should win
        state.quickMoveTarget = nil
        #expect(state.activeOverlay == .themePicker)

        // Remove themePicker, themeCreator should win
        state.showThemePicker = false
        #expect(state.activeOverlay == .themeCreator)
    }

    // MARK: - blocksBackgroundFocus Tests

    @Test("blocksBackgroundFocus is false when no overlays are active")
    func blocksBackgroundFocus_noOverlays() {
        let state = OverlaysState()
        #expect(state.blocksBackgroundFocus == false)
    }

    @Test("blocksBackgroundFocus is true when detailItem is set")
    func blocksBackgroundFocus_detail() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])
        state.detailItem = item
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when quickMoveTarget is set")
    func blocksBackgroundFocus_quickMove() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])
        state.quickMoveTarget = item
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when showThemePicker is true")
    func blocksBackgroundFocus_themePicker() {
        let state = OverlaysState()
        state.showThemePicker = true
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when showThemeCreator is true")
    func blocksBackgroundFocus_themeCreator() {
        let state = OverlaysState()
        state.showThemeCreator = true
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when showTierListCreator is true")
    func blocksBackgroundFocus_tierListCreator() {
        let state = OverlaysState()
        state.showTierListCreator = true
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when showTierListBrowser is true")
    func blocksBackgroundFocus_tierListBrowser() {
        let state = OverlaysState()
        state.showTierListBrowser = true
        #expect(state.blocksBackgroundFocus == true)
    }

    @Test("blocksBackgroundFocus is true when showAnalyticsSidebar is true")
    func blocksBackgroundFocus_analytics() {
        let state = OverlaysState()
        state.showAnalyticsSidebar = true
        #expect(state.blocksBackgroundFocus == true)
    }

    // MARK: - Helper Methods Tests

    @Test("dismissAllOverlays clears all overlay state")
    func dismissAllOverlays() {
        let state = OverlaysState()
        let item = Item(id: "test", attributes: ["name": "Test Item"])

        // Set all overlays
        state.detailItem = item
        state.quickMoveTarget = item
        state.showThemePicker = true
        state.showThemeCreator = true
        state.showTierListCreator = true
        state.showTierListBrowser = true
        state.showAnalyticsSidebar = true

        // Dismiss all
        state.dismissAllOverlays()

        // Verify all cleared
        #expect(state.detailItem == nil)
        #expect(state.quickMoveTarget == nil)
        #expect(state.showThemePicker == false)
        #expect(state.showThemeCreator == false)
        #expect(state.showTierListCreator == false)
        #expect(state.showTierListBrowser == false)
        #expect(state.showAnalyticsSidebar == false)
        #expect(state.activeOverlay == nil)
        #expect(state.blocksBackgroundFocus == false)
    }

    @Test("presentThemeCreator sets showThemeCreator to true")
    func presentThemeCreator() {
        let state = OverlaysState()
        #expect(state.showThemeCreator == false)

        state.presentThemeCreator()
        #expect(state.showThemeCreator == true)
        #expect(state.activeOverlay == .themeCreator)
    }

    @Test("dismissThemeCreator sets showThemeCreator to false")
    func dismissThemeCreator() {
        let state = OverlaysState()
        state.showThemeCreator = true

        state.dismissThemeCreator()
        #expect(state.showThemeCreator == false)
        #expect(state.activeOverlay == nil)
    }
}
