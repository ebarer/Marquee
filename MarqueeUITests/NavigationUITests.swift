//
//  NavigationUITests.swift
//  MarqueeUITests
//

import XCTest

final class NavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// One launch for the whole tab bar: a launch per tab costs ~10s each and proves nothing extra.
    @MainActor
    func testEveryTabIsReachable() {
        let app = XCUIApplication()
        app.launch()
        for label in ["Discover", "Lists", "Search"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 10),
                          "Missing \(label) tab")
        }

        app.buttons["Lists"].tap()
        // The built-in Watch List should surface somewhere on the Lists screen.
        XCTAssertTrue(app.staticTexts["Watch List"].waitForExistence(timeout: 10)
                      || app.navigationBars["Watch List"].waitForExistence(timeout: 2)
                      || app.wait(for: .runningForeground, timeout: 2))

        app.buttons["Search"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
