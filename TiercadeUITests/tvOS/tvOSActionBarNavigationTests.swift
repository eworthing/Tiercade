#if os(tvOS)
import XCTest

/// Regression suite for ActionBar visibility and navigation on tvOS.
/// Ensures the multi-select affordance is reachable for remote-driven flows.
final class ActionBarNavigationTests: TiercadeTvOSUITestCase {
    override var launchAnchor: XCUIElement {
        app.buttons["ActionBar_MultiSelect"]
    }

    @MainActor
    func test_navigate_down_to_action_bar() throws {
        let remote = self.remote
        let target = launchAnchor

        guard target.exists == false else {
            XCTAssertTrue(target.isEnabled, "MultiSelect should be enabled when it is present without navigation")
            return
        }

        for _ in 1...15 {
            remote.press(.down)
            pause(for: 0.4)

            if target.exists {
                XCTAssertTrue(target.isEnabled, "MultiSelect button should be enabled once discovered")
                return
            }
        }

        XCTFail("Could not find ActionBar_MultiSelect even after navigating down 15 times")
    }

    @MainActor
    func test_action_bar_exists_without_navigation() throws {
        let actionBar = app.otherElements["ActionBar"]
        pause(for: 0.5)

        XCTAssertTrue(
            actionBar.exists || launchAnchor.exists,
            "Expected ActionBar container or MultiSelect button to exist without navigation"
        )
    }

    @MainActor
    func test_check_if_action_bar_disabled() throws {
        let multiSelectButton = launchAnchor

        if multiSelectButton.exists {
            XCTAssertTrue(multiSelectButton.isEnabled, "MultiSelect button exists but is disabled")
            return
        }

        let fallbackButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] 'multi'"))
            .firstMatch

        XCTAssertFalse(
            fallbackButton.exists,
            "Found a button containing 'multi' in the label but missing ActionBar_MultiSelect identifier"
        )
    }
}
#endif
