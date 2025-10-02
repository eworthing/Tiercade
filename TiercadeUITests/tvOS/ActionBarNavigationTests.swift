import XCTest

/// Test ActionBar visibility after navigating to it
/// The ActionBar might not be in the initial focus path
final class ActionBarNavigationTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()
        sleep(5)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    func test_navigate_down_to_action_bar() throws {
        // Try navigating down from the main content to reach the ActionBar
        let remote = XCUIRemote.shared
        
        // Navigate down multiple times to try to reach action bar
        for attempt in 1...15 {
            sleep(1)
            remote.press(.down)
            
            // Check if multiselect button is now accessible
            let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
            if multiSelectButton.exists {
                XCTAssertTrue(true, "✅ Found ActionBar_MultiSelect after \(attempt) down presses")
                return
            }
        }
        
        // If we get here, we never found it
        XCTFail("Could not find ActionBar_MultiSelect even after navigating down 15 times")
    }
    
    @MainActor
    func test_action_bar_exists_without_navigation() throws {
        // Check if action bar is in hierarchy without navigation
        // This test documents whether the element is accessible at all
        
        let actionBar = app.otherElements["ActionBar"]
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        
        // Wait a bit for UI to settle
        sleep(3)
        
        let actionBarExists = actionBar.exists
        let buttonExists = multiSelectButton.exists
        
        // Document what we find
        if !actionBarExists && !buttonExists {
            XCTFail("""
                Neither ActionBar container nor MultiSelect button are visible in UI hierarchy.
                This suggests the ActionBar may be:
                1. Below the fold and requires scrolling/navigation
                2. Disabled or hidden by modal overlay
                3. Not rendered until focused
                4. Using wrong element type for query
                """)
        } else if actionBarExists && !buttonExists {
            XCTFail("ActionBar container exists but MultiSelect button doesn't")
        } else if !actionBarExists && buttonExists {
            XCTAssertTrue(true, "MultiSelect button exists even though container doesn't")
        } else {
            XCTAssertTrue(true, "✅ Both ActionBar and MultiSelect button exist")
        }
    }
    
    @MainActor
    func test_check_if_action_bar_disabled() throws {
        // Check if ActionBar might be disabled
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        
        if multiSelectButton.exists {
            let isEnabled = multiSelectButton.isEnabled
            XCTAssertTrue(
                isEnabled,
                "MultiSelect button exists but is disabled"
            )
        } else {
            // Try finding the button by different means
            let allButtons = app.buttons
            var foundMultiSelect = false
            
            // Check first 30 buttons
            for i in 0..<min(30, allButtons.count) {
                let button = allButtons.element(boundBy: i)
                if button.exists {
                    let label = button.label
                    if label.localizedCaseInsensitiveContains("multi") || 
                       label.localizedCaseInsensitiveContains("select") {
                        foundMultiSelect = true
                        XCTFail("""
                            Found button with 'multi/select' in label at index \(i):
                            Label: '\(label)'
                            Identifier: '\(button.identifier)'
                            Enabled: \(button.isEnabled)
                            """)
                        break
                    }
                }
            }
            
            if !foundMultiSelect {
                XCTFail("MultiSelect button not found in first 30 buttons")
            }
        }
    }
}
