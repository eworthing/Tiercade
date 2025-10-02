#if os(tvOS)
import XCTest

/// Tests to investigate element visibility issues in the tvOS UI test hierarchy.
/// Trying different query types and accessibility configurations.
final class ElementVisibilityTests: TiercadeTvOSUITestCase {
    override var shouldLaunchAppOnSetUp: Bool { true }

    // MARK: - ActionBar Investigation

    @MainActor
    func test_find_action_bar_by_different_queries() throws {
        // Try different query types to find ActionBar
        print("\n=== ACTIONBAR QUERIES ===")

        // Try as otherElement (current approach)
        let asOtherElement = app.otherElements["ActionBar"]
        print("otherElements['ActionBar'].exists: \(asOtherElement.exists)")

        // Try as descendant
        let descendants = app.descendants(matching: .any)["ActionBar"]
        print("descendants['ActionBar'].exists: \(descendants.exists)")

        // Try to find MultiSelect button directly
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        print("buttons['ActionBar_MultiSelect'].exists: \(multiSelectButton.exists)")

        // If button exists, ActionBar parent should exist
        if multiSelectButton.waitForExistence(timeout: 5) {
            print("✅ MultiSelect button found!")
            XCTAssertTrue(multiSelectButton.exists, "MultiSelect button should exist")
        } else {
            // Try finding button by label instead
            let buttonByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'multi'")).firstMatch
            print("Button with 'multi' in label exists: \(buttonByLabel.exists)")

            if buttonByLabel.exists {
                print("Found button with label: '\(buttonByLabel.label)'")
                print("Button identifier: '\(buttonByLabel.identifier)'")
            }
        }
    }

    @MainActor
    func test_find_tier_rows_by_different_queries() throws {
        // Try different query types to find TierRow
        print("\n=== TIERROW QUERIES ===")

        // Try as otherElement (current approach)
        let sTierAsOther = app.otherElements["TierRow_S"]
        print("otherElements['TierRow_S'].exists: \(sTierAsOther.exists)")

        // Try finding any element with "TierRow" in identifier
        let tierRowDescendants = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'TierRow'")
        )
        print("Elements with 'TierRow' in identifier: \(tierRowDescendants.count)")

        // Try finding by tier letter
        let sElements = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'S'")
        )
        print("Elements with 'S' in identifier: \(sElements.count)")

        // List first few matches
        for i in 0..<min(5, sElements.count) {
            let element = sElements.element(boundBy: i)
            if element.exists {
                print("  Element[\(i)]: identifier='\(element.identifier)', label='\(element.label)'")
            }
        }
    }

    @MainActor
    func test_list_all_accessible_buttons() throws {
        // List all buttons to see what's actually accessible
        print("\n=== ALL ACCESSIBLE BUTTONS (first 20) ===")

        let buttonCount = min(20, app.buttons.count)
        var foundToolbar = false
        var foundActionBar = false

        for i in 0..<buttonCount {
            let button = app.buttons.element(boundBy: i)
            if button.waitForExistence(timeout: 1) {
                let id = button.identifier
                let label = button.label
                print("Button[\(i)]: id='\(id)', label='\(label)'")

                if id.starts(with: "Toolbar_") {
                    foundToolbar = true
                }
                if id.starts(with: "ActionBar_") {
                    foundActionBar = true
                }
            }
        }

        print("\nSummary:")
        print("  Found Toolbar buttons: \(foundToolbar)")
        print("  Found ActionBar buttons: \(foundActionBar)")

        // Pass if we found at least toolbar buttons
        XCTAssertTrue(foundToolbar, "Should find at least some toolbar buttons")
    }

    @MainActor
    func test_wait_for_action_bar_with_long_timeout() throws {
        // Maybe ActionBar needs more time to appear
        print("\n=== TESTING LONG TIMEOUT ===")

        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        let appeared = multiSelectButton.waitForExistence(timeout: 10)

        print("MultiSelect button appeared after 10s: \(appeared)")

        if appeared {
            print("✅ Button exists after waiting!")
            XCTAssertTrue(multiSelectButton.exists)
        } else {
            print("❌ Button still doesn't exist after 10 seconds")
            print("Trying to find any button with 'Select' in label...")

            let anySelectButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'select'")
            ).firstMatch

            if anySelectButton.exists {
                let msg = "Found button with 'select': " +
                    "label='\(anySelectButton.label)', id='\(anySelectButton.identifier)'"
                print(msg)
            }
        }
    }
}

#endif
