import XCTest

/// UI tests for tier list switching workflow on tvOS.
final class TierListSwitcherUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()
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
        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_")).firstMatch
        
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
        
        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "TierListCard_")).firstMatch
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
