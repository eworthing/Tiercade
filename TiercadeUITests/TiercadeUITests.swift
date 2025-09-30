//
//  TiercadeUITests.swift
//  TiercadeUITests
//
//  Created by PL on 9/14/25.
//

import XCTest

final class TiercadeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Placeholder for teardown logic.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        // Add assertions when coverage is needed.
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
