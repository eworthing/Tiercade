#if os(tvOS)
import XCTest

final class QuickMoveFocusTests: TiercadeTvOSUITestCase {

    @MainActor
    func test_QuickMove_focus_traversal() throws {
        // Only run on tvOS 26 or newer (user requested 26-only testing)
        guard #available(tvOS 26.0, *) else {
            throw XCTSkip("Requires tvOS 26+")
        }

    prepareApp()
    let remote = self.remote
        focusFirstCard(using: remote)

        let quickMove = openQuickMoveOverlay(using: remote)
        let buttons = fetchQuickMoveButtons()

        verifyDefaultFocus(on: buttons.s)
        verifyFocusTraversal(using: remote, buttons: buttons)
        dismissQuickMoveOverlay(using: remote, buttons: buttons, overlay: quickMove)
    }
}

private extension QuickMoveFocusTests {
    struct QuickMoveButtons {
        let s: XCUIElement
        let a: XCUIElement
        let b: XCUIElement
        let c: XCUIElement
        let u: XCUIElement
        let cancel: XCUIElement
    }

    func prepareApp() {
        if app.isRunning == false {
            launchApp(waitingFor: app.buttons["Toolbar_H2H"])
        }
    }

    func focusFirstCard(using remote: XCUIRemote) {
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Card_'"))
        var attempts = 0
        while attempts < 4 {
            guard cards.count > 0 else { break }
            let firstCard = cards.element(boundBy: 0)
            if firstCard.exists && firstCard.hasFocus { return }
            remote.press(.down)
            pause(for: 0.2)
            attempts += 1
        }
    }

    func openQuickMoveOverlay(using remote: XCUIRemote) -> XCUIElement {
        remote.press(.playPause)
        pause(for: 0.3)

        let quickMove = app.otherElements["QuickMove_Overlay"]
        XCTAssertTrue(quickMove.waitForExistence(timeout: 5), "QuickMove overlay should appear")
        return quickMove
    }

    func fetchQuickMoveButtons() -> QuickMoveButtons {
        QuickMoveButtons(
            s: app.buttons["QuickMove_S"],
            a: app.buttons["QuickMove_A"],
            b: app.buttons["QuickMove_B"],
            c: app.buttons["QuickMove_C"],
            u: app.buttons["QuickMove_U"],
            cancel: app.buttons["QuickMove_Cancel"]
        )
    }

    func verifyDefaultFocus(on button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertTrue(button.hasFocus, "S should be the default focused button")
    }

    func verifyFocusTraversal(using remote: XCUIRemote, buttons: QuickMoveButtons) {
        moveFocus(remote: remote, button: buttons.a, direction: .right, message: "Right should move focus to A")
        moveFocus(remote: remote, button: buttons.b, direction: .down, message: "Down should move focus to B")
        moveFocus(remote: remote, button: buttons.c, direction: .left, message: "Left should move focus to C")

        remote.press(.up)
        pause(for: 0.2)
        XCTAssertTrue(buttons.s.hasFocus, "Up should return focus to S")

        remote.press(.down)
        XCTAssertTrue(buttons.u.waitForExistence(timeout: 3))
        pause(for: 0.2)
        XCTAssertTrue(buttons.u.hasFocus, "Down from hub should reach U (center-bottom)")
    }

    func moveFocus(remote: XCUIRemote, button: XCUIElement, direction: XCUIRemote.Button, message: String) {
        remote.press(direction)
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        pause(for: 0.2)
        XCTAssertTrue(button.hasFocus, message)
    }

    func dismissQuickMoveOverlay(
        using remote: XCUIRemote,
        buttons: QuickMoveButtons,
        overlay: XCUIElement
    ) {
        guard buttons.cancel.waitForExistence(timeout: 2) else {
            remote.press(.menu)
            XCTAssertFalse(overlay.exists, "QuickMove overlay should dismiss")
            return
        }

        if !buttons.cancel.hasFocus {
            remote.press(.right)
        }
        remote.press(.select)
        pause(for: 0.2)
        XCTAssertFalse(overlay.exists, "QuickMove overlay should dismiss")
    }
}

#endif
