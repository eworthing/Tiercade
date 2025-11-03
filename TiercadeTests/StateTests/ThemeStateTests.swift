import Testing
@testable import Tiercade
import TiercadeCore

/// Tests for ThemeState
///
/// Focus on the theme application logic that maps tier order to colors.
/// Ensures correct color assignment and fallback behavior.
@MainActor
internal struct ThemeStateTests {
    // MARK: - Test Helpers

    internal func makeMockCatalog() -> MockThemeCatalog {
        MockThemeCatalog()
    }

    internal func makeTestTheme() -> TierTheme {
        TierTheme(
            slug: "test",
            displayName: "Test Theme",
            shortDescription: "A test theme",
            colorS: "#FF0000",
            colorA: "#FF8800",
            colorB: "#FFFF00",
            colorC: "#00FF00",
            colorD: "#0088FF",
            colorF: "#0000FF",
            unrankedColorHex: "#888888"
        )
    }

    // MARK: - applyTheme Tests

    @Test("applyTheme maps tier order to theme colors correctly")
    internal func applyTheme_mapsColorsCorrectly() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()
        internal let tierOrder = ["S", "A", "B", "C", "D", "F"]

        internal let colors = state.applyTheme(theme, to: tierOrder)

        #expect(colors["S"] == "#FF0000")
        #expect(colors["A"] == "#FF8800")
        #expect(colors["B"] == "#FFFF00")
        #expect(colors["C"] == "#00FF00")
        #expect(colors["D"] == "#0088FF")
        #expect(colors["F"] == "#0000FF")
        #expect(colors["unranked"] == "#888888")
    }

    @Test("applyTheme updates selectedTheme and selectedThemeID")
    internal func applyTheme_updatesSelection() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()
        internal let tierOrder = ["S", "A", "B"]

        _ = state.applyTheme(theme, to: tierOrder)

        #expect(state.selectedTheme.slug == "test")
        #expect(state.selectedThemeID == theme.id)
    }

    @Test("applyTheme handles custom tier order")
    internal func applyTheme_customTierOrder() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()
        internal let tierOrder = ["Best", "Good", "Okay"]

        internal let colors = state.applyTheme(theme, to: tierOrder)

        // Should use fallback index since tier names don't match
        #expect(colors["Best"] != nil)
        #expect(colors["Good"] != nil)
        #expect(colors["Okay"] != nil)
        #expect(colors["unranked"] == "#888888")
    }

    @Test("applyTheme handles empty tier order")
    internal func applyTheme_emptyTierOrder() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()
        internal let tierOrder: [String] = []

        internal let colors = state.applyTheme(theme, to: tierOrder)

        #expect(colors["unranked"] == "#888888")
        #expect(colors.count == 1)
    }

    // MARK: - availableThemes Tests

    @Test("availableThemes includes bundled and custom themes")
    internal func availableThemes() async {
        internal let catalog = makeMockCatalog()
        internal let bundledTheme = TierTheme(
            slug: "bundled",
            displayName: "Bundled",
            shortDescription: "Bundled theme"
        )
        internal let customTheme = TierTheme(
            slug: "custom",
            displayName: "Custom",
            shortDescription: "Custom theme"
        )

        await catalog.mockThemes(bundled: [bundledTheme], custom: [customTheme])
        internal let state = ThemeState(themeCatalog: catalog)
        state.customThemes = [customTheme]

        internal let available = state.availableThemes

        #expect(available.count >= 2)
        #expect(available.contains { $0.slug == "custom" })
    }

    // MARK: - customThemeIDs Tests

    @Test("customThemeIDs tracks added custom themes")
    internal func customThemeIDs() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()

        #expect(state.customThemeIDs.isEmpty)

        state.customThemes.append(theme)
        state.customThemeIDs.insert(theme.id)

        #expect(state.customThemeIDs.contains(theme.id))
        #expect(state.customThemeIDs.count == 1)
    }

    // MARK: - themeDraft Tests

    @Test("themeDraft can be set and cleared")
    internal func themeDraft() async {
        internal let catalog = makeMockCatalog()
        internal let state = ThemeState(themeCatalog: catalog)
        internal let theme = makeTestTheme()
        internal let tierOrder = ["S", "A", "B"]
        internal let draft = ThemeDraft(baseTheme: theme, tierOrder: tierOrder)

        #expect(state.themeDraft == nil)

        state.setThemeDraft(draft)
        #expect(state.themeDraft != nil)
        #expect(state.themeDraft?.displayName == theme.displayName)

        state.clearThemeDraft()
        #expect(state.themeDraft == nil)
    }
}
