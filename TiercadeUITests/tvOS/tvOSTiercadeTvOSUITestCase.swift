#if os(tvOS)
import XCTest

@MainActor
class TiercadeTvOSUITestCase: XCTestCase {
    fileprivate static let bundleIdentifier = "eworthing.Tiercade"
    fileprivate static let baseLaunchArguments = ["-uiTest", "-resetUiState"]
    fileprivate static let baseLaunchEnvironment = [
        "UITEST_DISABLE_ANIMATIONS": "1",
        "UITEST_SEED_DATA": "1"
    ]

    var app: XCUIApplication!
    var remote: XCUIRemote { XCUIRemote.shared }

    /// Override to inject additional launch arguments for a specific test case.
    var additionalLaunchArguments: [String] { [] }

    /// Override to inject additional launch environment values for a specific test case.
    var additionalLaunchEnvironment: [String: String] { [:] }

    /// Override and return `false` for tests that manage launching manually.
    var shouldLaunchAppOnSetUp: Bool { true }

    /// The element we wait on after launching to confirm the UI is ready.
    var launchAnchor: XCUIElement {
        app.buttons["Toolbar_H2H"]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = Self.baseLaunchArguments + additionalLaunchArguments
        app.launchEnvironment = Self.baseLaunchEnvironment.merging(additionalLaunchEnvironment) { _, new in new }

        try Self.refreshSimulatorBeforeTest()

        if shouldLaunchAppOnSetUp {
            launchApp(waitingFor: launchAnchor)
        }
    }

    override func tearDownWithError() throws {
        if app?.isRunning == true {
            app.terminate()
            _ = launchAnchor.waitForNonExistence(timeout: 2)
        }
        app = nil
        try super.tearDownWithError()
    }

    func launchApp(waitingFor element: XCUIElement, timeout: TimeInterval = 10) {
        if app.isRunning {
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected \(element.debugDescription) to exist after launching the app"
        )
    }

    func relaunchApp(
        waitingFor element: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        extraArguments: [String] = []
    ) {
        app.terminate()
        app.launchArguments = Self.baseLaunchArguments + additionalLaunchArguments + extraArguments
        app.launchEnvironment = Self.baseLaunchEnvironment.merging(additionalLaunchEnvironment) { _, new in new }
        let anchor = element ?? launchAnchor
        launchApp(waitingFor: anchor, timeout: timeout)
    }

    static func refreshSimulatorBeforeTest() throws {
        terminateRunningAppIfPresent()
    }

    static func terminateRunningAppIfPresent() {
        let runningApp = XCUIApplication(bundleIdentifier: bundleIdentifier)
        if runningApp.state != .notRunning {
            runningApp.terminate()
        }
    }

    func pause(for duration: TimeInterval) {
        guard duration > 0 else { return }
        let expectation = XCTestExpectation(description: "Pause for \(duration)")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: duration + 0.5)
    }

    @discardableResult
    func sleep(_ seconds: UInt32) -> UInt32 {
        pause(for: TimeInterval(seconds))
        return 0
    }

    func waitForFocus(on element: XCUIElement, timeout: TimeInterval = 2) {
        let predicate = NSPredicate(format: "hasFocus == YES")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected \(element.identifier) to receive focus within \(timeout)s")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == NO")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

extension XCUIApplication {
    var isRunning: Bool {
        state == .runningForeground || state == .runningBackground
    }
}
#endif
