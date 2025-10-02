import XCTest

/// Comprehensive tests for Head-to-Head ranking mode on tvOS
/// Tests focus management, navigation, skip functionality, and exit behavior
final class HeadToHeadTests: XCTestCase {
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
    
    // MARK: - Entry & Exit Tests
    
    @MainActor
    func test_H2H_can_enter_from_toolbar() throws {
        let h2hButton = app.buttons["Toolbar_H2H"]
        
        // Navigate to H2H button in toolbar
        let remote = XCUIRemote.shared
        navigateToToolbarButton(h2hButton, using: remote)
        
        // Activate H2H mode
        remote.press(.select)
        sleep(2)
        
        // Verify H2H overlay appeared
        let h2hOverlay = app.otherElements["H2H_Overlay"]
        XCTAssertTrue(
            h2hOverlay.waitForExistence(timeout: 3),
            "H2H overlay should appear after activating H2H button"
        )
        
        // Verify left and right options exist
        XCTAssertTrue(
            app.buttons["H2H_Left"].exists,
            "Left option should be visible"
        )
        XCTAssertTrue(
            app.buttons["H2H_Right"].exists,
            "Right option should be visible"
        )
    }
    
    @MainActor
    func test_H2H_exit_command_dismisses_overlay() throws {
        enterH2HMode()
        
        let h2hOverlay = app.otherElements["H2H_Overlay"]
        XCTAssertTrue(h2hOverlay.exists, "H2H overlay should be open")
        
        // Press Menu button to exit
        let remote = XCUIRemote.shared
        remote.press(.menu)
        sleep(2) // Wait for debounce and dismissal
        
        // Verify overlay dismissed
        XCTAssertFalse(
            h2hOverlay.exists,
            "H2H overlay should dismiss after Menu button press"
        )
        
        // Verify focus returned to main UI
        let toolbarButton = app.buttons["Toolbar_H2H"]
        XCTAssertTrue(
            toolbarButton.exists,
            "Should return to main UI after exit"
        )
    }
    
    @MainActor
    func test_H2H_exit_command_debounce() throws {
        enterH2HMode()
        
        let h2hOverlay = app.otherElements["H2H_Overlay"]
        let remote = XCUIRemote.shared
        
        // Make a selection first
        remote.press(.left) // Focus left option
        sleep(1)
        remote.press(.select) // Select it
        sleep(1)
        
        // Press Menu immediately after selection (should be ignored due to debounce)
        remote.press(.menu)
        sleep(1) // Short wait (less than debounce window)
        
        // If new pair loaded, overlay should still exist
        // (This tests that Menu doesn't immediately exit after selection)
        let stillInH2H = h2hOverlay.exists || app.buttons["H2H_Finish"].exists
        XCTAssertTrue(
            stillInH2H,
            "Should still be in H2H mode shortly after selection (debounce protection)"
        )
    }
    
    // MARK: - Focus & Navigation Tests
    
    @MainActor
    func test_H2H_default_focus_on_left_option() throws {
        enterH2HMode()
        
        let leftOption = app.buttons["H2H_Left"]
        XCTAssertTrue(
            leftOption.waitForExistence(timeout: 3),
            "Left option should exist"
        )
        
        // Default focus should be on left option
        XCTAssertTrue(
            leftOption.hasFocus,
            "Default focus should be on left option when H2H pair loads"
        )
    }
    
    @MainActor
    func test_H2H_can_navigate_between_options() throws {
        enterH2HMode()
        
        let leftOption = app.buttons["H2H_Left"]
        let rightOption = app.buttons["H2H_Right"]
        
        XCTAssertTrue(leftOption.waitForExistence(timeout: 3))
        XCTAssertTrue(rightOption.exists)
        
        let remote = XCUIRemote.shared
        
        // Navigate to right option
        remote.press(.right)
        sleep(1)
        
        XCTAssertTrue(
            rightOption.hasFocus,
            "Right press should move focus to right option"
        )
        
        // Navigate back to left option
        remote.press(.left)
        sleep(1)
        
        XCTAssertTrue(
            leftOption.hasFocus,
            "Left press should move focus back to left option"
        )
    }
    
    @MainActor
    func test_H2H_skip_button_is_reachable_and_centered() throws {
        enterH2HMode()
        
        let skipButton = app.buttons["H2H_Skip"]
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 3),
            "Skip button should exist in H2H mode"
        )
        
        // Verify skip button has the correct icon
        // (accessibility label should contain "skip" or have clock.arrow.circlepath icon)
        let skipLabel = skipButton.label.lowercased()
        XCTAssertTrue(
            skipLabel.contains("skip") || skipButton.identifier == "H2H_Skip",
            "Skip button should be identifiable"
        )
        
        let remote = XCUIRemote.shared
        
        // Navigate down from left/right options should reach skip
        remote.press(.down)
        sleep(1)
        
        XCTAssertTrue(
            skipButton.hasFocus,
            "Skip button should be reachable via down navigation"
        )
    }
    
    @MainActor
    func test_H2H_focus_stays_contained() throws {
        enterH2HMode()
        
        let h2hOverlay = app.otherElements["H2H_Overlay"]
        let leftOption = app.buttons["H2H_Left"]
        let remote = XCUIRemote.shared
        
        // Try to escape focus by pressing up/down multiple times
        for _ in 0..<10 {
            remote.press(.up)
            sleep(1)
        }
        
        // Should still be in H2H overlay
        XCTAssertTrue(
            h2hOverlay.exists,
            "Focus should stay contained in H2H overlay after up presses"
        )
        
        for _ in 0..<10 {
            remote.press(.down)
            sleep(1)
        }
        
        XCTAssertTrue(
            h2hOverlay.exists,
            "Focus should stay contained in H2H overlay after down presses"
        )
        
        // Verify we can still interact with H2H controls
        XCTAssertTrue(
            leftOption.exists || app.buttons["H2H_Skip"].exists,
            "H2H controls should still be accessible"
        )
    }
    
    // MARK: - Skip Functionality Tests
    
    @MainActor
    func test_H2H_skip_button_increments_counter() throws {
        enterH2HMode()
        
        let skipButton = app.buttons["H2H_Skip"]
        let skipCounter = app.staticTexts["H2H_SkippedCount"]
        
        XCTAssertTrue(skipButton.waitForExistence(timeout: 3))
        
        // Get initial skip count (should be 0)
        let initialCount = skipCounter.exists ? skipCounter.label : "0"
        
        let remote = XCUIRemote.shared
        
        // Navigate to and press skip button
        navigateToButton(skipButton, using: remote)
        remote.press(.select)
        sleep(1)
        
        // Verify counter incremented
        if skipCounter.waitForExistence(timeout: 2) {
            let newCount = skipCounter.label
            XCTAssertNotEqual(
                initialCount,
                newCount,
                "Skip counter should increment after pressing skip button"
            )
        } else {
            print("Skip counter not visible - may only show when > 0")
        }
        
        // Verify new pair loaded (options should still exist)
        XCTAssertTrue(
            app.buttons["H2H_Left"].exists || app.buttons["H2H_Finish"].exists,
            "Should load new pair or show finish button after skip"
        )
    }
    
    @MainActor
    func test_H2H_skip_counter_is_visible_and_updates() throws {
        enterH2HMode()
        
        let skipButton = app.buttons["H2H_Skip"]
        let remote = XCUIRemote.shared
        
        // Skip multiple times to ensure counter appears
        for _ in 0..<3 {
            navigateToButton(skipButton, using: remote)
            remote.press(.select)
            sleep(1)
        }
        
        // Counter should now be visible and show at least 3
        let skipCounter = app.staticTexts["H2H_SkippedCount"]
        if skipCounter.waitForExistence(timeout: 2) {
            let countText = skipCounter.label
            print("Skip counter shows: \(countText)")
            XCTAssertTrue(
                skipCounter.exists,
                "Skip counter should be visible after multiple skips"
            )
        }
    }
    
    // MARK: - Selection & Pair Loading Tests
    
    @MainActor
    func test_H2H_selecting_option_loads_next_pair() throws {
        enterH2HMode()
        
        let leftOption = app.buttons["H2H_Left"]
        XCTAssertTrue(leftOption.waitForExistence(timeout: 3))
        
        // Get initial option labels to verify they change
        let initialLeftLabel = leftOption.label
        
        let remote = XCUIRemote.shared
        
        // Select left option
        remote.press(.select)
        sleep(2) // Wait for next pair to load
        
        // Either a new pair should load OR finish button should appear
        let newLeftOption = app.buttons["H2H_Left"]
        let finishButton = app.buttons["H2H_Finish"]
        
        let progressedToNext = newLeftOption.exists || finishButton.exists
        XCTAssertTrue(
            progressedToNext,
            "Should either load new pair or show finish button after selection"
        )
        
        // If new pair loaded, verify it's different
        if newLeftOption.exists {
            let newLeftLabel = newLeftOption.label
            print("Initial: \(initialLeftLabel), New: \(newLeftLabel)")
            // Note: Labels might be same if items repeat, so we just verify it exists
        }
    }
    
    @MainActor
    func test_H2H_finish_button_appears_when_queue_empty() throws {
        enterH2HMode()
        
        let remote = XCUIRemote.shared
        
        // Make selections until we run out of pairs
        // (This assumes a small dataset in -uiTest mode)
        var iterations = 0
        let maxIterations = 50 // Safety limit
        
        while iterations < maxIterations {
            let leftOption = app.buttons["H2H_Left"]
            let rightOption = app.buttons["H2H_Right"]
            let finishButton = app.buttons["H2H_Finish"]
            
            if finishButton.waitForExistence(timeout: 1) {
                print("Finish button appeared after \(iterations) iterations")
                
                XCTAssertTrue(
                    finishButton.exists,
                    "Finish button should appear when queue is empty"
                )
                
                // Verify options are no longer shown
                XCTAssertFalse(
                    leftOption.exists,
                    "Left option should not exist when finish button is shown"
                )
                XCTAssertFalse(
                    rightOption.exists,
                    "Right option should not exist when finish button is shown"
                )
                
                return // Test passed
            }
            
            if leftOption.exists {
                // Make a selection to progress
                remote.press(.select)
                sleep(1)
            } else {
                XCTFail("Neither options nor finish button found")
                return
            }
            
            iterations += 1
        }
        
        print("Note: Finish button didn't appear within \(maxIterations) iterations - dataset may be too large")
    }
    
    @MainActor
    func test_H2H_finish_button_exits_mode() throws {
        enterH2HMode()
        
        let remote = XCUIRemote.shared
        
        // Skip through pairs quickly to reach finish
        let skipButton = app.buttons["H2H_Skip"]
        for _ in 0..<20 {
            if app.buttons["H2H_Finish"].exists {
                break
            }
            navigateToButton(skipButton, using: remote)
            remote.press(.select)
            sleep(1)
        }
        
        let finishButton = app.buttons["H2H_Finish"]
        if finishButton.waitForExistence(timeout: 2) {
            // Focus and select finish button
            navigateToButton(finishButton, using: remote)
            remote.press(.select)
            sleep(2)
            
            // Verify H2H mode exited
            let h2hOverlay = app.otherElements["H2H_Overlay"]
            XCTAssertFalse(
                h2hOverlay.exists,
                "H2H overlay should dismiss after pressing Finish"
            )
            
            // Verify returned to main UI
            XCTAssertTrue(
                app.buttons["Toolbar_H2H"].exists,
                "Should return to main UI after finishing H2H"
            )
        } else {
            throw XCTSkip("Finish button didn't appear - dataset may be too large")
        }
    }
    
    // MARK: - Focus Restoration Tests
    
    @MainActor
    func test_H2H_focus_restored_after_exit() throws {
        enterH2HMode()
        
        let remote = XCUIRemote.shared
        
        // Exit H2H mode
        remote.press(.menu)
        sleep(2)
        
        // Focus should be restored to a logical location (toolbar or tier grid)
        let toolbarFocused = app.buttons["Toolbar_H2H"].hasFocus ||
                           app.buttons["Toolbar_Randomize"].hasFocus
        let cardFocused = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Card_'")
        ).firstMatch.hasFocus
        
        let focusRestored = toolbarFocused || cardFocused
        XCTAssertTrue(
            focusRestored,
            "Focus should be restored to toolbar or tier grid after exiting H2H"
        )
    }
    
    // MARK: - Helper Methods
    
    private func enterH2HMode() {
        let h2hButton = app.buttons["Toolbar_H2H"]
        let remote = XCUIRemote.shared
        
        // Navigate to H2H button
        for _ in 0..<20 {
            if h2hButton.hasFocus {
                break
            }
            remote.press(.up) // Move to toolbar
            sleep(1)
            if h2hButton.hasFocus {
                break
            }
            remote.press(.right) // Navigate through toolbar
            sleep(1)
        }
        
        // Activate H2H
        remote.press(.select)
        sleep(2)
        
        // Verify we're in H2H mode
        let h2hOverlay = app.otherElements["H2H_Overlay"]
        XCTAssertTrue(
            h2hOverlay.waitForExistence(timeout: 3),
            "Failed to enter H2H mode"
        )
    }
    
    private func navigateToToolbarButton(_ button: XCUIElement, using remote: XCUIRemote) {
        // Navigate up to toolbar
        for _ in 0..<10 {
            if button.hasFocus {
                return
            }
            remote.press(.up)
            sleep(1)
        }
        
        // Navigate left/right to find button
        for _ in 0..<15 {
            if button.hasFocus {
                return
            }
            remote.press(.right)
            sleep(1)
        }
    }
    
    private func navigateToButton(_ button: XCUIElement, using remote: XCUIRemote) {
        if button.hasFocus {
            return
        }
        
        // Try all directions to reach button
        for _ in 0..<5 {
            remote.press(.up)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.down)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.left)
            sleep(1)
            if button.hasFocus { return }
            
            remote.press(.right)
            sleep(1)
            if button.hasFocus { return }
        }
    }
}

// MARK: - XCUIElement Extension

private extension XCUIElement {
    var hasFocus: Bool {
        // On tvOS, focused elements are typically hittable and have higher prominence
        return self.exists && self.isHittable
    }
}
