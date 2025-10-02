#if os(tvOS)
import XCTest

final class TvOSBasicTests: TiercadeTvOSUITestCase {

    @MainActor
    func test_ActionBar_and_Overlays_exist() throws {
        prepareApp()
        logElementDiagnostics()
        verifyActionBarPresence()

        let remote = XCUIRemote.shared

        openItemMenu(using: remote)
        let itemMenu = waitForItemMenuAppearance()
        verifyItemMenuButtons()
        openGalleryIfAvailable(using: remote)
        dismissItemMenu(using: remote, itemMenu: itemMenu)

        let quickMove = openQuickMove(using: remote)
        verifyQuickMoveButtons()
        dismissQuickMove(using: remote, quickMove: quickMove)
    }
}

private extension TvOSBasicTests {
    func prepareApp() {
        if app.isRunning == false {
            launchApp(waitingFor: launchAnchor)
        }
    }

    func logElementDiagnostics() {
        let allElements = app.descendants(matching: .any)
        print("Total elements found: \(allElements.count)")

        let elementWithIdentifier = allElements
            .matching(NSPredicate(format: "identifier != ''"))
            .firstMatch
        if elementWithIdentifier.exists {
            print("Found element with identifier: '\(elementWithIdentifier.identifier)'")
        } else {
            print("No elements with accessibility identifiers found")
        }

        print("Number of buttons found: \(app.buttons.count)")
        print("Number of static texts found: \(app.staticTexts.count)")
        print("Number of other elements found: \(app.otherElements.count)")
    }

    func verifyActionBarPresence() {
        XCTAssertTrue(app.exists, "App should exist")

        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        let multiSelectExists = multiSelectButton.waitForExistence(timeout: 20)
        if multiSelectExists {
            print("Found Multi-Select button!")
        } else {
            print("Multi-Select button not found")
        }
        XCTAssertTrue(multiSelectExists, "Multi-Select button should appear")
    }

    func openItemMenu(using remote: XCUIRemote) {
        remote.press(.down)
        pause(for: 1)
        remote.press(.select)
    }

    func waitForItemMenuAppearance() -> XCUIElement {
        let itemMenu = app.otherElements["ItemMenu_Overlay"]
        XCTAssertTrue(
            itemMenu.waitForExistence(timeout: 3),
            "ItemMenu overlay should appear after Select on a card"
        )
        return itemMenu
    }

    func verifyItemMenuButtons() {
        XCTAssertTrue(
            app.buttons["ItemMenu_ToggleSelection"].exists,
            "Toggle Selection button should exist"
        )
        XCTAssertTrue(
            app.buttons["ItemMenu_ViewDetails"].exists,
            "View Details button should exist"
        )
        XCTAssertTrue(
            app.buttons["ItemMenu_RemoveFromTier"].exists,
            "Remove from Tier button should exist"
        )
        XCTAssertTrue(
            app.buttons["ItemMenu_Move_S"].exists || app.buttons["ItemMenu_Move_A"].exists,
            "At least one Move-to button should exist"
        )
    }

    func openGalleryIfAvailable(using remote: XCUIRemote) {
        guard app.buttons["ItemMenu_ViewDetails"].exists else { return }
        remote.press(.right)
        pause(for: 1)
        remote.press(.select)

        let gallery = app.otherElements
            .matching(NSPredicate(format: "identifier BEGINSWITH 'Gallery_Page_'"))
            .firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 5), "Gallery should appear after View Details")

    remote.press(.menu)
    pause(for: 1)
    }

    func dismissItemMenu(using remote: XCUIRemote, itemMenu: XCUIElement) {
        remote.press(.menu)
        pause(for: 1)
        XCTAssertFalse(itemMenu.exists, "ItemMenu overlay should dismiss after Menu")
    }

    func openQuickMove(using remote: XCUIRemote) -> XCUIElement {
        remote.press(.playPause)
        let quickMove = app.otherElements["QuickMove_Overlay"]
        XCTAssertTrue(
            quickMove.waitForExistence(timeout: 3),
            "QuickMove overlay should appear after Play/Pause on a card"
        )
        return quickMove
    }

    func verifyQuickMoveButtons() {
        ["QuickMove_S", "QuickMove_A", "QuickMove_B", "QuickMove_C"].forEach { identifier in
            XCTAssertTrue(app.buttons[identifier].exists, "\(identifier) button should exist")
        }
    }

    func dismissQuickMove(using remote: XCUIRemote, quickMove: XCUIElement) {
        guard app.buttons["QuickMove_Cancel"].exists else {
            XCTAssertFalse(quickMove.exists, "QuickMove overlay should dismiss after Cancel")
            return
        }
        remote.press(.right)
        pause(for: 1)
        remote.press(.select)
        pause(for: 1)
        XCTAssertFalse(quickMove.exists, "QuickMove overlay should dismiss after Cancel")
    }
}

#endif
