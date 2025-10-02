import XCTest

/// Quick smoke tests to verify basic UI test setup and accessibility IDs
final class QuickSmokeTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()
        sleep(3) // Give app time to initialize
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Toolbar Accessibility Tests
    
    @MainActor
    func test_toolbar_buttons_exist() throws {
        // Verify all toolbar buttons have accessibility IDs and exist
        XCTAssertTrue(app.buttons["Toolbar_H2H"].exists, "H2H button should exist")
        XCTAssertTrue(app.buttons["Toolbar_Randomize"].exists, "Randomize button should exist")
        XCTAssertTrue(app.buttons["Toolbar_Reset"].exists, "Reset button should exist")
        XCTAssertTrue(app.buttons["Toolbar_Analytics"].exists, "Analytics button should exist")
    }
    
    @MainActor
    func test_action_bar_exists() throws {
        // Verify action bar buttons exist (no container ID because it overrides children)
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        XCTAssertTrue(multiSelectButton.waitForExistence(timeout: 5), "Multi-select button should exist")
    }
    
    @MainActor
    func test_tier_grid_exists() throws {
        // Verify at least one tier exists with cards (ScrollView with tier ID)
        let unrankedTierRow = app.scrollViews["TierRow_Unranked"]
        XCTAssertTrue(unrankedTierRow.waitForExistence(timeout: 5), "Unranked tier row should exist")
        
        // Verify cards are accessible
        let firstCard = app.buttons["Card_richard-hatch"]
        XCTAssertTrue(firstCard.exists, "First card should be accessible")
    }
}
