#if os(tvOS)
import XCTest

/// UI tests for tier list switching workflow on tvOS.
final class TierListSwitcherUITests: TiercadeTvOSUITestCase {
    override var launchAnchor: XCUIElement {
        app.buttons["Toolbar_TierListMenu"]
    }

    // MARK: - Tier List Picker Button Tests

    func testTierListPickerButtonExists() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "Tier list picker button should exist in toolbar"
        )
    }

    func testTierListPickerShowsCurrentList() throws {
        let picker = focusTierListMenu()
        XCTAssertFalse(picker.label.isEmpty, "Tier list picker should display a list name")
    }

    // MARK: - Browser Overlay Tests

    func testClickingPickerOpensBrowser() throws {
        let browser = openTierListBrowser()
        XCTAssertTrue(browser.isVisible, "Browser overlay should appear after opening the picker")
        dismissBrowserIfNeeded(handle: browser)
    }

    func testBrowserShowsBundledSection() throws {
        let browser = openTierListBrowser()

        let bundledHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "BUNDLED")
        ).firstMatch

        XCTAssertTrue(
            bundledHeader.waitForExistence(timeout: 2),
            "Browser should show Bundled Library section"
        )

        dismissBrowserIfNeeded(handle: browser)
    }

    func testBrowserShowsRecentSectionAfterSelection() throws {
        _ = selectBundledTierList(at: 0)

        let browser = openTierListBrowser()
        let recentHeader = app.staticTexts.matching(
            NSPredicate(format: "label ==[c] %@", "RECENT")
        ).firstMatch

        XCTAssertTrue(
            recentHeader.waitForExistence(timeout: 2),
            "Browser should surface a RECENT section after a selection"
        )

        dismissBrowserIfNeeded(handle: browser)
    }

    func testBrowserHasCloseButton() throws {
        let browser = openTierListBrowser()

        XCTAssertTrue(
            waitUntil(timeout: 2) { browser.closeButton.exists },
            "Browser should expose a Close button"
        )

        dismissBrowserIfNeeded(handle: browser)
    }

    func testClosingBrowserDismissesOverlay() throws {
        let browser = openTierListBrowser()
        _ = focusCloseButton()

        remote.press(.select)
        pause(for: 0.6)

        XCTAssertTrue(
            waitUntil(timeout: 2) { !browser.isVisible },
            "Browser overlay should be dismissed after activating Close"
        )
    }

    // MARK: - Tier List Selection Tests

    func testSelectingBundledListLoadsIt() throws {
        let selection = selectBundledTierList(at: 0)

        XCTAssertTrue(
            app.buttons["Toolbar_TierListMenu"].exists,
            "Toolbar should remain visible after switching tier lists"
        )

        assertToolbarDisplays(selection.label)
    }

    func testActiveListIsMarkedInBrowser() throws {
        let selection = selectBundledTierList(at: 0)

        let browser = openTierListBrowser()
        let selectedCard = app.buttons[selection.identifier]
        XCTAssertTrue(
            waitUntil(timeout: 3) { selectedCard.exists },
            "Previously selected card should surface when re-opening the browser"
        )

    let activeBadge = selectedCard.descendants(matching: .staticText)["Currently active tier list"]

        XCTAssertTrue(
            waitUntil(timeout: 3) { activeBadge.exists },
            "Active tier list should be marked with an accessibility label"
        )

        dismissBrowserIfNeeded(handle: browser)
    }

    // MARK: - Focus Management Tests

    func testPickerButtonIsFocusable() throws {
        let picker = focusTierListMenu()
        waitForFocus(on: picker)
    }

    func testBrowserCardsAreFocusable() throws {
    let browser = openTierListBrowser()
        let firstCard = focusFirstBrowserCard()
        waitForFocus(on: firstCard)
        dismissBrowserIfNeeded(handle: browser)
    }

    // MARK: - Integration with Main App

    func testSwitchingListsUpdatesMainView() throws {
        let selection = selectBundledTierList(at: 0)

        assertToolbarDisplays(selection.label)
    }

    // MARK: - Performance Tests

    func testBrowserOpensQuickly() throws {
        _ = focusTierListMenu()

        measure {
            let browser = openTierListBrowser()
            XCTAssertTrue(browser.isVisible)
            _ = focusCloseButton()
            remote.press(.select)
            pause(for: 0.6)
            XCTAssertTrue(waitUntil(timeout: 1.5) { !browser.isVisible })
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func focusTierListMenu(timeout: TimeInterval = 5) -> XCUIElement {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: timeout), "Tier list picker should exist")

        if picker.hasFocus {
            return picker
        }

        for _ in 0..<4 where !picker.hasFocus {
            remote.press(.up)
            pause(for: 0.25)
        }

        var attempts = 0
        while !picker.hasFocus && attempts < 12 {
            remote.press(.right)
            pause(for: 0.25)
            attempts += 1
        }

        attempts = 0
        while !picker.hasFocus && attempts < 12 {
            remote.press(.left)
            pause(for: 0.25)
            attempts += 1
        }

        waitForFocus(on: picker, timeout: 2)
        return picker
    }

    @discardableResult
    private func openTierListBrowser(timeout: TimeInterval = 4) -> TierListBrowserHandle {
        _ = focusTierListMenu()

    let overlay = tierListBrowserOverlay
    let closeButton = app.buttons["TierListBrowser_CloseButton"]
        let firstCard = bundledCardsQuery.firstMatch

        if !(overlay.exists || closeButton.exists || firstCard.exists) {
            remote.press(.select)
            pause(for: 0.6)
        }

        let appeared = waitUntil(timeout: timeout) {
            overlay.exists || closeButton.exists || firstCard.exists
        }

        XCTAssertTrue(appeared, "Browser overlay should appear")

        return TierListBrowserHandle(
            overlay: overlay,
            closeButton: closeButton,
            firstCard: firstCard
        )
    }

    @discardableResult
    private func selectBundledTierList(at index: Int) -> (label: String, identifier: String) {
        let browser = openTierListBrowser()
        let card = focusBundledCard(at: index)
        let rawLabel = card.staticTexts.firstMatch.label.isEmpty
            ? card.label
            : card.staticTexts.firstMatch.label
        let label = rawLabel.components(separatedBy: "\n").first ?? rawLabel
        let selection = (label: label, identifier: card.identifier)

        remote.press(.select)
        pause(for: 1.0)

        XCTAssertTrue(
            waitUntil(timeout: 2) { !browser.isVisible },
            "Browser should close after making a selection"
        )

        return selection
    }

    @discardableResult
    private func focusFirstBrowserCard() -> XCUIElement {
        focusBundledCard(at: 0)
    }

    @discardableResult
    private func focusBundledCard(at index: Int) -> XCUIElement {
        let cards = bundledCardsQuery
        XCTAssertGreaterThan(cards.count, index, "Expected to find card at index \(index)")

        let firstCard = cards.element(boundBy: 0)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 2))

        if !firstCard.hasFocus {
            remote.press(.down)
            pause(for: 0.2)
        }

        waitForFocus(on: firstCard, timeout: 2)

        if index == 0 {
            return firstCard
        }

        let targetCard = cards.element(boundBy: index)
        var attempts = 0
        while !targetCard.hasFocus && attempts < max(8, index + 4) {
            remote.press(.right)
            pause(for: 0.25)
            attempts += 1
        }

        waitForFocus(on: targetCard, timeout: 2)
        return targetCard
    }

    @discardableResult
    private func focusCloseButton() -> XCUIElement {
        let closeButton = app.buttons["TierListBrowser_CloseButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button should exist")

        if closeButton.hasFocus {
            return closeButton
        }

        for _ in 0..<20 where !closeButton.hasFocus {
            remote.press(.up)
            pause(for: 0.15)
        }

        if !closeButton.hasFocus {
            remote.press(.left)
            pause(for: 0.15)
            for _ in 0..<10 where !closeButton.hasFocus {
                remote.press(.up)
                pause(for: 0.15)
            }
        }

        XCTAssertTrue(
            waitUntil(timeout: 2.5) { closeButton.hasFocus },
            "Close button should receive focus"
        )

        return closeButton
    }

    private func dismissBrowserIfNeeded(handle: TierListBrowserHandle? = nil) {
        let overlay = handle?.overlay ?? tierListBrowserOverlay
        let closeButton = handle?.closeButton ?? app.buttons["TierListBrowser_CloseButton"]
        guard overlay.exists || closeButton.exists else { return }
        remote.press(.menu)
        pause(for: 0.6)
        _ = waitUntil(timeout: 1.5) { !(overlay.exists || closeButton.exists) }
    }

    private var bundledCardsQuery: XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_")
        )
    }

    private var tierListBrowserOverlay: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "TierListBrowser_Overlay")
            .firstMatch
    }

    private func assertToolbarDisplays(_ label: String, timeout: TimeInterval = 3) {
        let didAppear = waitUntil(timeout: timeout) { [self] in
            let primary = app.staticTexts["Toolbar_TierListMenu_Title"]
            return (primary.exists && primary.label == label) ||
                app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", label)
                ).firstMatch.exists
        }

        XCTAssertTrue(didAppear, "Toolbar should display \(label)")
    }

    @MainActor
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 3,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }

    @MainActor
    private struct TierListBrowserHandle {
        let overlay: XCUIElement
        let closeButton: XCUIElement
        let firstCard: XCUIElement

        var isVisible: Bool {
            overlay.exists || closeButton.exists || firstCard.exists
        }
    }
}

#endif
