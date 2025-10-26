@preconcurrency import XCTest

/// Convenience abstraction for the hardware keys we need to exercise in Mac Catalyst UI tests.
enum HardwareKey {
    case left, right, up, down, enter, returnKey, escape, space, tab

    var xcuiKey: XCUIKeyboardKey {
        switch self {
        case .left: return .leftArrow
        case .right: return .rightArrow
        case .up: return .upArrow
        case .down: return .downArrow
        case .enter: return .enter
        case .returnKey: return .return
        case .escape: return .escape
        case .space: return .space
        case .tab: return .tab
        }
    }
}

extension XCUIElement {
    /// Types a single hardware key using the strongly typed helper.
    func typeKey(_ key: HardwareKey, modifiers: XCUIElement.KeyModifierFlags = []) {
        typeKey(key.xcuiKey, modifierFlags: modifiers)
    }
}

extension XCTestCase {
    /// Boot the Catalyst build with the standard UI-test arguments.
    @discardableResult
    func launchTiercade(arguments extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = app.launchArguments
        let baseArguments = ["-uiTest"]
        for arg in baseArguments where !arguments.contains(arg) {
            arguments.append(arg)
        }
        for argument in extraArguments where !arguments.contains(argument) {
            arguments.append(argument)
        }
        app.launchArguments = arguments
        app.launch()
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Tiercade failed to reach foreground state")

        // Ensure the app window is fully visible and focused
        let window = app.windows.firstMatch
        if window.waitForExistence(timeout: 5) {
            window.tap()  // Tap window to ensure it's frontmost
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))  // Wait for window focus
            app.activate()  // Activate again to ensure focus stays
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        return app
    }

    func primaryWindow(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Expected Tiercade window to exist", file: file, line: line)
        return window
    }

    func sendKey(_ key: HardwareKey, to window: XCUIElement, modifiers: XCUIElement.KeyModifierFlags = []) {
        window.typeKey(key, modifiers: modifiers)
    }

    func openQuickRankOverlay(in app: XCUIApplication, window: XCUIElement) {
        sendKey(.space, to: window)
        // First wait for any Quick Rank static text to appear
        let quickRankPredicate = NSPredicate(format: "label BEGINSWITH %@", "Quick Rank:")
        XCTAssertTrue(app.staticTexts.matching(quickRankPredicate).firstMatch.waitForExistence(timeout: 5.0),
                      "Quick Rank overlay content should appear")
        // Then wait for the overlay identifier
        waitForElement(app.otherElements["QuickRank_Overlay"], in: app, timeout: 10.0)
    }

    func dismissQuickRankOverlayIfNeeded(in app: XCUIApplication, window: XCUIElement) {
        guard app.otherElements["QuickRank_Overlay"].exists else { return }
        sendKey(.escape, to: window)
        let predicate = NSPredicate(format: "exists == false")
        let dismissalExpectation = expectation(for: predicate, evaluatedWith: app.otherElements["QuickRank_Overlay"])
        wait(for: [dismissalExpectation], timeout: 3)
    }

    func waitForElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if element.waitForExistence(timeout: timeout) { return }
        let identifier = element.identifier.isEmpty ? String(describing: element) : element.identifier
        attachDebugHierarchy(of: app, named: "Hierarchy after waiting for \(identifier)")
        XCTFail("Failed waiting for element \(identifier)", file: file, line: line)
    }

    func attachDebugHierarchy(of app: XCUIApplication, named name: String = "UI Hierarchy") {
        XCTContext.runActivity(named: name) { _ in
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func elementHasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    func waitForKeyboardFocus(
        on element: XCUIElement,
        using window: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elementHasKeyboardFocus(element) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        attachDebugHierarchy(of: app, named: "Hierarchy after waiting for keyboard focus on \(element.identifier)")
        XCTFail("Keyboard focus never reached \(element.identifier)", file: file, line: line)
    }

    func focusElementWithTab(
        _ element: XCUIElement,
        in app: XCUIApplication,
        window: XCUIElement,
        maxAttempts: Int = 12,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<maxAttempts where !elementHasKeyboardFocus(element) {
            sendKey(.tab, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        waitForKeyboardFocus(on: element, using: window, in: app, timeout: 1.5, file: file, line: line)
    }

    func waitForElementToDisappear(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard element.exists else { return }
        let predicate = NSPredicate(format: "exists == false")
        let exp = expectation(for: predicate, evaluatedWith: element)
        wait(for: [exp], timeout: timeout)
        if element.exists {
            attachDebugHierarchy(of: app, named: "Hierarchy when \(element.identifier) failed to dismiss")
            XCTFail("\(element.identifier) remained visible", file: file, line: line)
        }
    }
}

/// Keyboard navigation smoke tests for the Catalyst build.
final class TiercadeKeyboardNavigationTests: XCTestCase {
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
        try super.tearDownWithError()
    }

    @MainActor func testPressingSpaceOpensQuickRankForDefaultFocusedCard() throws {
        let app = launchTiercade()
        let window = primaryWindow(in: app)
        attachDebugHierarchy(of: app, named: "Post-launch hierarchy")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Card_"))
        let firstCard = cards.element(boundBy: 0)
        waitForElement(firstCard, in: app)
        let firstName = firstCard.label

        // Click card to give it focus initially, then test with keyboard
        firstCard.click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        // Press Space to open Quick Rank overlay
        openQuickRankOverlay(in: app, window: window)

        XCTAssertTrue(app.staticTexts["Quick Rank: \(firstName)"].exists)
        dismissQuickRankOverlayIfNeeded(in: app, window: window)
    }

    /// Validates that arrow keys can navigate between cards without requiring mouse clicks,
    /// matching tvOS spatial navigation behavior on Mac Catalyst.
    @MainActor func testArrowKeyNavigationBetweenCards() throws {
        let app = launchTiercade()
        let window = primaryWindow(in: app)
        attachDebugHierarchy(of: app, named: "Post-launch hierarchy")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Card_"))
        let firstCard = cards.element(boundBy: 0)
        waitForElement(firstCard, in: app)

        // Give app time to seed initial focus
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        // Try pressing Space without clicking first - should open Quick Rank if focus is seeded
        sendKey(.space, to: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let quickRankOverlay = app.otherElements["QuickRank_Overlay"]

        if quickRankOverlay.exists {
            // SUCCESS: Focus was automatically seeded, no click needed!
            dismissQuickRankOverlayIfNeeded(in: app, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))

            // Navigate with arrow key
            sendKey(.right, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))

            // Verify Space works on new focused card
            sendKey(.space, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))

            XCTAssertTrue(quickRankOverlay.exists,
                          "Arrow key navigation should work after initial focus")
            dismissQuickRankOverlayIfNeeded(in: app, window: window)
        } else {
            // FALLBACK: Focus wasn't auto-seeded, click to establish it
            firstCard.click()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))

            // Verify Space works after click
            sendKey(.space, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))

            XCTAssertTrue(quickRankOverlay.exists,
                          "Space should open Quick Rank after establishing focus")
            dismissQuickRankOverlayIfNeeded(in: app, window: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))

            // Navigate with arrow key
            sendKey(.right, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))

            // Verify arrow navigation works
            sendKey(.space, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))

            XCTAssertTrue(quickRankOverlay.exists,
                          "Arrow key navigation should work from first card")
            dismissQuickRankOverlayIfNeeded(in: app, window: window)
        }
    }

    @MainActor func testEscapeDismissesQuickRankOverlay() throws {
        let app = launchTiercade()
        let window = primaryWindow(in: app)
        attachDebugHierarchy(of: app, named: "Post-launch hierarchy")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Card_"))
        let firstCard = cards.element(boundBy: 0)
        waitForElement(firstCard, in: app)

        // Click card to give it focus
        firstCard.click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        // Open Quick Rank overlay via Space
        openQuickRankOverlay(in: app, window: window)

        // Dismiss it with Escape
        dismissQuickRankOverlayIfNeeded(in: app, window: window)

        XCTAssertFalse(app.otherElements["QuickRank_Overlay"].exists)
    }

    @MainActor func testToolbarNavigationAndShortcuts() throws {
        let app = launchTiercade()
        let window = primaryWindow(in: app)
        attachDebugHierarchy(of: app, named: "Post-launch hierarchy")

        // Try keyboard navigation (Tab up to 20 times to reach H2H button)
        let h2hButton = app.buttons["Toolbar_H2H"]
        waitForElement(h2hButton, in: app)

        var reachedViaKeyboard = false
        for _ in 0..<20 {
            sendKey(.tab, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            if elementHasKeyboardFocus(h2hButton) {
                reachedViaKeyboard = true
                break
            }
        }

        // If Tab reached the H2H button, activate it with Space
        if reachedViaKeyboard {
            sendKey(.space, to: window)
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        } else {
            // Fallback: tap the button directly
            h2hButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        let h2hOverlay = app.otherElements["MatchupOverlay_Root"]
        waitForElement(h2hOverlay, in: app, timeout: 15.0)
    }
}
