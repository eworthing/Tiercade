import XCTest

final class TvOSBasicTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_ActionBar_and_Overlays_exist() throws {
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()

        // Wait for app to fully load
        sleep(5)
        
        // First, let's see if ANY elements exist at all
        let anyElements = app.descendants(matching: .any)
        print("Total elements found: \(anyElements.count)")
        
        // Check if the app itself exists
        XCTAssertTrue(app.exists, "App should exist")
        
        // Try to find ANY element with an accessibility identifier
        let elementWithId = app.descendants(matching: .any).matching(NSPredicate(format: "identifier != ''")).firstMatch
        if elementWithId.exists {
            print("Found element with identifier: '\(elementWithId.identifier)'")
        } else {
            print("No elements with accessibility identifiers found")
        }
        
        // Let's specifically look for common SwiftUI elements
        let buttons = app.buttons
        print("Number of buttons found: \(buttons.count)")
        
        let texts = app.staticTexts
        print("Number of static texts found: \(texts.count)")
        
        let otherElements = app.otherElements
        print("Number of other elements found: \(otherElements.count)")
        
        // Now try to find the ActionBar components directly
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        let multiSelectExists = multiSelectButton.waitForExistence(timeout: 20)
        
        if multiSelectExists {
            print("Found Multi-Select button!")
        } else {
            print("Multi-Select button not found")
        }
        
        XCTAssertTrue(multiSelectExists, "Multi-Select button should appear")

    // Try to move focus to a card and open Item Menu (Select)
        let remote = XCUIRemote.shared
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        // Either ItemMenu appears or a Select triggers something else; check overlay id
        let itemMenu = app.otherElements["ItemMenu_Overlay"]
        XCTAssertTrue(itemMenu.waitForExistence(timeout: 3), "ItemMenu overlay should appear after Select on a card")

    // Assert key Item Menu buttons exist
    XCTAssertTrue(app.buttons["ItemMenu_ToggleSelection"].exists, "Toggle Selection button should exist")
    XCTAssertTrue(app.buttons["ItemMenu_ViewDetails"].exists, "View Details button should exist")
    XCTAssertTrue(app.buttons["ItemMenu_RemoveFromTier"].exists, "Remove from Tier button should exist")
    // Check a few move targets explicitly (depends on tier order)
    XCTAssertTrue(app.buttons["ItemMenu_Move_S"].exists || app.buttons["ItemMenu_Move_A"].exists, "At least one Move-to button should exist")

        // Navigate to View Details to open gallery and then back out
        if app.buttons["ItemMenu_ViewDetails"].exists {
            remote.press(.right)
            sleep(1)
            remote.press(.select)
            // Expect a gallery element
            let anyGallery = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'Gallery_Page_'")).firstMatch
            XCTAssertTrue(anyGallery.waitForExistence(timeout: 5), "Gallery should appear after View Details")
            // Return back to main view (Menu)
            remote.press(.menu)
            sleep(1)
        }
        // Ensure ItemMenu is dismissed
        remote.press(.menu)
        sleep(1)
        XCTAssertFalse(itemMenu.exists, "ItemMenu overlay should dismiss after Menu")

        // Open QuickMove via Play/Pause
        remote.press(.playPause)
        let quickMove = app.otherElements["QuickMove_Overlay"]
        XCTAssertTrue(quickMove.waitForExistence(timeout: 3), "QuickMove overlay should appear after Play/Pause on a card")

        // Assert QuickMove buttons exist
        XCTAssertTrue(app.buttons["QuickMove_S"].exists, "QuickMove S button should exist")
        XCTAssertTrue(app.buttons["QuickMove_A"].exists, "QuickMove A button should exist")
        XCTAssertTrue(app.buttons["QuickMove_B"].exists, "QuickMove B button should exist")
        XCTAssertTrue(app.buttons["QuickMove_C"].exists, "QuickMove C button should exist")

        // Dismiss QuickMove via Cancel to verify closing path
        if app.buttons["QuickMove_Cancel"].exists {
            remote.press(.right)
            sleep(1)
            remote.press(.select)
            sleep(1)
        }
        XCTAssertFalse(quickMove.exists, "QuickMove overlay should dismiss after Cancel")
    }
}
