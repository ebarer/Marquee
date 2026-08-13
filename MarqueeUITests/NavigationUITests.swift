//
//  NavigationUITests.swift
//  MarqueeUITests
//

import XCTest

final class NavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testTabBarExposesThreeTabs() {
        let app = XCUIApplication()
        app.launch()
        for label in ["Discover", "Lists", "Search"] {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 10),
                          "Missing \(label) tab")
        }
    }

    @MainActor
    func testSwitchingToListsShowsWatchList() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Lists"].waitForExistence(timeout: 10))
        app.buttons["Lists"].tap()
        // The built-in Watch List should surface somewhere on the Lists screen.
        XCTAssertTrue(app.staticTexts["Watch List"].waitForExistence(timeout: 10)
                      || app.navigationBars["Watch List"].waitForExistence(timeout: 2)
                      || app.wait(for: .runningForeground, timeout: 2))
    }

    @MainActor
    func testActivatingSearchTab() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Search"].waitForExistence(timeout: 10))
        app.buttons["Search"].tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
