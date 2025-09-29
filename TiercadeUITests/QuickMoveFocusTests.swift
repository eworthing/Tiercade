import XCTest

final class QuickMoveFocusTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_QuickMove_focus_traversal() throws {
        // Only run on tvOS 26 or newer (user requested 26-only testing)
        guard #available(tvOS 26.0, *) else {
            throw XCTSkip("Requires tvOS 26+")
        }
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()

        // Give the app a moment to render initial UI
        let remote = XCUIRemote.shared
        sleep(2)

        // Move focus to the first card in the first tier row
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Card_'"))
        var attempts = 0
        while attempts < 4 {
            if cards.count > 0 {
                let firstCard = cards.element(boundBy: 0)
                if firstCard.exists && firstCard.hasFocus { break }
            }
            remote.press(.down)
            usleep(200_000)
            attempts += 1
        }

    // Open Quick Move via Play/Pause on the focused card (with a quick retry)
    remote.press(.playPause)
    usleep(300_000)

        let quickMove = app.otherElements["QuickMove_Overlay"]
        XCTAssertTrue(quickMove.waitForExistence(timeout: 5), "QuickMove overlay should appear")

        let s = app.buttons["QuickMove_S"]
        let a = app.buttons["QuickMove_A"]
        let b = app.buttons["QuickMove_B"]
        let c = app.buttons["QuickMove_C"]
        let u = app.buttons["QuickMove_U"]

    // Assert default focus is on S
        XCTAssertTrue(s.waitForExistence(timeout: 3))
    XCTAssertTrue(s.hasFocus, "S should be the default focused button")

        // Move focus: right -> A, down -> B, left -> C, up -> S, down -> U
    remote.press(.right)
    XCTAssertTrue(a.waitForExistence(timeout: 3))
    usleep(200_000)
    XCTAssertTrue(a.hasFocus, "Right should move focus to A")

    remote.press(.down)
    XCTAssertTrue(b.waitForExistence(timeout: 3))
    usleep(200_000)
    XCTAssertTrue(b.hasFocus, "Down should move focus to B")

    remote.press(.left)
    XCTAssertTrue(c.waitForExistence(timeout: 3))
    usleep(200_000)
    XCTAssertTrue(c.hasFocus, "Left should move focus to C")

    remote.press(.up)
    usleep(200_000)
    XCTAssertTrue(s.hasFocus, "Up should return focus to S")

    remote.press(.down)
    XCTAssertTrue(u.waitForExistence(timeout: 3))
    usleep(200_000)
    XCTAssertTrue(u.hasFocus, "Down from hub should reach U (center-bottom)")

        // Cancel to dismiss overlay
        let cancel = app.buttons["QuickMove_Cancel"]
        if cancel.waitForExistence(timeout: 2) {
            // Move to the bottom button row if not already focused
            if !cancel.hasFocus { remote.press(.right) }
            remote.press(.select)
        } else {
            // Fallback: Menu
            remote.press(.menu)
        }

        XCTAssertFalse(quickMove.exists, "QuickMove overlay should dismiss")
    }
}
