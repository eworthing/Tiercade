import XCTest

final class SmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Keep setUp minimal; perform app launch inside the @MainActor test method.
    }

    @MainActor
    func testSmokeRemote() throws {
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()

        // Wait for main content to appear
        let firstElement = app.otherElements.firstMatch
        XCTAssertTrue(firstElement.waitForExistence(timeout: 10), "App did not launch or UI not visible")

        // Capture a baseline screenshot
        let before = XCUIScreen.main.screenshot()
        let beforeData = before.pngRepresentation
        let beforeURL = URL(fileURLWithPath: "/tmp").appendingPathComponent("tiercade_ui_before.png")
        try beforeData.write(to: beforeURL)

        // Use XCUIRemote to simulate Apple TV remote presses
        let remote = XCUIRemote.shared
        // Try to move focus to toolbar and press H2H by accessibility id
        if app.buttons["Toolbar_H2H"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.buttons["Toolbar_H2H"].exists, "Toolbar_H2H button should exist")
            // tap() is unavailable on tvOS UI tests; use the remote to activate the focused control
            remote.press(.select)
            sleep(1)
        } else {
            // fallback to remote presses if the button isn't reachable directly
            remote.press(.right)
            sleep(1)
            remote.press(.select)
            sleep(1)
            remote.press(.down)
            sleep(1)
            remote.press(.select)
            sleep(1)
        }

        // Capture an after screenshot
        let after = XCUIScreen.main.screenshot()
        let afterData = after.pngRepresentation
        let afterURL = URL(fileURLWithPath: "/tmp")
            .appendingPathComponent("tiercade_ui_after.png")
        try afterData.write(to: afterURL)

        // Assert that H2H overlay or QuickRank overlay appeared (one of them)
        let quickRankOverlayExists = app.otherElements["QuickRank_Overlay"].exists
        let h2hFinishExists = app.buttons["H2H_Finish"].exists
        XCTAssertTrue(
            quickRankOverlayExists || h2hFinishExists,
            "Expected one of the overlays to be visible after interaction"
        )
    }
}
