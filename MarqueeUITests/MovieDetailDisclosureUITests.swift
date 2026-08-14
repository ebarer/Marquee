//
//  MovieDetailDisclosureUITests.swift
//  MarqueeUITests
//
//  The detail page must never report a field empty and then fill it in. Placeholders are hidden
//  from accessibility, so a value element existing means the page has committed to an answer —
//  and that answer has to be the final one.
//

import XCTest

final class MovieDetailDisclosureUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Opens the first movie on Discover, from empty caches and with the detail request held back
    /// — otherwise a cached title lands complete and there's no loading state to test.
    @MainActor
    private func pushFirstMovie() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetCaches", "-uiTestSlowDetail"]
        app.launch()
        XCTAssertTrue(app.buttons["Discover"].waitForExistence(timeout: 30))

        let card = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No Discover card to open")
        card.tap()
        return app
    }

    /// Every distinct label a value cell showed while the page loaded, in order. Empty means the
    /// cell never disclosed anything, which these tests treat as a failure rather than a pass.
    @MainActor
    private func disclosures(of identifier: String, in app: XCUIApplication,
                             forSeconds seconds: TimeInterval) -> [String] {
        var seen: [String] = []
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            if element.exists {
                let label = element.label
                if !label.isEmpty, seen.last != label { seen.append(label) }
            }
            usleep(40_000)   // 40ms
        }
        return seen
    }

    /// Asserts a cell disclosed something, and that an em dash was its last word on the matter.
    @MainActor
    private func assertNoFillInAfterEmpty(_ identifier: String, in app: XCUIApplication) {
        let seen = disclosures(of: identifier, in: app, forSeconds: 10)

        XCTAssertFalse(seen.isEmpty,
                       "\(identifier) never disclosed a value — the test would pass vacuously")

        if let dash = seen.firstIndex(of: "—") {
            let after = Array(seen[(dash + 1)...])
            XCTAssertTrue(after.isEmpty,
                          "\(identifier) reported empty, then disclosed \(after). Sequence: \(seen)")
        }
    }

    @MainActor
    func testRatingCellNeverFillsInAfterReportingEmpty() {
        assertNoFillInAfterEmpty("metadata-value-RATING", in: pushFirstMovie())
    }

    @MainActor
    func testGenreCellNeverFillsInAfterReportingEmpty() {
        assertNoFillInAfterEmpty("metadata-value-GENRE", in: pushFirstMovie())
    }

    @MainActor
    func testCreditClipsCellNeverFillsInAfterReportingEmpty() {
        assertNoFillInAfterEmpty("metadata-value-CREDIT CLIPS", in: pushFirstMovie())
    }

    @MainActor
    func testStreamingVerdictNeverFlips() {
        let app = pushFirstMovie()
        let seen = disclosures(of: "whereToWatch-verdict", in: app, forSeconds: 10)

        XCTAssertFalse(seen.isEmpty, "The streaming verdict never appeared")
        XCTAssertFalse(seen.contains("Unavailable to Stream") && seen.contains("Available to Stream"),
                       "Streaming verdict flipped mid-load: \(seen)")
    }

    @MainActor
    func testDescriptionNeverReplacesTheUnavailableLine() {
        let app = pushFirstMovie()
        let unavailable = "No movie description available."

        var sawUnavailable = false
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if app.staticTexts[unavailable].exists { sawUnavailable = true }
            usleep(40_000)
        }

        if sawUnavailable {
            XCTAssertTrue(app.staticTexts[unavailable].exists,
                          "Claimed no description, then showed one")
        }
    }
}
