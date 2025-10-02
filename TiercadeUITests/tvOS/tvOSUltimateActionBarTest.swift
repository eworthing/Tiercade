#if os(tvOS)
import XCTest

final class UltimateActionBarTest: TiercadeTvOSUITestCase {

    func test_every_possible_actionbar_query() {
        var output = "\n============ ULTIMATE ACTIONBAR DIAGNOSTIC ============\n"

        // Wait for app to be stable
        pause(for: 3)

        output += "\n--- 1. Direct button queries (no container check) ---\n"
        let multiSelectButton = app.buttons["ActionBar_MultiSelect"]
        output += "MultiSelect button exists: \(multiSelectButton.exists)\n"
        output += "MultiSelect button waitForExistence(5s): \(multiSelectButton.waitForExistence(timeout: 5))\n"

        output += "\n--- 2. Query all buttons and print ---\n"
        let allButtons = app.buttons.allElementsBoundByIndex
        output += "Total buttons found: \(allButtons.count)\n"
        for (index, button) in allButtons.enumerated() {
            output += "  Button \(index): identifier='\(button.identifier)', label='\(button.label)'\n"
        }

        output += "\n--- 3. Query as otherElements ---\n"
        let actionBarOther = app.otherElements["ActionBar"]
        output += "ActionBar as otherElement exists: \(actionBarOther.exists)\n"

        output += "\n--- 4. Query as any element type ---\n"
        let actionBarAny = app.descendants(matching: .any)["ActionBar"]
        output += "ActionBar as any descendant exists: \(actionBarAny.exists)\n"

        output += "\n--- 5. Query move buttons directly ---\n"
        let moveSButton = app.buttons["ActionBar_Move_S"]
        output += "Move S button exists: \(moveSButton.exists)\n"

        output += "\n--- 6. Search for 'Multi-Select' text ---\n"
        let multiSelectText = app.staticTexts["Multi-Select"]
        output += "Multi-Select text exists: \(multiSelectText.exists)\n"

        output += "\n--- 7. Query buttons by partial label ---\n"
        let moveButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move to'"))
        output += "Move buttons count: \(moveButtons.count)\n"

        output += "\n--- 8. Dump entire UI hierarchy ---\n"
        output += app.debugDescription

        output += "\n============ END DIAGNOSTIC ============\n"

        // Write to file
        try? output.write(toFile: "/tmp/actionbar_ultimate_diagnostic.txt", atomically: true, encoding: .utf8)

        // This test always passes - it's just for diagnostics
        XCTAssertTrue(true)
    }
}

#endif
