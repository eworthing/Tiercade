#if os(tvOS)
import XCTest

class ThemePickerOverlayFocusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testFocusDoesNotEscapeOverlay() {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTest")
        app.launch()
        // Open theme picker overlay
        let themePickerButton = app.buttons["Toolbar_ThemePicker"]
        XCTAssertTrue(themePickerButton.waitForExistence(timeout: 5))
        // Use the remote to activate the button (tap is unavailable on tvOS)
        let remote = XCUIRemote.shared

        // helper declared in extension below to keep this test method short

    navigateToElement(themePickerButton, in: app, using: remote)
        // Ensure the toolbar button actually has focus before activating it
        if !waitForFocus(themePickerButton, timeout: 2) {
            // attach UI hierarchy and screenshot to help debugging
            let dump = app.debugDescription
            let dumpAttachment = XCTAttachment(string: dump)
            dumpAttachment.name = "app.debugDescription"
            dumpAttachment.lifetime = .keepAlways
            add(dumpAttachment)
            let shot = app.screenshot()
            let shotAttachment = XCTAttachment(screenshot: shot)
            shotAttachment.name = "screenshot-toolbar-focus-failure"
            shotAttachment.lifetime = .keepAlways
            add(shotAttachment)
            XCTFail("Theme picker button did not receive focus; attached debug info")
        }
        remote.press(.select)

    let overlay = app.otherElements["ThemePicker_Overlay"]
    // Give the overlay a bit more time on slower CI/simulators
    XCTAssertTrue(overlay.waitForExistence(timeout: 10))

    // Try to move focus up from the top row
        let staticTexts = app.staticTexts
        let firstLabel = staticTexts.element(boundBy: 0).label
        let firstThemeCard = app.buttons.matching(identifier: "ThemeCard_" + firstLabel).firstMatch
        XCTAssertTrue(firstThemeCard.exists)
        remote.press(.select)
        remote.press(.up)

        // Focus should remain inside overlay (on close button)
        let closeButton = app.buttons["ThemePicker_Close"]
        XCTAssertTrue(closeButton.exists)
        XCTAssertTrue(waitForFocus(closeButton))

        // Try to move focus down from the bottom row
        let lastIndex = staticTexts.count - 1
        let lastLabel = staticTexts.element(boundBy: lastIndex).label
        let lastThemeCard = app.buttons.matching(identifier: "ThemeCard_" + lastLabel).firstMatch
        XCTAssertTrue(lastThemeCard.exists)
        remote.press(.select)
        remote.press(.down)

    let resetButton = app.buttons["ThemePicker_Reset"]
    XCTAssertTrue(resetButton.exists)
    XCTAssertTrue(waitForFocus(resetButton))

        // Try to move up again from close button (should stay)
        remote.press(.select)
        remote.press(.up)
        XCTAssertTrue(waitForFocus(closeButton))
    }
}

// MARK: - Helpers

private extension XCTestCase {
    @MainActor
    func navigateToElement(
        _ el: XCUIElement,
        in app: XCUIApplication,
        using remote: XCUIRemote,
        maxAttempts: Int = 30
    ) {
        var tries = 0
        // If there's an action bar button we can use it as an anchor
    let actionBarPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "ActionBar_")
    let actionBarAnchor = app.buttons.matching(actionBarPredicate).firstMatch
        if actionBarAnchor.exists {
            // try to focus an action bar button first (press Down from content)
            while tries < 6 && !actionBarAnchor.hasFocus {
                remote.press(.down)
                RunLoop.current.run(until: Date().addingTimeInterval(0.18))
                tries += 1
            }
        }
        tries = 0
        // Prefer moving Up first (common pattern to reach top toolbar), then Right/Down/Left
        while tries < maxAttempts && !el.hasFocus {
            remote.press(.up)
            RunLoop.current.run(until: Date().addingTimeInterval(0.18))
            if el.hasFocus { break }
            remote.press(.right)
            RunLoop.current.run(until: Date().addingTimeInterval(0.14))
            if el.hasFocus { break }
            remote.press(.down)
            RunLoop.current.run(until: Date().addingTimeInterval(0.14))
            if el.hasFocus { break }
            remote.press(.left)
            RunLoop.current.run(until: Date().addingTimeInterval(0.14))
            tries += 1
        }
    }
    @MainActor
    func waitForFocus(_ el: XCUIElement, timeout: TimeInterval = 2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if el.hasFocus { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
}

#endif
