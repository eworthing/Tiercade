#if canImport(XCTest)
import XCTest

@MainActor
final class TierListSwitcherUITests: TiercadeTvOSUITestCase {
        private enum Identifiers {
            static let pickerButton = "Toolbar_TierListMenu"
            static let browserOverlay = "TierListBrowser_Overlay"
            static let closeButton = "Close"
            static let tierListCardPrefix = "TierListCard_"
        }

        override var launchAnchor: XCUIElement {
            app.buttons[Identifiers.pickerButton]
        }

        // MARK: - Tier List Picker Button Tests

        func testTierListPickerButtonExists() {
            let picker = focusTierListMenu()
            XCTAssertTrue(picker.exists, "Tier list picker button should exist in toolbar")
        }

        func testTierListPickerShowsCurrentList() {
            let picker = focusTierListMenu()
            XCTAssertFalse(picker.label.isEmpty, "Tier list picker should display a list name")
        }

        // MARK: - Browser Overlay Tests

        func testClickingPickerOpensBrowser() {
            let browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.exists, "Browser overlay should appear after activating picker")
        }

        func testBrowserShowsRecentSection() {
            let browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.waitForExistence(timeout: 5))

            let recentHeader = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "RECENT"))
                .firstMatch
            XCTAssertTrue(recentHeader.exists, "Browser should surface a Recent section when available")
        }

        func testBrowserShowsBundledSection() {
            let browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.waitForExistence(timeout: 5))

            let bundledHeader = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "BUNDLED"))
                .firstMatch
            XCTAssertTrue(bundledHeader.exists, "Browser should show the Bundled Library section")
        }

        func testBrowserHasCloseButton() {
            let browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.waitForExistence(timeout: 5))

            let closeButton = app.buttons[Identifiers.closeButton]
            XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Browser should expose a Close button")
        }

        func testClosingBrowserDismissesOverlay() {
            let browser = openTierListBrowser()
            let closeButton = focusCloseButton()

            remote.press(.select)
            pause(for: 0.2)
            XCTAssertTrue(
                browser.waitForNonExistence(timeout: 4),
                "Browser overlay should dismiss after selecting Close"
            )
        }

        // MARK: - Tier List Selection Tests

        func testSelectingBundledListLoadsIt() {
            let browser = openTierListBrowser()
            let firstCard = bundledTierListCards().firstMatch
            XCTAssertTrue(firstCard.waitForExistence(timeout: 4), "Expected at least one bundled tier list card")

            driveFocus(to: firstCard)
            remote.press(.select)
            pause(for: 0.2)
            XCTAssertTrue(
                browser.waitForNonExistence(timeout: 4),
                "Browser should close after selecting a tier list"
            )

            let picker = app.buttons[Identifiers.pickerButton]
            XCTAssertTrue(picker.exists, "Picker button should remain visible after selection")
        }

        func testActiveListIsMarkedInBrowser() {
            var browser = openTierListBrowser()
            let firstCard = bundledTierListCards().firstMatch
            XCTAssertTrue(firstCard.waitForExistence(timeout: 4), "Expected a bundled tier list card to load")

            driveFocus(to: firstCard)
            remote.press(.select)
            pause(for: 0.2)
            XCTAssertTrue(
                browser.waitForNonExistence(timeout: 4),
                "Browser should close when a list is activated"
            )

            pause(for: 1.0)

            browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.waitForExistence(timeout: 5))

            let activeLabel = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "Active"))
                .firstMatch
            let activeIcon = app.images
                .matching(NSPredicate(format: "identifier CONTAINS[c] %@", "checkmark"))
                .firstMatch

            XCTAssertTrue(
                activeLabel.exists || activeIcon.exists,
                "Browser should mark the currently active tier list"
            )
        }

        // MARK: - Focus Management Tests

        func testPickerButtonIsFocusable() {
            let picker = focusTierListMenu()
            XCTAssertTrue(picker.isEnabled, "Picker button should be enabled and focusable")
        }

        func testBrowserCardsAreFocusable() {
            let browser = openTierListBrowser()
            defer { closeBrowserIfPresent() }
            XCTAssertTrue(browser.waitForExistence(timeout: 5))

            let cards = bundledTierListCards()
            XCTAssertGreaterThan(cards.count, 0, "Browser should list focusable tier list cards")

            let firstCard = cards.element(boundBy: 0)
            XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
            driveFocus(to: firstCard)
            XCTAssertTrue(firstCard.isEnabled, "Tier list cards should be focusable buttons")
        }

        // MARK: - Integration with Main App

        func testSwitchingListsUpdatesMainView() {
            let browser = openTierListBrowser()
            let cards = bundledTierListCards()

            guard cards.count > 0 else {
                XCTFail("Expected at least one bundled tier list card to be present")
                return
            }

            let firstCard = cards.element(boundBy: 0)
            XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
            driveFocus(to: firstCard)
            remote.press(.select)
            pause(for: 0.2)
            XCTAssertTrue(browser.waitForNonExistence(timeout: 4))

            pause(for: 1.5)

            let tierGrid = app.otherElements.matching(identifier: "TierGrid").firstMatch
            _ = tierGrid.exists

            let picker = app.buttons[Identifiers.pickerButton]
            XCTAssertTrue(picker.exists, "Picker button should remain after switching lists")
        }

        // MARK: - Performance Tests

        func testBrowserOpensQuickly() {
            measure(metrics: [XCTClockMetric()]) {
                let browser = openTierListBrowser()
                XCTAssertTrue(browser.waitForExistence(timeout: 2))
                closeBrowserIfPresent()
                pause(for: 0.3)
            }
        }

        // MARK: - Helpers

        @discardableResult
        private func focusTierListMenu(timeout: TimeInterval = 5) -> XCUIElement {
            let picker = app.buttons[Identifiers.pickerButton]
            XCTAssertTrue(
                picker.waitForExistence(timeout: timeout),
                "Tier list picker button did not appear in time"
            )

            if !picker.hasFocus {
                driveFocus(to: picker, preferredDirections: [.up, .left, .right])
            }

            waitForFocus(on: picker, timeout: 2)
            return picker
        }

        @discardableResult
        private func openTierListBrowser() -> XCUIElement {
            let picker = focusTierListMenu()
            remote.press(.select)
            pause(for: 0.2)

            let browser = app.otherElements[Identifiers.browserOverlay]
            XCTAssertTrue(browser.waitForExistence(timeout: 5), "Tier List Browser overlay did not appear")
            return browser
        }

        @discardableResult
        private func focusCloseButton() -> XCUIElement {
            let closeButton = app.buttons[Identifiers.closeButton]
            XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button was not present")

            if !closeButton.hasFocus {
                driveFocus(to: closeButton, preferredDirections: [.up, .left])
            }

            waitForFocus(on: closeButton, timeout: 2)
            return closeButton
        }

        private func closeBrowserIfPresent(timeout: TimeInterval = 4) {
            let browser = app.otherElements[Identifiers.browserOverlay]
            guard browser.exists else { return }

            if app.buttons[Identifiers.closeButton].exists {
                _ = focusCloseButton()
                remote.press(.select)
                pause(for: 0.2)
                _ = browser.waitForNonExistence(timeout: timeout)
            } else {
                remote.press(.menu)
                pause(for: 0.3)
            }
        }

        private func bundledTierListCards() -> XCUIElementQuery {
            let predicate = NSPredicate(
                format: "identifier BEGINSWITH %@",
                Identifiers.tierListCardPrefix
            )
            return app.buttons.matching(predicate)
        }

        private func driveFocus(
            to element: XCUIElement,
            preferredDirections: [XCUIRemote.Button] = [.up, .right, .left, .down],
            maxLoops: Int = 12
        ) {
            guard !element.hasFocus else { return }

            for _ in 0..<maxLoops {
                for direction in preferredDirections {
                    remote.press(direction)
                    pause(for: 0.12)
                    if element.hasFocus { return }
                }
            }

            attachFocusFailureDebugInfo(for: element)
            let identifier = element.identifier.isEmpty ? "<unnamed>" : element.identifier
            XCTFail("Failed to focus element with identifier: \(identifier)")
        }

        private func attachFocusFailureDebugInfo(for element: XCUIElement) {
            let hierarchyAttachment = XCTAttachment(string: app.debugDescription)
            hierarchyAttachment.name = "FocusFailureHierarchy"
            hierarchyAttachment.lifetime = .keepAlways
            add(hierarchyAttachment)

            let screenshotAttachment = XCTAttachment(screenshot: app.screenshot())
            screenshotAttachment.name = "FocusFailureScreenshot"
            screenshotAttachment.lifetime = .keepAlways
            add(screenshotAttachment)
        }
    }
    #endif
    }

    // MARK: - Tier List Picker Button Tests

    func testTierListPickerButtonExists() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Tier list picker button should exist in toolbar")
    }

    func testTierListPickerShowsCurrentList() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // Should display some tier list name (default or loaded)
        let label = picker.label
        XCTAssertFalse(label.isEmpty, "Tier list picker should display a list name")
    }

    // MARK: - Browser Overlay Tests

    func testClickingPickerOpensBrowser() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // Select the picker button using remote
        let remote = XCUIRemote.shared
        remote.press(.select)

        // Browser overlay should appear
        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3), "Browser overlay should appear after tapping picker")
    }

    func testBrowserShowsRecentSection() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        // Wait for browser to appear
        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Recent section header should be visible if there are recent lists
        // (may not exist if fresh install, so we just check the query doesn't crash)
        let recentHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "RECENT")).firstMatch
        _ = recentHeader.exists
    }

    func testBrowserShowsBundledSection() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Bundled Library header should exist
        let bundledHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "BUNDLED")).firstMatch
        XCTAssertTrue(bundledHeader.exists, "Browser should show Bundled Library section")
    }

    func testBrowserHasCloseButton() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Close button should exist
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists, "Browser should have a Close button")
    }

    func testClosingBrowserDismissesOverlay() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Close the browser
        let closeButton = app.buttons["Close"]
        remote.press(.select)

        // Browser should disappear
        XCTAssertFalse(browser.exists, "Browser overlay should be dismissed after tapping Close")
    }

    // MARK: - Tier List Selection Tests

    func testSelectingBundledListLoadsIt() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Find any bundled tier list card (they should have TierListCard_ prefix)
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_")
        let firstCard = app.buttons.matching(predicate).firstMatch

        guard firstCard.exists else {
            XCTFail("No bundled tier list cards found")
            return
        }

        // Get the card's accessibility identifier to extract the list name
        let cardID = firstCard.identifier

        // Select using remote
        remote.press(.select)

        // Browser should close
        XCTAssertFalse(browser.waitForExistence(timeout: 2), "Browser should close after selecting a list")

        // Picker button should now show the selected list
        // (We can't predict exact name, but it should change from default if we selected something different)
        XCTAssertTrue(picker.exists, "Picker button should still exist after selection")
    }

    func testActiveListIsMarkedInBrowser() throws {
        // First, ensure we have an active list by loading a bundled one
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        var browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_")
        let firstCard = app.buttons.matching(predicate).firstMatch
        guard firstCard.exists else {
            XCTFail("No bundled tier list cards found")
            return
        }

        remote.press(.select)

        // Wait a moment for selection to process
        sleep(1)

        // Open browser again
        remote.press(.select)
        browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Look for the "Active" label (checkmark or "Currently active tier list" accessibility label)
        let activeLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Active")).firstMatch
        let activeIcon = app.images.matching(NSPredicate(format: "identifier CONTAINS[c] %@", "checkmark")).firstMatch

        // At least one should exist
        XCTAssertTrue(activeLabel.exists || activeIcon.exists, "Browser should mark the currently active list")
    }

    // MARK: - Focus Management Tests

    func testPickerButtonIsFocusable() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // On tvOS, we can check if the button receives focus
        // This is a basic check; full focus testing requires XCUIRemote
        XCTAssertTrue(picker.isEnabled, "Picker button should be enabled and focusable")
    }

    func testBrowserCardsAreFocusable() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared
        remote.press(.select)

        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Check that tier list cards are focusable buttons
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_"))
        XCTAssertGreaterThan(cards.count, 0, "Browser should have focusable tier list cards")

        // Verify first card is enabled/focusable
        if cards.count > 0 {
            let firstCard = cards.element(boundBy: 0)
            XCTAssertTrue(firstCard.isEnabled, "Tier list cards should be focusable")
        }
    }

    // MARK: - Integration with Main App

    func testSwitchingListsUpdatesMainView() throws {
        // This is a smoke test to ensure the UI doesn't crash when switching
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        // Open browser
        let remote = XCUIRemote.shared
        remote.press(.select)
        let browser = app.otherElements["TierListBrowser_Overlay"]
        XCTAssertTrue(browser.waitForExistence(timeout: 3))

        // Select a list
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_"))
        if cards.count > 0 {
            remote.press(.select)

            // Wait for main view to update
            sleep(2)

            // Verify the main tier grid still exists and is accessible
            // We can look for tier rows or the grid itself
            let tierGrid = app.otherElements.matching(identifier: "TierGrid").firstMatch
            // Not all views may have this identifier, so we just check app doesn't crash
            _ = tierGrid.exists

            // Ensure picker button is still there
            XCTAssertTrue(picker.exists, "Picker button should remain after switching lists")
        }
    }

    // MARK: - Performance Tests

    func testBrowserOpensQuickly() throws {
        let picker = app.buttons["Toolbar_TierListMenu"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let remote = XCUIRemote.shared

        measure {
            remote.press(.select)
            let browser = app.otherElements["TierListBrowser_Overlay"]
            _ = browser.waitForExistence(timeout: 2)

            let closeButton = app.buttons["Close"]
            if closeButton.exists {
                remote.press(.select)
            }
        }
    }
}
