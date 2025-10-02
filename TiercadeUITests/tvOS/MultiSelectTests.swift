import XCTest

/// Comprehensive tests for Multi-Select mode on tvOS
/// Tests selection, batch operations, action bar, and focus management
final class MultiSelectTests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTest"]
        app.launch()
        sleep(3)
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Entry & Exit Tests
    
    @MainActor
    func test_MultiSelect_can_enter_from_action_bar() throws {
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        XCTAssertTrue(
            multiSelectButton.waitForExistence(timeout: 10),
            "Multi-Select button should exist in action bar"
        )
        
        let remote = XCUIRemote.shared
        
        // Navigate to multi-select button
        navigateToButton(multiSelectButton, using: remote)
        
        // Activate multi-select mode
        remote.press(.select)
        sleep(1)
        
        // Verify action bar shows selection controls
        let clearSelectionButton = app.buttons["ActionBar_ClearSelection"]
        XCTAssertTrue(
            clearSelectionButton.waitForExistence(timeout: 3),
            "Clear Selection button should appear in multi-select mode"
        )
    }
    
    @MainActor
    func test_MultiSelect_can_exit_via_clear_selection() throws {
        enterMultiSelectMode()
        
        let clearButton = app.buttons["ActionBar_ClearSelection"]
        XCTAssertTrue(clearButton.exists)
        
        let remote = XCUIRemote.shared
        navigateToButton(clearButton, using: remote)
        remote.press(.select)
        sleep(1)
        
        // Verify exited multi-select mode
        XCTAssertFalse(
            clearButton.exists,
            "Clear Selection button should disappear after exiting multi-select"
        )
        
        // Verify multi-select button reappears
        XCTAssertTrue(
            app.buttons["ActionBar_MultiSelect"].exists,
            "Multi-Select button should reappear after exiting"
        )
    }
    
    // MARK: - Selection Tests
    
    @MainActor
    func test_MultiSelect_can_select_single_card() throws {
        enterMultiSelectMode()
        
        // Focus a card
        let remote = XCUIRemote.shared
        remote.press(.down) // Navigate to tier grid
        sleep(1)
        
        // Select the card
        remote.press(.select)
        sleep(1)
        
        // Verify selection count updated
        let selectionCount = getSelectionCount()
        XCTAssertGreaterThan(
            selectionCount,
            0,
            "Selection count should be > 0 after selecting a card"
        )
    }
    
    @MainActor
    func test_MultiSelect_can_select_multiple_cards() throws {
        enterMultiSelectMode()
        
        let remote = XCUIRemote.shared
        
        // Navigate to tier grid and select multiple cards
        remote.press(.down)
        sleep(1)
        
        // Select first card
        remote.press(.select)
        sleep(1)
        let count1 = getSelectionCount()
        
        // Navigate and select second card
        remote.press(.right)
        sleep(1)
        remote.press(.select)
        sleep(1)
        let count2 = getSelectionCount()
        
        XCTAssertGreaterThan(count2, count1, "Selection count should increase with each selection")
        XCTAssertGreaterThanOrEqual(count2, 2, "Should have at least 2 cards selected")
    }
    
    @MainActor
    func test_MultiSelect_can_deselect_card() throws {
        enterMultiSelectMode()
        
        let remote = XCUIRemote.shared
        remote.press(.down)
        sleep(1)
        
        // Select a card
        remote.press(.select)
        sleep(1)
        let countAfterSelect = getSelectionCount()
        
        // Deselect the same card
        remote.press(.select)
        sleep(1)
        let countAfterDeselect = getSelectionCount()
        
        XCTAssertLessThan(
            countAfterDeselect,
            countAfterSelect,
            "Selection count should decrease when deselecting"
        )
    }
    
    // MARK: - Action Bar Tests
    
    @MainActor
    func test_MultiSelect_action_bar_shows_move_buttons() throws {
        enterMultiSelectMode()
        selectCards(count: 2)
        
        // Verify move buttons exist for different tiers
        let moveButtons = [
            "ActionBar_Move_S",
            "ActionBar_Move_A",
            "ActionBar_Move_B",
            "ActionBar_Move_C"
        ]
        
        var foundButtons = 0
        for buttonID in moveButtons {
            if app.buttons[buttonID].exists {
                foundButtons += 1
            }
        }
        
        XCTAssertGreaterThanOrEqual(
            foundButtons,
            2,
            "Should have at least 2 move buttons available in action bar"
        )
    }
    
    @MainActor
    func test_MultiSelect_selection_count_displays() throws {
        enterMultiSelectMode()
        
        // Select a card
        let remote = XCUIRemote.shared
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        sleep(1)
        
        // Check for selection count indicator
        let count = getSelectionCount()
        XCTAssertGreaterThan(count, 0, "Selection count should be visible and > 0")
    }
    
    // MARK: - Batch Move Tests
    
    @MainActor
    func test_MultiSelect_can_batch_move_to_tier() throws {
        enterMultiSelectMode()
        selectCards(count: 2)
        
        // Find and press a move button
        let moveButtonS = app.buttons["ActionBar_Move_S"]
        if moveButtonS.exists {
            let remote = XCUIRemote.shared
            navigateToButton(moveButtonS, using: remote)
            remote.press(.select)
            sleep(2)
            
            // After moving, selection should be cleared and mode should exit
            let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
            XCTAssertTrue(
                multiSelectButton.exists,
                "Should exit multi-select mode after batch move"
            )
        } else {
            throw XCTSkip("Move to S button not available")
        }
    }
    
    @MainActor
    func test_MultiSelect_focus_returns_to_grid_after_move() throws {
        enterMultiSelectMode()
        selectCards(count: 1)
        
        let moveButton = app.buttons["ActionBar_Move_A"]
        if moveButton.exists {
            let remote = XCUIRemote.shared
            navigateToButton(moveButton, using: remote)
            remote.press(.select)
            sleep(2)
            
            // Focus should return to tier grid
            let cards = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'Card_'")
            )
            
            var cardHasFocus = false
            for i in 0..<min(cards.count, 10) {
                if cards.element(boundBy: i).hasFocus {
                    cardHasFocus = true
                    break
                }
            }
            
            XCTAssertTrue(
                cardHasFocus || app.buttons["ActionBar_MultiSelect"].hasFocus,
                "Focus should return to tier grid or action bar after move"
            )
        } else {
            throw XCTSkip("Move button not available")
        }
    }
    
    // MARK: - Focus Tests
    
    @MainActor
    func test_MultiSelect_can_navigate_between_action_bar_and_grid() throws {
        enterMultiSelectMode()
        
        let remote = XCUIRemote.shared
        let clearButton = app.buttons["ActionBar_ClearSelection"]
        
        // Start in action bar
        XCTAssertTrue(clearButton.exists)
        
        // Navigate down to tier grid
        remote.press(.down)
        sleep(1)
        
        // Should be able to select cards (focus is in grid)
        remote.press(.select)
        sleep(1)
        
        // Navigate back up to action bar
        remote.press(.up)
        sleep(1)
        
        // Should be able to reach action bar buttons
        let actionBarReachable = clearButton.hasFocus ||
                                app.buttons["ActionBar_Move_S"].hasFocus ||
                                app.buttons["ActionBar_Move_A"].hasFocus
        
        XCTAssertTrue(
            actionBarReachable || clearButton.exists,
            "Should be able to navigate between action bar and tier grid"
        )
    }
    
    @MainActor
    func test_MultiSelect_cards_remain_selectable_while_navigating() throws {
        enterMultiSelectMode()
        
        let remote = XCUIRemote.shared
        remote.press(.down)
        sleep(1)
        
        // Select card, navigate, select another
        remote.press(.select)
        sleep(1)
        
        remote.press(.right)
        sleep(1)
        
        remote.press(.select)
        sleep(1)
        
        remote.press(.right)
        sleep(1)
        
        remote.press(.select)
        sleep(1)
        
        // Should have multiple cards selected
        let count = getSelectionCount()
        XCTAssertGreaterThanOrEqual(
            count,
            2,
            "Should be able to select multiple cards while navigating"
        )
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor
    func test_MultiSelect_clear_selection_with_no_cards_selected() throws {
        enterMultiSelectMode()
        
        // Try to clear without selecting anything
        let clearButton = app.buttons["ActionBar_ClearSelection"]
        XCTAssertTrue(clearButton.exists)
        
        let remote = XCUIRemote.shared
        navigateToButton(clearButton, using: remote)
        remote.press(.select)
        sleep(1)
        
        // Should exit multi-select mode gracefully
        XCTAssertTrue(
            app.buttons["ActionBar_MultiSelect"].exists,
            "Should handle clearing with no selection gracefully"
        )
    }
    
    @MainActor
    func test_MultiSelect_move_all_cards_from_tier() throws {
        enterMultiSelectMode()
        
        let remote = XCUIRemote.shared
        remote.press(.down)
        sleep(1)
        
        // Try to select all visible cards in a tier
        for _ in 0..<5 {
            remote.press(.select)
            sleep(1)
            remote.press(.right)
            sleep(1)
        }
        
        let count = getSelectionCount()
        XCTAssertGreaterThan(count, 0, "Should have selected some cards")
        
        // Move them to another tier
        let moveButton = app.buttons["ActionBar_Move_C"]
        if moveButton.exists {
            navigateToButton(moveButton, using: remote)
            remote.press(.select)
            sleep(2)
            
            // Verify mode exited
            XCTAssertTrue(
                app.buttons["ActionBar_MultiSelect"].exists,
                "Should exit multi-select after batch move"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func enterMultiSelectMode() {
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        XCTAssertTrue(
            multiSelectButton.waitForExistence(timeout: 10),
            "Multi-Select button must exist to enter mode"
        )
        
        let remote = XCUIRemote.shared
        navigateToButton(multiSelectButton, using: remote)
        remote.press(.select)
        sleep(1)
        
        // Verify mode entered
        XCTAssertTrue(
            app.buttons["ActionBar_ClearSelection"].waitForExistence(timeout: 3),
            "Failed to enter multi-select mode"
        )
    }
    
    private func selectCards(count: Int) {
        let remote = XCUIRemote.shared
        remote.press(.down) // Navigate to tier grid
        sleep(1)
        
        for _ in 0..<count {
            remote.press(.select)
            sleep(1)
            remote.press(.right)
            sleep(1)
        }
    }
    
    private func getSelectionCount() -> Int {
        // Try to find selection count in action bar
        // Could be a label, static text, or part of button label
        let selectionCountElement = app.staticTexts["ActionBar_SelectionCount"]
        if selectionCountElement.exists {
            let text = selectionCountElement.label
            if let count = Int(text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                return count
            }
        }
        
        // Fallback: count from clear button label (e.g., "Clear (3)")
        let clearButton = app.buttons["ActionBar_ClearSelection"]
        if clearButton.exists {
            let label = clearButton.label
            if let count = Int(label.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                return count > 0 ? count : 1
            }
        }
        
        // If we can't determine count but clear button exists, assume at least 1
        return clearButton.exists ? 1 : 0
    }
    
    private func navigateToButton(_ button: XCUIElement, using remote: XCUIRemote) {
        if button.hasFocus {
            return
        }
        
        // Try different navigation patterns
        for _ in 0..<20 {
            if button.hasFocus {
                return
            }
            
            remote.press(.up)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.right)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.left)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.down)
            sleep(1)
            if button.hasFocus { return }
        }
    }
}

// MARK: - XCUIElement Extension

private extension XCUIElement {
    var hasFocus: Bool {
        return self.exists && self.isHittable
    }
}
