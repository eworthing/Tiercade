#if os(tvOS)
import XCTest

/// Debug test to inspect UI hierarchy
final class UIHierarchyDebugTests: TiercadeTvOSUITestCase {

    @MainActor
    func test_debug_print_hierarchy() throws {
        // Print all buttons
        print("=== ALL BUTTONS ===")
        for i in 0..<app.buttons.count {
            let button = app.buttons.element(boundBy: i)
            if button.exists {
                print("Button[\(i)]: identifier='\(button.identifier)', label='\(button.label)'")
            }
        }

        // Print all other elements
        print("\n=== ALL OTHER ELEMENTS ===")
        for i in 0..<min(20, app.otherElements.count) { // Limit to first 20
            let element = app.otherElements.element(boundBy: i)
            if element.exists {
                print("OtherElement[\(i)]: identifier='\(element.identifier)', label='\(element.label)'")
            }
        }

        // Try to find specific elements we're looking for
        print("\n=== SPECIFIC ELEMENT CHECKS ===")
        print("ActionBar exists: \(app.otherElements["ActionBar"].exists)")
        print("ActionBar_MultiSelect exists: \(app.buttons["ActionBar_MultiSelect"].exists)")
        print("TierRow_S exists: \(app.otherElements["TierRow_S"].exists)")

        // Always fail so we see the output
        XCTFail("Debug test - check console output for UI hierarchy")
    }
}

#endif
