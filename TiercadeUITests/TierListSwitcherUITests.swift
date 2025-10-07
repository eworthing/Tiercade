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
